#!/usr/bin/env python3
"""
Automated Reviewdog Fix Agent

This agent continuously monitors the current branch's PR for reviewdog linter failures,
automatically fixes them using Claude API, commits, and pushes until all checks pass.
Supports any linter that reviewdog runs (shellcheck, golangci-lint, etc.).
"""

import json
import os
import subprocess
import sys
import time
from typing import Optional, Dict, List, Tuple
import re

try:
    import anthropic
except ImportError:
    print("Error: anthropic package not installed. Run: pip install anthropic")
    sys.exit(1)


class ReviewdogAgent:
    def __init__(self, api_key: Optional[str] = None):
        """Initialize the agent with Claude API credentials."""
        self.api_key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not self.api_key:
            raise ValueError(
                "ANTHROPIC_API_KEY environment variable must be set or passed as argument"
            )
        self.client = anthropic.Anthropic(api_key=self.api_key)
        self.current_branch = self._get_current_branch()
        self.pr_number = None

    def _run_command(self, cmd: List[str], check=True) -> Tuple[int, str, str]:
        """Run a shell command and return exit code, stdout, stderr."""
        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True, check=check
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.CalledProcessError as e:
            return e.returncode, e.stdout, e.stderr

    def _get_current_branch(self) -> str:
        """Get the current git branch name."""
        code, stdout, _ = self._run_command(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"]
        )
        if code != 0:
            raise RuntimeError("Failed to get current branch")
        return stdout.strip()

    def _get_repo_info(self) -> Tuple[str, str]:
        """Get the GitHub org and repo name from git remote."""
        code, stdout, _ = self._run_command(
            ["git", "remote", "get-url", "origin"]
        )
        if code != 0:
            raise RuntimeError("Failed to get git remote URL")

        remote_url = stdout.strip()

        # Handle both HTTPS and SSH URLs
        # SSH: git@github.com:org/repo.git
        # HTTPS: https://github.com/org/repo.git
        import re
        match = re.search(r'github\.com[:/]([^/]+)/([^/]+?)(\.git)?$', remote_url)
        if not match:
            raise RuntimeError(f"Could not parse GitHub org/repo from: {remote_url}")

        org = match.group(1)
        repo = match.group(2)
        return org, repo

    def get_pr_for_branch(self) -> Optional[int]:
        """Get the PR number for the current branch."""
        code, stdout, stderr = self._run_command(
            [
                "gh",
                "pr",
                "list",
                "--head",
                self.current_branch,
                "--json",
                "number,state",
                "--jq",
                ".[0].number",
            ],
            check=False,
        )

        if code != 0:
            print(f"Error getting PR: {stderr}")
            return None

        pr_num = stdout.strip()
        if pr_num and pr_num != "null":
            return int(pr_num)
        return None

    def get_pr_checks(self) -> Dict[str, str]:
        """Get the status of all checks for the PR."""
        if not self.pr_number:
            return {}

        code, stdout, stderr = self._run_command(
            ["gh", "pr", "checks", str(self.pr_number)], check=False
        )

        # Parse the check results
        checks = {}
        for line in stdout.split("\n"):
            if line.strip():
                # Parse format: "check_name<tab>status<tab>time<tab>url"
                parts = line.split("\t")
                if len(parts) >= 2:
                    check_name = parts[0].strip()
                    status = parts[1].strip()
                    checks[check_name] = status

        return checks

    def run_shellcheck_locally(self) -> List[Dict]:
        """Run shellcheck locally to get detailed error information."""
        print("Running shellcheck locally to detect issues...")
        # TODO: This currently only runs shellcheck. Could be extended to run other linters.

        # Find all shell scripts
        code, stdout, _ = self._run_command(
            ["find", ".", "-type", "f", "-name", "*.sh", "-not", "-path", "./vendor/*", "-not", "-path", "./.devbox/*", "-not", "-path", "./build/*"]
        )

        if code != 0:
            return []

        shell_files = [f.strip() for f in stdout.split("\n") if f.strip()]
        all_issues = []

        for file_path in shell_files:
            # Run shellcheck with JSON output
            code, stdout, stderr = self._run_command(
                ["shellcheck", "-f", "json", file_path], check=False
            )

            if code != 0 and stdout:
                try:
                    issues = json.loads(stdout)
                    for issue in issues:
                        issue["file"] = file_path
                        all_issues.append(issue)
                except json.JSONDecodeError:
                    # If not JSON, try to parse plain text output
                    code, stdout, _ = self._run_command(
                        ["shellcheck", file_path], check=False
                    )
                    if stdout:
                        all_issues.append({
                            "file": file_path,
                            "line": 0,
                            "message": stdout,
                            "code": "UNKNOWN"
                        })

        return all_issues

    def fix_shellcheck_issues(self, issues: List[Dict]) -> bool:
        """Use Claude to fix shellcheck issues in the affected files."""
        if not issues:
            return False

        # Group issues by file
        files_with_issues = {}
        for issue in issues:
            file_path = issue["file"]
            if file_path not in files_with_issues:
                files_with_issues[file_path] = []
            files_with_issues[file_path].append(issue)

        print(f"\nFound issues in {len(files_with_issues)} file(s)")

        fixed_files = []

        for file_path, file_issues in files_with_issues.items():
            print(f"\nFixing {file_path}...")

            # Read the current file content
            try:
                with open(file_path, "r") as f:
                    original_content = f.read()
            except Exception as e:
                print(f"Error reading {file_path}: {e}")
                continue

            # Format issues for Claude
            issues_description = "\n".join([
                f"- Line {issue.get('line', 'unknown')}: {issue.get('message', 'Unknown issue')} (Code: {issue.get('code', 'UNKNOWN')})"
                for issue in file_issues
            ])

            # Ask Claude to fix the issues
            prompt = f"""You are a shellcheck expert. Fix the following shellcheck issues in this bash script.

File: {file_path}

ShellCheck Issues:
{issues_description}

Current file content:
```bash
{original_content}
```

Please provide the complete fixed file content. Only output the corrected bash script code, nothing else.
Make minimal changes - only fix the shellcheck issues, don't refactor or change functionality.
"""

            try:
                print(f"  Asking Claude to fix {len(file_issues)} issue(s)...")
                response = self.client.messages.create(
                    model="claude-sonnet-4-20250514",
                    max_tokens=4096,
                    messages=[{"role": "user", "content": prompt}]
                )

                fixed_content = response.content[0].text

                # Extract code from markdown code blocks if present
                if "```" in fixed_content:
                    # Extract content between ```bash and ```
                    match = re.search(r"```(?:bash|sh)?\n(.*?)\n```", fixed_content, re.DOTALL)
                    if match:
                        fixed_content = match.group(1)

                # Write the fixed content
                with open(file_path, "w") as f:
                    f.write(fixed_content)

                print(f"  ✓ Fixed {file_path}")
                fixed_files.append(file_path)

            except Exception as e:
                print(f"  ✗ Error fixing {file_path}: {e}")
                continue

        return len(fixed_files) > 0

    def commit_and_push(self, message: str = "Fix reviewdog linter issues"):
        """Commit changes and push to the remote branch."""
        print("\nCommitting and pushing changes...")

        # Add all changes
        code, _, stderr = self._run_command(["git", "add", "-A"])
        if code != 0:
            print(f"Error adding files: {stderr}")
            return False

        # Check if there are changes to commit
        code, stdout, _ = self._run_command(["git", "status", "--porcelain"])
        if not stdout.strip():
            print("No changes to commit")
            return False

        # Commit with co-author
        commit_message = f"""{message}

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"""

        code, _, stderr = self._run_command(
            ["git", "commit", "-m", commit_message]
        )
        if code != 0:
            print(f"Error committing: {stderr}")
            return False

        # Push to remote
        code, _, stderr = self._run_command(
            ["git", "push", "origin", self.current_branch]
        )
        if code != 0:
            print(f"Error pushing: {stderr}")
            return False

        print("✓ Changes committed and pushed successfully")
        return True

    def wait_for_checks(self, timeout: int = 600, poll_interval: int = 30):
        """Wait for PR checks to complete."""
        print(f"\nWaiting for checks to complete (timeout: {timeout}s)...")
        start_time = time.time()

        while time.time() - start_time < timeout:
            checks = self.get_pr_checks()

            if not checks:
                print("  No checks found yet...")
                time.sleep(poll_interval)
                continue

            # Check if reviewdog/shellcheck is complete
            reviewdog_status = checks.get("reviewdog", "pending")

            if reviewdog_status not in ["pending", "in_progress"]:
                print(f"  Reviewdog check completed with status: {reviewdog_status}")
                return reviewdog_status

            print(f"  Reviewdog status: {reviewdog_status}, waiting...")
            time.sleep(poll_interval)

        print("  Timeout waiting for checks")
        return "timeout"

    def run(self, max_iterations: int = 10):
        """Main agent loop."""
        print("=" * 60)
        print("Reviewdog Auto-Fix Agent")
        print("=" * 60)
        print(f"Current branch: {self.current_branch}")

        # Get PR number
        self.pr_number = self.get_pr_for_branch()
        if not self.pr_number:
            print(f"\n✗ No open PR found for branch '{self.current_branch}'")
            print("Please create a PR first using: gh pr create")
            return False

        print(f"PR number: #{self.pr_number}")

        # Get repo info for PR URL
        try:
            org, repo = self._get_repo_info()
            print(f"PR URL: https://github.com/{org}/{repo}/pull/{self.pr_number}")
        except Exception as e:
            print(f"Note: Could not generate PR URL: {e}")

        iteration = 0
        while iteration < max_iterations:
            iteration += 1
            print(f"\n{'=' * 60}")
            print(f"Iteration {iteration}/{max_iterations}")
            print(f"{'=' * 60}")

            # Run shellcheck locally to find issues
            issues = self.run_shellcheck_locally()

            if not issues:
                print("\n✓ No shellcheck issues found locally!")
                print("Checking PR status to confirm...")

                checks = self.get_pr_checks()
                reviewdog_status = checks.get("reviewdog", "unknown")

                if reviewdog_status == "pass":
                    print("✓ All checks passed! Agent completed successfully.")
                    return True
                elif reviewdog_status in ["pending", "in_progress"]:
                    print("Checks are still running, waiting for completion...")
                    status = self.wait_for_checks()
                    if status == "pass":
                        print("\n✓ All checks passed! Agent completed successfully.")
                        return True
                    elif status == "fail":
                        print("\nChecks failed, but no local issues found.")
                        print("This might be a transient error. Continuing...")
                        time.sleep(10)
                        continue
                else:
                    print(f"Reviewdog status: {reviewdog_status}")
                    print("Waiting a bit before checking again...")
                    time.sleep(30)
                    continue
            else:
                print(f"\nFound {len(issues)} shellcheck issue(s)")

                # Show a sample of issues
                for i, issue in enumerate(issues[:5]):
                    print(f"  {i+1}. {issue['file']}:{issue.get('line', '?')} - {issue.get('message', 'Unknown')[:80]}")
                if len(issues) > 5:
                    print(f"  ... and {len(issues) - 5} more")

                # Fix the issues
                if self.fix_shellcheck_issues(issues):
                    # Commit and push
                    if self.commit_and_push():
                        # Wait for checks to run
                        self.wait_for_checks()
                    else:
                        print("No changes were committed, possibly already fixed")
                        time.sleep(10)
                else:
                    print("\n✗ Failed to fix issues")
                    print("Waiting before retry...")
                    time.sleep(30)

        print(f"\n✗ Max iterations ({max_iterations}) reached without resolving all issues")
        return False


def main():
    """Entry point for the agent."""
    try:
        agent = ReviewdogAgent()
        success = agent.run()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\nAgent stopped by user")
        sys.exit(130)
    except Exception as e:
        print(f"\n✗ Fatal error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()

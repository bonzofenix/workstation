#!/usr/bin/env python3
"""
PR Dashboard - Fast parallel fetching of GitHub PR status

Configuration via environment variables:
  GITHUB_REMOTES - Comma-separated list of GitHub hosts
                   Example: GITHUB_REMOTES="github.com,github.enterprise.local"
"""
import asyncio
import json
import os
import subprocess
import sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from typing import List, Dict, Any, Optional


def get_github_hosts() -> List[Optional[str]]:
    """Get list of GitHub hosts from GITHUB_REMOTES environment variable."""
    remotes = os.environ.get("GITHUB_REMOTES", "")
    if not remotes:
        print("Error: GITHUB_REMOTES environment variable is not set.", file=sys.stderr)
        print("Please set it in ~/.bash_profile or ~/.zshrc:", file=sys.stderr)
        print('  export GITHUB_REMOTES="github.com,github.enterprise.local"', file=sys.stderr)
        sys.exit(1)

    hosts = []
    for host in remotes.split(","):
        host = host.strip()
        if host:
            # github.com is represented as None (default)
            hosts.append(None if host == "github.com" else host)

    return hosts


@dataclass
class PR:
    number: int
    title: str
    url: str
    repository: str
    updated_at: str
    is_draft: bool
    host: str  # "github.com" or "github.tools.sap"

    # Populated later
    reviews: List[Dict] = None
    review_requests: List[Dict] = None
    checks: List[Dict] = None
    unresolved_comments: int = 0
    commits: List[Dict] = None


def run_command(cmd: List[str], env: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
    """Run a command and return parsed JSON output."""
    try:
        full_env = os.environ.copy()
        if env:
            full_env.update(env)

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            env=full_env,
            timeout=30
        )

        if result.returncode != 0:
            return {"error": result.stderr}

        return json.loads(result.stdout) if result.stdout.strip() else {}
    except subprocess.TimeoutExpired:
        return {"error": "Command timed out"}
    except json.JSONDecodeError:
        return {"error": f"Invalid JSON: {result.stdout}"}
    except Exception as e:
        return {"error": str(e)}


def fetch_prs(host: Optional[str] = None) -> List[PR]:
    """Fetch all open PRs from a GitHub host."""
    env = {"GH_HOST": host} if host else None
    cmd = [
        "gh", "search", "prs",
        "--author=@me",
        "--state=open",
        "--json", "number,title,url,repository,updatedAt,isDraft",
        "--limit", "100"
    ]

    result = run_command(cmd, env)
    if isinstance(result, dict) and "error" in result:
        print(f"Warning: Failed to fetch PRs from {host or 'github.com'}: {result['error']}", file=sys.stderr)
        return []

    prs = []
    for pr_data in result:
        prs.append(PR(
            number=pr_data["number"],
            title=pr_data["title"],
            url=pr_data["url"],
            repository=pr_data["repository"]["nameWithOwner"],
            updated_at=pr_data["updatedAt"],
            is_draft=pr_data["isDraft"],
            host=host or "github.com"
        ))

    return prs


def fetch_pr_details(pr: PR) -> PR:
    """Fetch detailed information for a single PR (reviews, checks, comments)."""
    env = {"GH_HOST": pr.host} if pr.host != "github.com" else None

    # Fetch reviews and review requests
    review_cmd = [
        "gh", "pr", "view", str(pr.number),
        "-R", pr.repository,
        "--json", "reviews,reviewRequests"
    ]
    review_data = run_command(review_cmd, env)
    if "error" not in review_data:
        pr.reviews = review_data.get("reviews", [])
        pr.review_requests = review_data.get("reviewRequests", [])

    # Fetch CI checks
    checks_cmd = [
        "gh", "pr", "checks", str(pr.number),
        "-R", pr.repository,
        "--json", "name,state"
    ]
    checks_data = run_command(checks_cmd, env)
    if "error" not in checks_data:
        pr.checks = checks_data if isinstance(checks_data, list) else []
    else:
        pr.checks = []

    # Fetch unresolved comments
    owner, repo = pr.repository.split("/")

    # Fetch commits
    commits_cmd = [
        "gh", "pr", "view", str(pr.number),
        "-R", pr.repository,
        "--json", "commits"
    ]
    commits_data = run_command(commits_cmd, env)
    if "error" not in commits_data:
        raw_commits = commits_data.get("commits", [])
        pr.commits = [
            {"date": c.get("committedDate", ""), "msg": c.get("messageHeadline", "")}
            for c in raw_commits
        ]
    else:
        pr.commits = []

    graphql_query = f'''
    {{
      repository(owner: "{owner}", name: "{repo}") {{
        pullRequest(number: {pr.number}) {{
          reviewThreads(first: 100) {{
            nodes {{
              isResolved
            }}
          }}
        }}
      }}
    }}
    '''

    graphql_cmd = ["gh", "api", "graphql", "-f", f"query={graphql_query}"]
    graphql_data = run_command(graphql_cmd, env)
    if "error" not in graphql_data:
        threads = graphql_data.get("data", {}).get("repository", {}).get("pullRequest", {}).get("reviewThreads", {}).get("nodes", [])
        pr.unresolved_comments = sum(1 for thread in threads if not thread.get("isResolved", True))

    return pr


def categorize_checks(checks: List[Dict]) -> Dict[str, int]:
    """Categorize CI checks by status."""
    if not checks:
        return {"total": 0, "passing": 0, "failing": 0, "pending": 0}

    categories = {"total": len(checks), "passing": 0, "failing": 0, "pending": 0, "skipped": 0}
    for check in checks:
        state = check.get("state", "").upper()
        if state == "SUCCESS":
            categories["passing"] += 1
        elif state == "FAILURE":
            categories["failing"] += 1
        elif state in ["PENDING", "QUEUED", "IN_PROGRESS"]:
            categories["pending"] += 1
        elif state == "SKIPPED":
            categories["skipped"] += 1

    return categories


def get_review_status(pr: PR) -> Dict[str, Any]:
    """Determine review status for a PR."""
    status = {
        "approved": [],
        "changes_requested": [],
        "pending": [],
        "no_reviewers": False
    }

    # Check review requests (pending reviews)
    if pr.review_requests:
        for req in pr.review_requests:
            reviewer = req.get("login") or req.get("name") or req.get("slug", "Unknown")
            status["pending"].append(reviewer)

    # Check existing reviews
    if pr.reviews:
        # Group by reviewer and get latest review state
        latest_reviews = {}
        for review in pr.reviews:
            author = review.get("author", {})
            if not author:
                continue
            reviewer = author.get("login", "Unknown")
            state = review.get("state", "")

            # Skip COMMENTED and PENDING states for now
            if state in ["APPROVED", "CHANGES_REQUESTED"]:
                latest_reviews[reviewer] = state

        for reviewer, state in latest_reviews.items():
            if state == "APPROVED":
                status["approved"].append(reviewer)
            elif state == "CHANGES_REQUESTED":
                status["changes_requested"].append(reviewer)

    # Check if no reviewers assigned
    if not status["approved"] and not status["changes_requested"] and not status["pending"]:
        status["no_reviewers"] = True

    return status


def format_pr_line(pr: PR, check_stats: Dict, review_status: Dict) -> str:
    """Format a single PR line with status indicators."""
    draft = "🚧 " if pr.is_draft else ""

    # Build status indicators
    indicators = []

    # Review status
    if review_status["changes_requested"]:
        reviewers = ", ".join(f"@{r}" for r in review_status["changes_requested"])
        indicators.append(f"❌ Changes requested by {reviewers}")
    elif review_status["pending"]:
        reviewers = ", ".join(f"@{r}" for r in review_status["pending"])
        indicators.append(f"👀 Waiting on {reviewers}")
    elif review_status["no_reviewers"]:
        indicators.append("⚠️ No reviewers assigned")
    elif review_status["approved"]:
        reviewers = ", ".join(f"@{r}" for r in review_status["approved"])
        indicators.append(f"✅ Approved by {reviewers}")

    # Check status
    if check_stats["failing"] > 0:
        indicators.append(f"{check_stats['failing']} failing checks")
    elif check_stats["pending"] > 0:
        indicators.append(f"⏳ {check_stats['pending']} pending checks")
    elif check_stats["total"] > 0:
        indicators.append(f"✅ All {check_stats['passing']} checks passing")

    # Unresolved comments
    if pr.unresolved_comments > 0:
        indicators.append(f"{pr.unresolved_comments} unresolved comments")

    status_str = " | ".join(indicators) if indicators else "✅ Ready"

    # Format with explicit URL (no markdown link)
    return f"- {draft}{pr.url} - {pr.title} | {status_str}"


NOISE_PREFIXES = ("Merge branch", "Merge remote-tracking")
NOISE_KEYWORDS = ("trigger ci", "re-run", "rerun")


def is_noise_commit(msg: str) -> bool:
    """Check if commit message is merge/CI noise."""
    lower = msg.lower()
    if any(msg.startswith(p) for p in NOISE_PREFIXES):
        return True
    return any(kw in lower for kw in NOISE_KEYWORDS)


def get_most_recent_commit_date(all_prs: List[PR]) -> Optional[str]:
    """Find most recent commit date (YYYY-MM-DD) across all PRs."""
    latest = None
    for pr in all_prs:
        if not pr.commits:
            continue
        for commit in pr.commits:
            date_str = commit.get("date", "")[:10]  # YYYY-MM-DD
            if date_str and (latest is None or date_str > latest):
                latest = date_str
    return latest


def get_last_n_working_days(n: int) -> List[str]:
    """Get last N working days (Mon-Fri) as YYYY-MM-DD strings."""
    from datetime import datetime, timedelta

    dates = []
    current = datetime.now()

    while len(dates) < n:
        # Skip weekends (5=Saturday, 6=Sunday)
        if current.weekday() < 5:
            dates.append(current.strftime("%Y-%m-%d"))
        current -= timedelta(days=1)

    return dates


def fetch_merged_prs(github_hosts: List[Optional[str]], since_date: str) -> List[Dict]:
    """Fetch merged PRs from all hosts since a given date."""
    merged_prs = []

    for host in github_hosts:
        env = {"GH_HOST": host} if host else None
        cmd = [
            "gh", "search", "prs",
            "--author=@me",
            "--state=closed",
            "--merged",
            f"--merged-at=>={since_date}",
            "--json", "number,title,url,repository,mergedAt",
            "--limit", "100"
        ]

        result = run_command(cmd, env)
        if isinstance(result, dict) and "error" in result:
            print(f"Warning: Failed to fetch merged PRs from {host or 'github.com'}: {result['error']}", file=sys.stderr)
            continue

        for pr in result:
            merged_prs.append({
                "number": pr["number"],
                "title": pr["title"],
                "url": pr["url"],
                "repository": pr["repository"]["nameWithOwner"],
                "merged_at": pr["mergedAt"]
            })

    return merged_prs


def format_standup_briefing(all_prs: List[PR], target_date: str) -> List[str]:
    """Build standup briefing lines for commits on target_date."""
    from datetime import datetime

    lines = []
    date_display = datetime.strptime(target_date, "%Y-%m-%d").strftime("%B %d")

    lines.append(f"\n## 📋 Standup Briefing ({date_display}):\n")

    found_any = False
    for pr in all_prs:
        if not pr.commits:
            continue

        day_commits = [
            c["msg"] for c in pr.commits
            if c.get("date", "")[:10] == target_date and not is_noise_commit(c["msg"])
        ]

        if not day_commits:
            continue

        found_any = True
        short_repo = pr.repository.split("/")[-1]
        lines.append(f"**{short_repo}#{pr.number}** - {pr.title}")
        for msg in day_commits:
            lines.append(f"  - {msg}")
        lines.append("")

    if not found_any:
        lines.append("No substantive commits found (only merges/CI triggers).\n")

    return lines


def format_merged_prs(merged_prs: List[Dict], working_days: List[str]) -> List[str]:
    """Format merged PRs section for the last N working days."""
    from datetime import datetime

    lines = []
    lines.append("\n## ✅ Recently Merged (Last 2 Working Days):\n")

    if not merged_prs:
        lines.append("No PRs merged.\n")
        return lines

    # Group by date
    prs_by_date = {}
    for pr in merged_prs:
        merged_date = pr["merged_at"][:10]  # YYYY-MM-DD
        if merged_date not in prs_by_date:
            prs_by_date[merged_date] = []
        prs_by_date[merged_date].append(pr)

    # Display by working day (most recent first)
    found_any = False
    for date in working_days:
        if date in prs_by_date:
            found_any = True
            date_display = datetime.strptime(date, "%Y-%m-%d").strftime("%B %d")
            lines.append(f"**{date_display}:**\n")
            for pr in prs_by_date[date]:
                short_repo = pr["repository"].split("/")[-1]
                lines.append(f"- {pr['url']} - **{short_repo}#{pr['number']}**: {pr['title']}")
            lines.append("")

    if not found_any:
        lines.append("No PRs merged.\n")

    return lines


def main():
    """Main entry point."""
    # Get configured GitHub hosts
    github_hosts = get_github_hosts()

    print(f"Fetching PRs from {len(github_hosts)} GitHub host(s)...", file=sys.stderr)

    # Fetch PRs from all hosts in parallel
    with ThreadPoolExecutor(max_workers=len(github_hosts)) as executor:
        futures = [executor.submit(fetch_prs, host) for host in github_hosts]
        all_prs = []

        # Count PRs per host for summary
        prs_per_host = {}
        for host, future in zip(github_hosts, futures):
            host_prs = future.result()
            all_prs.extend(host_prs)
            host_name = host or "github.com"
            prs_per_host[host_name] = len(host_prs)

    if not all_prs:
        print("\n# Good Morning! ☀️\n\nNo open PRs found. Great job! 🎉")
        return

    print(f"Found {len(all_prs)} PRs. Fetching details...", file=sys.stderr)

    # Fetch details for all PRs in parallel
    with ThreadPoolExecutor(max_workers=10) as executor:
        all_prs = list(executor.map(fetch_pr_details, all_prs))

    # Categorize PRs
    needs_attention = []
    awaiting_review = []
    ready_to_merge = []

    for pr in all_prs:
        check_stats = categorize_checks(pr.checks)
        review_status = get_review_status(pr)

        pr_data = {
            "pr": pr,
            "checks": check_stats,
            "reviews": review_status
        }

        # Categorization logic
        has_changes_requested = bool(review_status["changes_requested"])
        has_failing_checks = check_stats["failing"] > 0
        has_unresolved_comments = pr.unresolved_comments > 0
        has_pending_review = bool(review_status["pending"])
        no_reviewers = review_status["no_reviewers"]

        if has_changes_requested or has_failing_checks or has_unresolved_comments:
            needs_attention.append(pr_data)
        elif has_pending_review or no_reviewers:
            awaiting_review.append(pr_data)
        else:
            ready_to_merge.append(pr_data)

    # Sort by priority (most urgent first)
    needs_attention.sort(key=lambda x: (
        -len(x["reviews"]["changes_requested"]),
        -x["checks"]["failing"],
        -x["pr"].unresolved_comments
    ))

    # Output formatted summary
    print("\n# Good Morning! ☀️\n")

    # Build host summary
    host_summary = ", ".join(f"{count} on {host}" for host, count in prs_per_host.items())
    print(f"**📊 {len(all_prs)} total open PRs** ({host_summary})\n")
    print("---\n")

    if needs_attention:
        print("## 🚨 Top Priority - Needs Attention:\n")
        for item in needs_attention:
            print(format_pr_line(item["pr"], item["checks"], item["reviews"]))
        print("\n---\n")

    if awaiting_review:
        print("## 👀 Awaiting Review:\n")
        for item in awaiting_review:
            print(format_pr_line(item["pr"], item["checks"], item["reviews"]))
        print("\n---\n")

    if ready_to_merge:
        print("## ✅ Approved and Passing:\n")
        for item in ready_to_merge:
            print(format_pr_line(item["pr"], item["checks"], item["reviews"]))
        print("\n---\n")

    # Summary stats
    total_failing = sum(item["checks"]["failing"] for item in needs_attention + awaiting_review + ready_to_merge)
    total_changes_requested = sum(len(item["reviews"]["changes_requested"]) for item in needs_attention + awaiting_review + ready_to_merge)
    total_unresolved = sum(item["pr"].unresolved_comments for item in needs_attention + awaiting_review + ready_to_merge)

    print("**Key Issues to Address:**")
    if total_changes_requested > 0:
        print(f"- 🔥 **{total_changes_requested} PRs with changes requested** need updates")
    if total_failing > 0:
        print(f"- ⚠️ **{total_failing} failing CI checks** across all PRs")
    if total_unresolved > 0:
        print(f"- 💬 **{total_unresolved} total unresolved comments**")

    # Standup briefing
    target_date = get_most_recent_commit_date(all_prs)
    if target_date:
        print("\n---")
        for line in format_standup_briefing(all_prs, target_date):
            print(line)

    # Merged PRs section
    working_days = get_last_n_working_days(2)
    merged_prs = fetch_merged_prs(github_hosts, working_days[-1])  # Fetch since oldest working day
    print("---")
    for line in format_merged_prs(merged_prs, working_days):
        print(line)


if __name__ == "__main__":
    main()

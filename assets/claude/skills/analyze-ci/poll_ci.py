#!/usr/bin/env python3
"""
poll-ci - Poll GitHub CI checks until all complete
Used by analyze-ci skill. Resilient to network hiccups.
Usage: poll_ci.py [--interval SECONDS] [--timeout SECONDS]

Defaults: interval=30s, timeout=3600s (1h)
"""
import argparse
import json
import subprocess
import sys
import time
from datetime import datetime
from typing import Dict, Any, Optional


def current_time() -> str:
    """Return current time as HH:MM:SS string."""
    return datetime.now().strftime("%H:%M:%S")


def run_gh_command(args: list[str]) -> tuple[Optional[Dict[str, Any]], Optional[str]]:
    """
    Run gh CLI command and return (parsed_json, error).
    Returns (None, error_msg) on failure.
    """
    try:
        result = subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            return None, result.stderr.strip()

        if not result.stdout.strip():
            return None, "Empty response from gh"

        return json.loads(result.stdout), None

    except subprocess.TimeoutExpired:
        return None, "Command timed out"
    except json.JSONDecodeError as e:
        return None, f"Invalid JSON: {e}"
    except Exception as e:
        return None, str(e)


def count_pending_checks(checks: list[Dict[str, Any]]) -> int:
    """Count number of checks with 'pending' bucket."""
    if not checks:
        return 0
    return sum(1 for check in checks if check.get("bucket") == "pending")


def fetch_check_status() -> tuple[Optional[list], Optional[str]]:
    """
    Fetch CI check status from GitHub.
    Returns (checks_list, error).
    """
    cmd = ["gh", "pr", "checks", "--json", "name,state,bucket"]
    checks, error = run_gh_command(cmd)

    if error:
        return None, error

    if not isinstance(checks, list):
        return None, f"Expected list, got {type(checks)}"

    return checks, None


def display_final_checks():
    """Display final check status table."""
    result = subprocess.run(
        ["gh", "pr", "checks"],
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        print(result.stdout)


def poll_checks(interval: int = 30, timeout: int = 3600) -> int:
    """
    Poll CI checks until all complete or timeout.
    Returns 0 on success, 1 on timeout.
    """
    start_time = time.time()

    while True:
        elapsed = int(time.time() - start_time)

        # Check timeout
        if elapsed >= timeout:
            print(f"[{current_time()}] Timeout after {timeout}s")
            display_final_checks()
            return 1

        # Fetch check status
        checks, error = fetch_check_status()

        if error:
            print(f"[{current_time()}] gh error (retrying in {interval}s): {error}")
            time.sleep(interval)
            continue

        # Count pending checks
        pending = count_pending_checks(checks)

        if pending == 0:
            print(f"[{current_time()}] All checks complete!")
            display_final_checks()
            return 0

        print(f"[{current_time()}] {pending} checks still pending...")
        time.sleep(interval)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Poll GitHub CI checks until all complete"
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=30,
        help="Poll interval in seconds (default: 30)"
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=3600,
        help="Timeout in seconds (default: 3600 = 1h)"
    )

    args = parser.parse_args()

    # Validate arguments
    if args.interval <= 0:
        print("Error: interval must be positive", file=sys.stderr)
        return 1

    if args.timeout <= 0:
        print("Error: timeout must be positive", file=sys.stderr)
        return 1

    return poll_checks(interval=args.interval, timeout=args.timeout)


if __name__ == "__main__":
    sys.exit(main())

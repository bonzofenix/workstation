#!/usr/bin/env python3
"""Tests for poll_ci.py"""
import os
import sys
import subprocess
import pytest
import json
from unittest.mock import Mock, patch, call
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from poll_ci import (
    current_time,
    run_gh_command,
    count_pending_checks,
    fetch_check_status,
    poll_checks
)


class TestCurrentTime:
    def test_returns_hh_mm_ss_format(self):
        result = current_time()
        assert len(result) == 8
        assert result[2] == ":"
        assert result[5] == ":"

    def test_returns_valid_time(self):
        result = current_time()
        parts = result.split(":")
        assert len(parts) == 3
        hours, minutes, seconds = map(int, parts)
        assert 0 <= hours <= 23
        assert 0 <= minutes <= 59
        assert 0 <= seconds <= 59


class TestRunGhCommand:
    def test_success(self):
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(
                returncode=0,
                stdout='{"key": "value"}',
                stderr=""
            )

            result, error = run_gh_command(["gh", "pr", "checks"])
            assert result == {"key": "value"}
            assert error is None

    def test_command_failure(self):
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(
                returncode=1,
                stdout="",
                stderr="Error: no PR found"
            )

            result, error = run_gh_command(["gh", "pr", "checks"])
            assert result is None
            assert error == "Error: no PR found"

    def test_empty_response(self):
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(
                returncode=0,
                stdout="",
                stderr=""
            )

            result, error = run_gh_command(["gh", "pr", "checks"])
            assert result is None
            assert error == "Empty response from gh"

    def test_invalid_json(self):
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(
                returncode=0,
                stdout="not json",
                stderr=""
            )

            result, error = run_gh_command(["gh", "pr", "checks"])
            assert result is None
            assert "Invalid JSON" in error

    def test_timeout(self):
        with patch("subprocess.run") as mock_run:
            mock_run.side_effect = subprocess.TimeoutExpired(cmd=["gh"], timeout=30)

            result, error = run_gh_command(["gh", "pr", "checks"])
            assert result is None
            assert error == "Command timed out"


class TestCountPendingChecks:
    def test_empty_list(self):
        assert count_pending_checks([]) == 0

    def test_no_pending(self):
        checks = [
            {"name": "test", "bucket": "pass"},
            {"name": "lint", "bucket": "pass"}
        ]
        assert count_pending_checks(checks) == 0

    def test_all_pending(self):
        checks = [
            {"name": "test", "bucket": "pending"},
            {"name": "lint", "bucket": "pending"}
        ]
        assert count_pending_checks(checks) == 2

    def test_mixed(self):
        checks = [
            {"name": "test", "bucket": "pending"},
            {"name": "lint", "bucket": "pass"},
            {"name": "build", "bucket": "pending"}
        ]
        assert count_pending_checks(checks) == 2

    def test_missing_bucket(self):
        checks = [
            {"name": "test"},  # No bucket field
            {"name": "lint", "bucket": "pending"}
        ]
        assert count_pending_checks(checks) == 1


class TestFetchCheckStatus:
    def test_success(self):
        checks_data = [
            {"name": "test", "state": "SUCCESS", "bucket": "pass"},
            {"name": "lint", "state": "PENDING", "bucket": "pending"}
        ]

        with patch("poll_ci.run_gh_command") as mock_run:
            mock_run.return_value = (checks_data, None)

            checks, error = fetch_check_status()
            assert checks == checks_data
            assert error is None

    def test_command_error(self):
        with patch("poll_ci.run_gh_command") as mock_run:
            mock_run.return_value = (None, "Network error")

            checks, error = fetch_check_status()
            assert checks is None
            assert error == "Network error"

    def test_invalid_response_type(self):
        with patch("poll_ci.run_gh_command") as mock_run:
            mock_run.return_value = ({"not": "a list"}, None)

            checks, error = fetch_check_status()
            assert checks is None
            assert "Expected list" in error


class TestPollChecks:
    def test_immediate_completion(self):
        """All checks complete on first poll."""
        checks_data = [
            {"name": "test", "bucket": "pass"},
            {"name": "lint", "bucket": "pass"}
        ]

        with patch("poll_ci.fetch_check_status") as mock_fetch, \
             patch("poll_ci.display_final_checks") as mock_display:

            mock_fetch.return_value = (checks_data, None)

            result = poll_checks(interval=1, timeout=10)
            assert result == 0
            assert mock_fetch.call_count == 1
            mock_display.assert_called_once()

    def test_waits_for_completion(self):
        """Pending checks eventually complete."""
        pending_checks = [{"name": "test", "bucket": "pending"}]
        complete_checks = [{"name": "test", "bucket": "pass"}]

        with patch("poll_ci.fetch_check_status") as mock_fetch, \
             patch("poll_ci.display_final_checks") as mock_display, \
             patch("time.sleep") as mock_sleep:

            # First two calls return pending, third returns complete
            mock_fetch.side_effect = [
                (pending_checks, None),
                (pending_checks, None),
                (complete_checks, None)
            ]

            result = poll_checks(interval=1, timeout=10)
            assert result == 0
            assert mock_fetch.call_count == 3
            assert mock_sleep.call_count == 2

    def test_timeout(self):
        """Timeout occurs before completion."""
        pending_checks = [{"name": "test", "bucket": "pending"}]

        with patch("poll_ci.fetch_check_status") as mock_fetch, \
             patch("poll_ci.display_final_checks") as mock_display, \
             patch("time.time") as mock_time, \
             patch("time.sleep"):

            # Simulate time passing
            mock_time.side_effect = [0, 0, 3600, 3601]  # Start, first check, timeout
            mock_fetch.return_value = (pending_checks, None)

            result = poll_checks(interval=1, timeout=3600)
            assert result == 1
            mock_display.assert_called_once()

    def test_retry_on_error(self):
        """Retries on network error."""
        pending_checks = [{"name": "test", "bucket": "pending"}]
        complete_checks = [{"name": "test", "bucket": "pass"}]

        with patch("poll_ci.fetch_check_status") as mock_fetch, \
             patch("poll_ci.display_final_checks") as mock_display, \
             patch("time.sleep") as mock_sleep:

            # First call errors, second returns pending, third completes
            mock_fetch.side_effect = [
                (None, "Network error"),
                (pending_checks, None),
                (complete_checks, None)
            ]

            result = poll_checks(interval=1, timeout=10)
            assert result == 0
            assert mock_fetch.call_count == 3

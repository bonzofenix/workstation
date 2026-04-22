#!/usr/bin/env python3
"""Tests for pr-dashboard.py"""
import os
import sys
import pytest
from datetime import datetime, timedelta
from unittest.mock import Mock, patch

# Add parent directory to path so we can import pr_dashboard
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pr_dashboard
from pr_dashboard import (
    get_github_hosts,
    categorize_checks,
    get_review_status,
    is_noise_commit,
    get_last_n_working_days,
    format_pr_line,
    get_most_recent_commit_date,
    PR
)


class TestGetGithubHosts:
    def test_parses_single_host(self):
        with patch.dict(os.environ, {"GITHUB_REMOTES": "github.com"}):
            assert get_github_hosts() == [None]

    def test_parses_multiple_hosts(self):
        with patch.dict(os.environ, {"GITHUB_REMOTES": "github.com,github.enterprise.local"}):
            hosts = get_github_hosts()
            assert hosts == [None, "github.enterprise.local"]

    def test_strips_whitespace(self):
        with patch.dict(os.environ, {"GITHUB_REMOTES": " github.com , github.tools.sap "}):
            hosts = get_github_hosts()
            assert hosts == [None, "github.tools.sap"]

    def test_exits_when_not_set(self):
        with patch.dict(os.environ, {}, clear=True):
            with pytest.raises(SystemExit):
                get_github_hosts()


class TestCategorizeChecks:
    def test_empty_checks(self):
        result = categorize_checks([])
        assert result == {"total": 0, "passing": 0, "failing": 0, "pending": 0}

    def test_success_checks(self):
        checks = [
            {"name": "test", "state": "SUCCESS"},
            {"name": "build", "state": "SUCCESS"}
        ]
        result = categorize_checks(checks)
        assert result["passing"] == 2
        assert result["total"] == 2

    def test_failure_checks(self):
        checks = [{"name": "lint", "state": "FAILURE"}]
        result = categorize_checks(checks)
        assert result["failing"] == 1

    def test_pending_checks(self):
        checks = [
            {"name": "test", "state": "PENDING"},
            {"name": "build", "state": "IN_PROGRESS"},
            {"name": "deploy", "state": "QUEUED"}
        ]
        result = categorize_checks(checks)
        assert result["pending"] == 3

    def test_skipped_checks(self):
        checks = [{"name": "optional", "state": "SKIPPED"}]
        result = categorize_checks(checks)
        assert result["skipped"] == 1

    def test_mixed_checks(self):
        checks = [
            {"name": "test", "state": "SUCCESS"},
            {"name": "lint", "state": "FAILURE"},
            {"name": "build", "state": "PENDING"}
        ]
        result = categorize_checks(checks)
        assert result["total"] == 3
        assert result["passing"] == 1
        assert result["failing"] == 1
        assert result["pending"] == 1


class TestGetReviewStatus:
    def test_no_reviewers(self):
        pr = PR(1, "title", "url", "repo", "2024-01-01", False, "github.com")
        pr.reviews = []
        pr.review_requests = []

        status = get_review_status(pr)
        assert status["no_reviewers"] is True
        assert status["approved"] == []
        assert status["changes_requested"] == []

    def test_pending_reviews(self):
        pr = PR(1, "title", "url", "repo", "2024-01-01", False, "github.com")
        pr.reviews = []
        pr.review_requests = [{"login": "alice"}, {"login": "bob"}]

        status = get_review_status(pr)
        assert status["pending"] == ["alice", "bob"]
        assert status["no_reviewers"] is False

    def test_approved(self):
        pr = PR(1, "title", "url", "repo", "2024-01-01", False, "github.com")
        pr.reviews = [
            {"author": {"login": "alice"}, "state": "APPROVED"}
        ]
        pr.review_requests = []

        status = get_review_status(pr)
        assert status["approved"] == ["alice"]

    def test_changes_requested(self):
        pr = PR(1, "title", "url", "repo", "2024-01-01", False, "github.com")
        pr.reviews = [
            {"author": {"login": "bob"}, "state": "CHANGES_REQUESTED"}
        ]
        pr.review_requests = []

        status = get_review_status(pr)
        assert status["changes_requested"] == ["bob"]

    def test_latest_review_wins(self):
        pr = PR(1, "title", "url", "repo", "2024-01-01", False, "github.com")
        pr.reviews = [
            {"author": {"login": "alice"}, "state": "CHANGES_REQUESTED"},
            {"author": {"login": "alice"}, "state": "APPROVED"}
        ]
        pr.review_requests = []

        status = get_review_status(pr)
        assert status["approved"] == ["alice"]
        assert status["changes_requested"] == []

    def test_ignores_commented_state(self):
        pr = PR(1, "title", "url", "repo", "2024-01-01", False, "github.com")
        pr.reviews = [
            {"author": {"login": "alice"}, "state": "COMMENTED"}
        ]
        pr.review_requests = []

        status = get_review_status(pr)
        assert status["no_reviewers"] is True


class TestIsNoiseCommit:
    def test_merge_branch(self):
        assert is_noise_commit("Merge branch 'main' into feature") is True
        assert is_noise_commit("Merge remote-tracking branch 'origin/main'") is True

    def test_ci_trigger(self):
        assert is_noise_commit("trigger ci") is True
        assert is_noise_commit("Trigger CI") is True
        assert is_noise_commit("re-run tests") is True
        assert is_noise_commit("rerun ci") is True

    def test_real_commits(self):
        assert is_noise_commit("fix: resolve auth bug") is False
        assert is_noise_commit("feat: add user dashboard") is False


class TestGetLastNWorkingDays:
    def test_returns_n_days(self):
        days = get_last_n_working_days(5)
        assert len(days) == 5

    def test_returns_dates_in_descending_order(self):
        days = get_last_n_working_days(3)
        assert days[0] > days[1] > days[2]

    def test_skips_weekends(self):
        days = get_last_n_working_days(10)
        for day_str in days:
            day = datetime.strptime(day_str, "%Y-%m-%d")
            # Monday=0, Friday=4, Saturday=5, Sunday=6
            assert day.weekday() < 5

    def test_date_format(self):
        days = get_last_n_working_days(1)
        # Should match YYYY-MM-DD
        assert len(days[0]) == 10
        assert days[0][4] == "-"
        assert days[0][7] == "-"


class TestFormatPRLine:
    def test_draft_indicator(self):
        pr = PR(1, "Title", "https://github.com/owner/repo/pull/1",
                "owner/repo", "2024-01-01", True, "github.com")
        pr.checks = []
        pr.reviews = []
        pr.review_requests = []
        pr.unresolved_comments = 0

        check_stats = {"total": 0, "passing": 0, "failing": 0, "pending": 0}
        review_status = {"approved": [], "changes_requested": [], "pending": [], "no_reviewers": True}

        line = format_pr_line(pr, check_stats, review_status)
        assert line.startswith("- 🚧")

    def test_changes_requested(self):
        pr = PR(1, "Title", "https://github.com/owner/repo/pull/1",
                "owner/repo", "2024-01-01", False, "github.com")
        pr.checks = []
        pr.unresolved_comments = 0

        check_stats = {"total": 0, "passing": 0, "failing": 0, "pending": 0}
        review_status = {"approved": [], "changes_requested": ["alice"], "pending": [], "no_reviewers": False}

        line = format_pr_line(pr, check_stats, review_status)
        assert "Changes requested by @alice" in line

    def test_failing_checks(self):
        pr = PR(1, "Title", "https://github.com/owner/repo/pull/1",
                "owner/repo", "2024-01-01", False, "github.com")
        pr.unresolved_comments = 0

        check_stats = {"total": 2, "passing": 0, "failing": 2, "pending": 0}
        review_status = {"approved": [], "changes_requested": [], "pending": [], "no_reviewers": True}

        line = format_pr_line(pr, check_stats, review_status)
        assert "2 failing checks" in line

    def test_unresolved_comments(self):
        pr = PR(1, "Title", "https://github.com/owner/repo/pull/1",
                "owner/repo", "2024-01-01", False, "github.com")
        pr.unresolved_comments = 3

        check_stats = {"total": 0, "passing": 0, "failing": 0, "pending": 0}
        review_status = {"approved": [], "changes_requested": [], "pending": [], "no_reviewers": True}

        line = format_pr_line(pr, check_stats, review_status)
        assert "3 unresolved comments" in line

    def test_ready_status(self):
        pr = PR(1, "Title", "https://github.com/owner/repo/pull/1",
                "owner/repo", "2024-01-01", False, "github.com")
        pr.checks = []
        pr.unresolved_comments = 0

        check_stats = {"total": 0, "passing": 0, "failing": 0, "pending": 0}
        review_status = {"approved": ["bob"], "changes_requested": [], "pending": [], "no_reviewers": False}

        line = format_pr_line(pr, check_stats, review_status)
        assert "Approved by @bob" in line


class TestGetMostRecentCommitDate:
    def test_empty_prs(self):
        assert get_most_recent_commit_date([]) is None

    def test_no_commits(self):
        pr = PR(1, "title", "url", "repo", "2024-01-01", False, "github.com")
        pr.commits = []
        assert get_most_recent_commit_date([pr]) is None

    def test_single_commit(self):
        pr = PR(1, "title", "url", "repo", "2024-01-01", False, "github.com")
        pr.commits = [{"date": "2024-01-15T10:00:00Z", "msg": "fix"}]
        assert get_most_recent_commit_date([pr]) == "2024-01-15"

    def test_multiple_commits(self):
        pr1 = PR(1, "title", "url", "repo", "2024-01-01", False, "github.com")
        pr1.commits = [{"date": "2024-01-10T10:00:00Z", "msg": "fix"}]

        pr2 = PR(2, "title", "url", "repo", "2024-01-01", False, "github.com")
        pr2.commits = [{"date": "2024-01-15T10:00:00Z", "msg": "feat"}]

        assert get_most_recent_commit_date([pr1, pr2]) == "2024-01-15"

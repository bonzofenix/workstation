#!/usr/bin/env python3
"""Tests for run_in_container.py"""
import os
import sys
import subprocess
import pytest
from unittest.mock import Mock, patch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run_in_container import (
    Container,
    run_command,
    find_containers,
    select_container,
    exec_in_container,
    get_container_info
)


class TestContainer:
    def test_creation(self):
        c = Container("abc123", "my-container", "Up 2 hours")
        assert c.id == "abc123"
        assert c.name == "my-container"
        assert c.status == "Up 2 hours"

    def test_repr(self):
        c = Container("abc123", "my-container", "Up 2 hours")
        assert "abc123" in repr(c)
        assert "my-container" in repr(c)


class TestRunCommand:
    def test_success(self):
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(
                returncode=0,
                stdout="output",
                stderr=""
            )

            exit_code, stdout, stderr = run_command(["echo", "test"])
            assert exit_code == 0
            assert stdout == "output"
            assert stderr == ""

    def test_failure(self):
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(
                returncode=1,
                stdout="",
                stderr="error"
            )

            exit_code, stdout, stderr = run_command(["false"])
            assert exit_code == 1
            assert stderr == "error"

    def test_timeout(self):
        with patch("subprocess.run") as mock_run:
            mock_run.side_effect = subprocess.TimeoutExpired(cmd=["sleep"], timeout=30)

            exit_code, stdout, stderr = run_command(["sleep", "100"])
            assert exit_code == 1
            assert "timed out" in stderr

    def test_not_found(self):
        with patch("subprocess.run") as mock_run:
            mock_run.side_effect = FileNotFoundError()

            exit_code, stdout, stderr = run_command(["nonexistent"])
            assert exit_code == 1
            assert "not found" in stderr


class TestFindContainers:
    def test_no_containers(self):
        with patch("run_in_container.run_command") as mock_cmd:
            mock_cmd.return_value = (0, "", "")

            containers = find_containers()
            assert containers == []

    def test_single_container(self):
        with patch("run_in_container.run_command") as mock_cmd:
            mock_cmd.return_value = (0, "abc123\tmy-app\tUp 2 hours", "")

            containers = find_containers()
            assert len(containers) == 1
            assert containers[0].id == "abc123"
            assert containers[0].name == "my-app"
            assert containers[0].status == "Up 2 hours"

    def test_multiple_containers(self):
        output = "abc123\tapp-1\tUp 1 hour\ndef456\tapp-2\tUp 2 hours"
        with patch("run_in_container.run_command") as mock_cmd:
            mock_cmd.return_value = (0, output, "")

            containers = find_containers()
            assert len(containers) == 2
            assert containers[0].name == "app-1"
            assert containers[1].name == "app-2"

    def test_docker_error(self):
        with patch("run_in_container.run_command") as mock_cmd:
            mock_cmd.return_value = (1, "", "Docker not running")

            containers = find_containers()
            assert containers == []

    def test_custom_filter(self):
        with patch("run_in_container.run_command") as mock_cmd:
            mock_cmd.return_value = (0, "abc123\tcustom-app\tUp", "")

            containers = find_containers("custom-app")
            assert len(containers) == 1
            mock_cmd.assert_called_once()
            # Check filter was used
            call_args = mock_cmd.call_args[0][0]
            assert "name=custom-app" in call_args


class TestSelectContainer:
    def test_empty_list(self):
        assert select_container([]) is None

    def test_single_auto_select(self):
        c = Container("abc123", "app", "Up")
        result = select_container([c])
        assert result == c

    def test_multiple_requires_selection(self):
        c1 = Container("abc123", "app-1", "Up")
        c2 = Container("def456", "app-2", "Up")
        result = select_container([c1, c2])
        assert result is None

    def test_select_by_id(self):
        c1 = Container("abc123", "app-1", "Up")
        c2 = Container("def456", "app-2", "Up")
        result = select_container([c1, c2], "abc")
        assert result == c1

    def test_select_by_full_id(self):
        c = Container("abc123", "app", "Up")
        result = select_container([c], "abc123")
        assert result == c

    def test_select_by_name(self):
        c1 = Container("abc123", "app-1", "Up")
        c2 = Container("def456", "app-2", "Up")
        result = select_container([c1, c2], "app-2")
        assert result == c2

    def test_select_not_found(self):
        c = Container("abc123", "app", "Up")
        result = select_container([c], "xyz")
        assert result is None


class TestExecInContainer:
    def test_basic_command(self):
        c = Container("abc123", "app", "Up")
        with patch("run_in_container.run_command") as mock_cmd:
            mock_cmd.return_value = (0, "output", "")

            exit_code, stdout, stderr = exec_in_container(c, "ls -la")
            assert exit_code == 0
            assert stdout == "output"

            # Check docker exec was called
            call_args = mock_cmd.call_args[0][0]
            assert call_args[0] == "docker"
            assert call_args[1] == "exec"
            assert "abc123" in call_args

    def test_interactive_flag(self):
        c = Container("abc123", "app", "Up")
        with patch("run_in_container.run_command") as mock_cmd:
            mock_cmd.return_value = (0, "", "")

            exec_in_container(c, "/bin/bash", interactive=True)

            call_args = mock_cmd.call_args[0][0]
            assert "-it" in call_args

    def test_user_flag(self):
        c = Container("abc123", "app", "Up")
        with patch("run_in_container.run_command") as mock_cmd:
            mock_cmd.return_value = (0, "", "")

            exec_in_container(c, "whoami", user="root")

            call_args = mock_cmd.call_args[0][0]
            assert "-u" in call_args
            assert "root" in call_args

    def test_workdir_flag(self):
        c = Container("abc123", "app", "Up")
        with patch("run_in_container.run_command") as mock_cmd:
            mock_cmd.return_value = (0, "", "")

            exec_in_container(c, "pwd", workdir="/app")

            call_args = mock_cmd.call_args[0][0]
            assert "-w" in call_args
            assert "/app" in call_args


class TestGetContainerInfo:
    def test_success(self):
        c = Container("abc123", "app", "Up")
        info = {"Id": "abc123", "Name": "app"}

        with patch("run_in_container.run_command") as mock_cmd, \
             patch("json.loads") as mock_json:
            mock_cmd.return_value = (0, '[{"Id": "abc123"}]', "")
            mock_json.return_value = [info]

            result = get_container_info(c)
            assert result == info

    def test_docker_error(self):
        c = Container("abc123", "app", "Up")
        with patch("run_in_container.run_command") as mock_cmd:
            mock_cmd.return_value = (1, "", "Error")

            result = get_container_info(c)
            assert result == {}

    def test_invalid_json(self):
        c = Container("abc123", "app", "Up")
        with patch("run_in_container.run_command") as mock_cmd:
            mock_cmd.return_value = (0, "not json", "")

            result = get_container_info(c)
            assert result == {}

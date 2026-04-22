#!/usr/bin/env python3
"""
run_in_container - Execute commands in running product-cf-hcp containers
"""
import argparse
import json
import subprocess
import sys
from typing import List, Dict, Optional, Tuple


class Container:
    """Represents a Docker container."""
    def __init__(self, container_id: str, name: str, status: str):
        self.id = container_id
        self.name = name
        self.status = status

    def __repr__(self):
        return f"Container(id={self.id}, name={self.name}, status={self.status})"


def run_command(cmd: List[str], check: bool = True) -> Tuple[int, str, str]:
    """
    Run shell command and return (exit_code, stdout, stderr).
    """
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )
        return result.returncode, result.stdout, result.stderr

    except subprocess.TimeoutExpired:
        return 1, "", "Command timed out"
    except FileNotFoundError:
        return 1, "", f"Command not found: {cmd[0]}"
    except Exception as e:
        return 1, "", str(e)


def find_containers(name_filter: str = "product-cf-hcp") -> List[Container]:
    """
    Find running containers matching name filter.
    Returns list of Container objects.
    """
    cmd = [
        "docker", "ps",
        "--filter", f"name={name_filter}",
        "--format", "{{.ID}}\t{{.Names}}\t{{.Status}}"
    ]

    exit_code, stdout, stderr = run_command(cmd)

    if exit_code != 0:
        return []

    containers = []
    for line in stdout.strip().split("\n"):
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) >= 3:
            containers.append(Container(
                container_id=parts[0],
                name=parts[1],
                status=parts[2]
            ))

    return containers


def select_container(containers: List[Container], container_id_or_name: Optional[str] = None) -> Optional[Container]:
    """
    Select a container from the list.
    If container_id_or_name specified, match by ID or name.
    If only one container, auto-select it.
    """
    if not containers:
        return None

    if container_id_or_name:
        # Try to match by ID or name
        for c in containers:
            if c.id.startswith(container_id_or_name) or c.name == container_id_or_name:
                return c
        return None

    # Auto-select if only one
    if len(containers) == 1:
        return containers[0]

    return None


def exec_in_container(container: Container, command: str, interactive: bool = False, user: Optional[str] = None, workdir: Optional[str] = None) -> Tuple[int, str, str]:
    """
    Execute command in container.
    Returns (exit_code, stdout, stderr).
    """
    cmd = ["docker", "exec"]

    if interactive:
        cmd.append("-it")

    if user:
        cmd.extend(["-u", user])

    if workdir:
        cmd.extend(["-w", workdir])

    cmd.append(container.id)

    # Parse command string into args
    if isinstance(command, str):
        # Simple split on spaces (doesn't handle quotes properly, but good enough)
        cmd.extend(command.split())
    else:
        cmd.extend(command)

    return run_command(cmd)


def get_container_info(container: Container) -> Dict:
    """Fetch detailed container info via docker inspect."""
    cmd = ["docker", "inspect", container.id]
    exit_code, stdout, stderr = run_command(cmd)

    if exit_code != 0:
        return {}

    try:
        info_list = json.loads(stdout)
        return info_list[0] if info_list else {}
    except json.JSONDecodeError:
        return {}


def format_output(container: Container, command: str, exit_code: int, stdout: str, stderr: str):
    """Format execution output for display."""
    print(f"✓ Executed in container: {container.name} ({container.id[:12]})\n")
    print(f"Command: {command}")
    print(f"Exit Code: {exit_code}\n")

    if stdout:
        print("Output:")
        print(stdout)

    if stderr:
        print("\nStderr:")
        print(stderr)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Execute commands in running product-cf-hcp containers"
    )
    parser.add_argument(
        "command",
        nargs="?",
        help="Command to execute (omit for interactive shell)"
    )
    parser.add_argument(
        "--container",
        help="Container ID or name to use"
    )
    parser.add_argument(
        "--filter",
        default="product-cf-hcp",
        help="Container name filter (default: product-cf-hcp)"
    )
    parser.add_argument(
        "--user",
        help="Run as specific user"
    )
    parser.add_argument(
        "--workdir",
        help="Working directory inside container"
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List available containers and exit"
    )

    args = parser.parse_args()

    # Find containers
    containers = find_containers(args.filter)

    if not containers:
        print(f"Error: No containers matching '{args.filter}' are currently running.", file=sys.stderr)
        print("\nSuggestions:", file=sys.stderr)
        print("  - Check all containers: docker ps -a", file=sys.stderr)
        print("  - Start a container: docker start <container-name>", file=sys.stderr)
        return 1

    # List mode
    if args.list:
        print(f"Found {len(containers)} container(s):\n")
        for c in containers:
            print(f"  {c.id[:12]}\t{c.name}\t{c.status}")
        return 0

    # Select container
    container = select_container(containers, args.container)

    if not container:
        if args.container:
            print(f"Error: Container '{args.container}' not found.", file=sys.stderr)
        else:
            print("Error: Multiple containers found. Specify one with --container:", file=sys.stderr)

        print("\nAvailable containers:", file=sys.stderr)
        for c in containers:
            print(f"  {c.id[:12]}\t{c.name}\t{c.status}", file=sys.stderr)
        return 1

    # Determine command
    command = args.command or "/bin/bash"
    interactive = args.command is None

    # Execute
    exit_code, stdout, stderr = exec_in_container(
        container,
        command,
        interactive=interactive,
        user=args.user,
        workdir=args.workdir
    )

    # Format output
    if not interactive:
        format_output(container, command, exit_code, stdout, stderr)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())

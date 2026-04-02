---
name: run-in-container
description: Execute commands in running product-cf-hcp containers
allowed-tools:
  - Bash(docker ps*)
  - Bash(docker exec*)
  - Bash(docker inspect*)
---

# Run in Container

This skill finds running product-cf-hcp containers and executes commands inside them. It automatically detects the appropriate container and runs the specified command.

## Prerequisites

- **Docker**: Docker daemon must be running
- **Running Container**: At least one product-cf-hcp container must be running
- **Permissions**: User must have docker exec permissions

## Usage

When invoked with a command argument:
1. Searches for running containers with "product-cf-hcp" in the name
2. Lists available containers if multiple are found
3. Executes the specified command in the container
4. Returns the command output

**Examples**:
```bash
# Run a shell command
/run-in-container "ls -la /app"

# Check running processes
/run-in-container "ps aux"

# View logs
/run-in-container "tail -f /var/log/app.log"

# Start an interactive shell (when no command specified)
/run-in-container
```

## How it Works

### Step 1: Find Running Containers
- Search for containers: `docker ps --filter "name=product-cf-hcp" --format "{{.ID}}\t{{.Names}}\t{{.Status}}"`
- If no containers found, error with instructions to start one
- If multiple containers found, list them and ask user to specify which one

### Step 2: Select Container
**Single Container**:
- Automatically select the only running container

**Multiple Containers**:
- Display list with container IDs, names, and status
- Ask user to specify container by name or ID
- Store selection for subsequent commands in the session

### Step 3: Execute Command
**With Command Argument**:
- Run: `docker exec <container-id> <command>`
- Return stdout and stderr

**Without Command (Interactive)**:
- Run: `docker exec -it <container-id> /bin/bash`
- If bash not available, try: `/bin/sh`
- Start interactive shell session

### Step 4: Handle Output
- Display command output directly
- If command fails, show exit code and error message
- Suggest common fixes for permission or path issues

## Command Options

### Non-Interactive Commands
Execute and return immediately:
```bash
docker exec <container-id> <command>
```

### Interactive Commands
For commands requiring TTY:
```bash
docker exec -it <container-id> <command>
```

### Running as Different User
```bash
docker exec -u <user> <container-id> <command>
```

### Setting Working Directory
```bash
docker exec -w <workdir> <container-id> <command>
```

## Error Handling

**No Containers Running**:
- Error: "No product-cf-hcp containers are currently running."
- Suggest: `docker ps -a` to see all containers
- Suggest: `docker start <container-name>` to start a stopped container

**Container Not Found**:
- Error: "Container '<name>' not found."
- List available containers

**Command Not Found in Container**:
- Error: "Command '<cmd>' not found in container."
- Suggest: Check if command is installed
- Suggest: Use full path (e.g., `/usr/bin/ls` instead of `ls`)

**Permission Denied**:
- Error: "Permission denied executing '<cmd>'."
- Suggest: Run with different user using `-u` flag
- Suggest: Check file permissions in container

**Docker Daemon Not Running**:
- Error: "Cannot connect to Docker daemon."
- Suggest: Start Docker Desktop or docker service

## Container Information

The skill can also provide container details:
- Container ID and name
- Image name and tag
- Status and uptime
- Exposed ports
- Mounted volumes
- Environment variables (filtered for secrets)

**Get Container Info**:
```bash
docker inspect <container-id> --format '{{json .}}'
```

## Output Format

**Successful Execution**:
```
✓ Executed in container: product-cf-hcp-api (abc123)

Command: ls -la /app
Exit Code: 0

Output:
drwxr-xr-x 5 root root 4096 Mar 16 10:30 .
drwxr-xr-x 1 root root 4096 Mar 16 10:29 ..
-rw-r--r-- 1 root root 1234 Mar 16 10:30 config.yaml
drwxr-xr-x 3 root root 4096 Mar 16 10:30 src
```

**Failed Execution**:
```
✗ Command failed in container: product-cf-hcp-api (abc123)

Command: invalid-command
Exit Code: 127

Error:
/bin/sh: invalid-command: not found

Suggestion: Check if the command exists in the container
```

## Tips

- Use `docker ps` to see all running containers first
- Container names may include suffixes (e.g., `product-cf-hcp-api-1`)
- Commands run as the default container user (usually root)
- Use full paths for binaries if PATH is not set
- Quote commands with spaces or special characters

## Advanced Usage

**Run multiple commands**:
```bash
/run-in-container "cd /app && ls -la && cat config.yaml"
```

**Capture output to file**:
```bash
/run-in-container "cat /var/log/app.log > /tmp/log.txt"
```

**Check environment variables**:
```bash
/run-in-container "env | grep -i app"
```

**Test network connectivity**:
```bash
/run-in-container "curl -v http://localhost:8080/health"
```

## Limitations

- Cannot run GUI applications
- Interactive commands (requiring user input) may not work as expected
- Commands are executed in container's default shell context
- Container must be in "running" state (not paused or stopped)
- Large outputs may be truncated

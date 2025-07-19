# WSL2 Claude Code Cluster

Complete multi-agent Claude Code environment for Windows + WSL2.

## Features

- ✅ **One-command installation**: Single script sets up everything
- ✅ **3 specialized agents**: Frontend, Backend, Infrastructure
- ✅ **Central router**: Intelligent task distribution
- ✅ **Windows integration**: PowerShell commands and Terminal profiles
- ✅ **Auto-start**: Systemd services (optional)
- ✅ **Hook system**: Event-driven automation

## Quick Start

### Prerequisites

- Windows 10/11 with WSL2 enabled
- Ubuntu 24.04 in WSL2
- Internet connection

### Installation

1. **In WSL2 Ubuntu:**

```bash
# Download and run installer
curl -sSL https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/wsl2/install-claude-cluster.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster/wsl2
./install-claude-cluster.sh
```

2. **Start the cluster:**

```bash
claude-cluster start
```

3. **Check status:**

```bash
claude-cluster status
```

## Usage

### Command Line

```bash
# Start all agents
claude-cluster start

# Stop all agents  
claude-cluster stop

# Restart specific agent
claude-cluster restart cc01

# View logs
claude-cluster logs         # All logs
claude-cluster logs cc02    # Specific agent

# Submit task
claude-cluster task /path/to/task.json
```

### Windows PowerShell

```powershell
# Import module
Import-Module \\wsl$\Ubuntu\home\claude-cluster\scripts\windows\ClaudeCluster.psm1

# Use commands
Start-ClaudeCluster
Get-ClaudeClusterStatus
Send-ClaudeTask -Description "Create a login page" -TaskType "frontend"
Watch-ClaudeLogs -Agent cc01
```

### Web API

```bash
# Submit task via API
curl -X POST http://localhost:8888/task \
  -H "Content-Type: application/json" \
  -d '{
    "type": "frontend_development",
    "description": "Create React component",
    "priority": "high"
  }'

# Check all agents status
curl http://localhost:8888/agents/status

# Broadcast message
curl -X POST http://localhost:8888/broadcast \
  -H "Content-Type: application/json" \
  -d '{"message": "System update in 5 minutes"}'
```

## Architecture

```
Windows Host
└── WSL2 Ubuntu
    ├── Central Router (port 8888)
    │   ├── /webhook      - Main webhook endpoint
    │   ├── /task         - Task submission
    │   ├── /agents/status - Agent monitoring
    │   └── /broadcast    - Multi-agent messaging
    │
    ├── Agent CC01 (port 8881) - Frontend specialist
    │   ├── React/TypeScript development
    │   ├── UI/UX implementation
    │   └── Component testing
    │
    ├── Agent CC02 (port 8882) - Backend specialist
    │   ├── API development
    │   ├── Database design
    │   └── Business logic
    │
    └── Agent CC03 (port 8883) - Infrastructure specialist
        ├── CI/CD pipelines
        ├── Docker/Kubernetes
        └── Cloud deployment
```

## Directory Structure

```
/home/claude-cluster/
├── agents/
│   ├── cc01/          # Frontend agent
│   ├── cc02/          # Backend agent
│   └── cc03/          # Infrastructure agent
├── shared/
│   ├── tasks/         # Task queue
│   ├── logs/          # Centralized logs
│   └── artifacts/     # Shared outputs
├── scripts/
│   ├── management/    # Cluster management
│   ├── hooks/         # Event handlers
│   └── windows/       # Windows integration
└── config/            # Configuration files
```

## Configuration

Each agent has its own configuration in:
```
/home/claude-cluster/agents/{agent}/.claude/config/hooks.conf
```

Modify to customize:
- Webhook ports
- Log levels
- Specializations
- Resource limits

## Troubleshooting

### Agents not starting
```bash
# Check tmux sessions
tmux ls

# Check webhook servers
ps aux | grep webhook

# View detailed logs
tail -f /home/claude-cluster/shared/logs/*.log
```

### Port conflicts
```bash
# Check port usage
netstat -tlnp | grep 888

# Modify ports in configs
vim /home/claude-cluster/agents/cc01/.claude/config/hooks.conf
```

### Windows Terminal profiles
Add profiles from:
```
\\wsl$\Ubuntu\home\claude-cluster\scripts\windows\terminal-profiles.json
```

## Advanced Usage

### Custom hooks
Add event handlers in:
```
/home/claude-cluster/agents/{agent}/.claude/hooks/
```

### Task routing rules
Modify router logic in:
```
/home/claude-cluster/scripts/management/central-router.py
```

### Resource limits
Set CPU/memory limits:
```bash
# In systemd service files
CPUQuota=200%
MemoryLimit=4G
```

## Updates

```bash
# Update cluster software
claude-cluster update

# Manual update
cd /tmp
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
# Follow migration guide
```

## Support

- Issues: https://github.com/ootakazuhiko/claude-code-cluster/issues
- Documentation: https://github.com/ootakazuhiko/claude-code-cluster/wiki
# Claude Code Cluster Hook System

## Overview

This hook system provides event-driven automation for Claude Code agents, replacing the inefficient polling-based approach with reactive webhooks and local hooks.

## Features

- **GitHub Webhook Integration**: Instant notification of new issues/PRs
- **Inter-Agent Communication**: Direct messaging between agents
- **Resource Management**: Automatic CPU/memory optimization
- **Task Prioritization**: Dynamic priority-based task switching
- **Progress Monitoring**: Real-time status updates and intervention

## Installation

```bash
# Clone the repository
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster

# Run the installer
./hooks/install-hooks.sh

# Activate hooks
source ~/.claude/hooks/activate.sh
```

## Hook Types

### 1. `on-task-received`
Triggered when a new task is assigned via webhook.

**Payload example:**
```json
{
  "type": "task",
  "source": "github",
  "data": {
    "issue_number": 123,
    "priority": "high",
    "labels": ["bug", "cc01-task"]
  }
}
```

### 2. `on-progress-update`
Periodic progress monitoring and resource management.

**Payload example:**
```json
{
  "type": "status",
  "source": "monitor",
  "data": {
    "cpu_usage": 75.5,
    "memory_usage": 45.2,
    "duration_hours": 12.5,
    "task_id": "issue-123"
  }
}
```

### 3. `on-agent-message`
Inter-agent communication for collaboration.

**Payload example:**
```json
{
  "type": "agent_message",
  "source": "CC02",
  "data": {
    "from": "CC02",
    "to": "CC01",
    "type": "help_request",
    "context": {
      "pr_number": 222,
      "issue": "type_annotations"
    }
  }
}
```

### 4. `on-error`
Error handling and recovery automation.

### 5. `on-task-complete`
Task completion notifications and cleanup.

### 6. `on-github-event`
GitHub-specific events (issues, PRs, comments).

### 7. `on-resource-limit`
Resource threshold alerts and throttling.

### 8. `on-collaboration-request`
Multi-agent collaboration coordination.

## Configuration

Edit `~/.claude/config/hooks.conf`:

```bash
HOOKS_ENABLED=true
WEBHOOK_PORT=8888
WEBHOOK_HOST=127.0.0.1
AGENT_NAME=CC01
LOG_LEVEL=INFO
```

## Webhook Server

The webhook server listens for incoming HTTP webhooks and triggers appropriate hooks.

### Start the server:
```bash
python3 ~/.claude/hooks/webhook-server.py
```

### Or as a systemd service:
```bash
sudo systemctl start claude-webhook
```

### Endpoints:
- `POST /webhook` - Main webhook endpoint
- `GET /health` - Health check

## GitHub Integration

Add webhook to your repository:
1. Go to Settings → Webhooks
2. Add webhook URL: `http://your-agent-host:8888/webhook`
3. Select events: Issues, Pull requests, Issue comments
4. Set content type: `application/json`

## Custom Hook Implementation

To add custom logic to a hook, create an `.impl` file:

```bash
# ~/.claude/hooks/on-task-received.impl
#!/bin/bash

TASK_FILE="$1"
# Your custom logic here
```

## Testing

Test a hook manually:
```bash
# Create test payload
cat > /tmp/test-task.json << EOF
{
  "type": "task",
  "source": "test",
  "data": {
    "priority": "high",
    "message": "Test task"
  }
}
EOF

# Trigger hook
~/.claude/hooks/on-task-received.sh /tmp/test-task.json
```

## Monitoring

View hook logs:
```bash
tail -f ~/.claude/logs/*.log
```

Check webhook server logs:
```bash
tail -f ~/.claude/logs/webhook-server.log
```

## Troubleshooting

### Webhook server not starting
- Check if port 8888 is available
- Verify Python dependencies: `pip install fastapi uvicorn`

### Hooks not triggering
- Check hook permissions: `chmod +x ~/.claude/hooks/*.sh`
- Verify webhook payload format
- Check logs for errors

### Agent not responding
- Ensure `AGENT_NAME` is set correctly
- Verify Claude process is running
- Check inter-agent network connectivity

## Security

- Webhook server binds to localhost only by default
- Use reverse proxy with HTTPS for external access
- Implement webhook signature verification for GitHub
- Sanitize all input data in hooks

## Next Steps

1. Deploy hooks to all agents (CC01, CC02, CC03)
2. Update GitHub workflows to send webhooks
3. Implement agent-specific customizations
4. Monitor and optimize based on usage patterns
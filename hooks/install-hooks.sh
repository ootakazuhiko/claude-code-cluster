#!/bin/bash
# Claude Code Cluster Hook System Installer

set -euo pipefail

# Configuration
HOOKS_DIR="${HOME}/.claude/hooks"
CONFIG_DIR="${HOME}/.claude/config"
CLAUDE_CLUSTER_REPO="https://github.com/ootakazuhiko/claude-code-cluster.git"

echo "=== Claude Code Cluster Hook System Installer ==="
echo ""

# Create directories
echo "Creating hook directories..."
mkdir -p "${HOOKS_DIR}"
mkdir -p "${CONFIG_DIR}"

# Function to create hook script
create_hook() {
    local hook_name=$1
    local hook_file="${HOOKS_DIR}/${hook_name}.sh"
    
    echo "Creating ${hook_name} hook..."
    
    cat > "${hook_file}" << 'EOF'
#!/bin/bash
# Auto-generated hook script
set -euo pipefail

HOOK_NAME="$(basename "$0" .sh)"
LOG_FILE="${HOME}/.claude/logs/${HOOK_NAME}.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Log hook execution
echo "[$(date)] Hook ${HOOK_NAME} triggered with args: $*" >> "$LOG_FILE"

# Source hook implementation if exists
IMPL_FILE="${HOME}/.claude/hooks/${HOOK_NAME}.impl"
if [ -f "$IMPL_FILE" ]; then
    source "$IMPL_FILE" "$@"
fi
EOF
    
    chmod +x "${hook_file}"
}

# Create base hooks
HOOKS=(
    "on-task-received"
    "on-progress-update"
    "on-error"
    "on-task-complete"
    "on-agent-message"
    "on-github-event"
    "on-resource-limit"
    "on-collaboration-request"
)

for hook in "${HOOKS[@]}"; do
    create_hook "$hook"
done

# Create webhook server script
echo "Creating webhook server..."
cat > "${HOOKS_DIR}/webhook-server.py" << 'EOF'
#!/usr/bin/env python3
"""
Claude Code Cluster Webhook Server
Receives webhooks and triggers appropriate hooks
"""

import os
import json
import subprocess
import logging
from pathlib import Path
from datetime import datetime
from typing import Dict, Any

from fastapi import FastAPI, Request, HTTPException
from pydantic import BaseModel

# Configuration
HOOKS_DIR = Path.home() / ".claude" / "hooks"
TEMP_DIR = Path("/tmp/claude-webhooks")
TEMP_DIR.mkdir(exist_ok=True)

# Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(Path.home() / ".claude" / "logs" / "webhook-server.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = FastAPI()

class WebhookPayload(BaseModel):
    type: str
    source: str
    data: Dict[str, Any]

def trigger_hook(hook_name: str, data_file: Path) -> bool:
    """Trigger a hook script with data file as argument"""
    hook_script = HOOKS_DIR / f"{hook_name}.sh"
    
    if not hook_script.exists():
        logger.warning(f"Hook script not found: {hook_script}")
        return False
    
    try:
        result = subprocess.run(
            [str(hook_script), str(data_file)],
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout
        )
        
        if result.returncode == 0:
            logger.info(f"Hook {hook_name} executed successfully")
            return True
        else:
            logger.error(f"Hook {hook_name} failed: {result.stderr}")
            return False
            
    except subprocess.TimeoutExpired:
        logger.error(f"Hook {hook_name} timed out")
        return False
    except Exception as e:
        logger.error(f"Error executing hook {hook_name}: {e}")
        return False

@app.post("/webhook")
async def handle_webhook(payload: WebhookPayload):
    """Handle incoming webhooks"""
    logger.info(f"Received webhook: type={payload.type}, source={payload.source}")
    
    # Save payload to temp file
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    data_file = TEMP_DIR / f"{payload.type}_{timestamp}.json"
    
    with open(data_file, "w") as f:
        json.dump(payload.dict(), f, indent=2)
    
    # Map webhook types to hooks
    hook_mapping = {
        "github_issue": "on-github-event",
        "github_pr": "on-github-event",
        "task": "on-task-received",
        "agent_message": "on-agent-message",
        "collaboration": "on-collaboration-request",
        "status": "on-progress-update"
    }
    
    hook_name = hook_mapping.get(payload.type, f"on-{payload.type}")
    
    # Trigger appropriate hook
    success = trigger_hook(hook_name, data_file)
    
    # Clean up old temp files (older than 1 hour)
    for old_file in TEMP_DIR.glob("*.json"):
        if (datetime.now() - datetime.fromtimestamp(old_file.stat().st_mtime)).seconds > 3600:
            old_file.unlink()
    
    if success:
        return {"status": "success", "hook": hook_name}
    else:
        raise HTTPException(status_code=500, detail=f"Hook execution failed: {hook_name}")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "hooks_dir": str(HOOKS_DIR)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8888)
EOF

chmod +x "${HOOKS_DIR}/webhook-server.py"

# Create systemd service for webhook server
echo "Creating systemd service..."
cat > "${CONFIG_DIR}/claude-webhook.service" << EOF
[Unit]
Description=Claude Code Cluster Webhook Server
After=network.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${HOOKS_DIR}
ExecStart=/usr/bin/python3 ${HOOKS_DIR}/webhook-server.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create example hook implementations
echo "Creating example hook implementations..."

# Task received hook
cat > "${HOOKS_DIR}/on-task-received.impl" << 'EOF'
#!/bin/bash
# Implementation for task received hook

TASK_FILE="$1"
TASK_TYPE=$(jq -r .data.type "$TASK_FILE" 2>/dev/null || echo "unknown")
PRIORITY=$(jq -r .data.priority "$TASK_FILE" 2>/dev/null || echo "normal")

echo "[$(date)] Received task: type=$TASK_TYPE, priority=$PRIORITY"

# High priority task handling
if [[ "$PRIORITY" == "critical" || "$PRIORITY" == "high" ]]; then
    echo "[$(date)] High priority task detected, considering interruption..."
    
    # Check if Claude is running
    if pgrep -f "claude" > /dev/null; then
        # Send notification to Claude (implementation depends on Claude CLI)
        echo "New high priority task received" | wall 2>/dev/null || true
    fi
fi

# Log task to queue
QUEUE_FILE="${HOME}/.claude/task_queue.json"
if [ -f "$QUEUE_FILE" ]; then
    # Append to existing queue
    jq '. + [input]' "$QUEUE_FILE" "$TASK_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"
else
    # Create new queue
    jq '[.]' "$TASK_FILE" > "$QUEUE_FILE"
fi
EOF

# Agent message hook
cat > "${HOOKS_DIR}/on-agent-message.impl" << 'EOF'
#!/bin/bash
# Implementation for agent message hook

MESSAGE_FILE="$1"
FROM_AGENT=$(jq -r .data.from "$MESSAGE_FILE" 2>/dev/null || echo "unknown")
MESSAGE_TYPE=$(jq -r .data.type "$MESSAGE_FILE" 2>/dev/null || echo "unknown")

echo "[$(date)] Message from $FROM_AGENT: type=$MESSAGE_TYPE"

case "$MESSAGE_TYPE" in
    "help_request")
        echo "[$(date)] Help requested by $FROM_AGENT"
        # Create response file
        RESPONSE_FILE="/tmp/response_to_${FROM_AGENT}_$(date +%s).json"
        cat > "$RESPONSE_FILE" << JSON
{
    "from": "${AGENT_NAME:-unknown}",
    "to": "$FROM_AGENT",
    "type": "help_response",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "data": {
        "status": "acknowledged",
        "message": "Help request received, analyzing..."
    }
}
JSON
        # Send response (implementation depends on agent communication setup)
        ;;
        
    "status_query")
        echo "[$(date)] Status query from $FROM_AGENT"
        # Respond with current status
        ;;
        
    *)
        echo "[$(date)] Unknown message type: $MESSAGE_TYPE"
        ;;
esac
EOF

# Progress update hook
cat > "${HOOKS_DIR}/on-progress-update.impl" << 'EOF'
#!/bin/bash
# Implementation for progress update hook

METRICS_FILE="$1"
CPU_USAGE=$(jq -r .data.cpu_usage "$METRICS_FILE" 2>/dev/null || echo "0")
MEMORY_USAGE=$(jq -r .data.memory_usage "$METRICS_FILE" 2>/dev/null || echo "0")
TASK_DURATION=$(jq -r .data.duration_hours "$METRICS_FILE" 2>/dev/null || echo "0")

echo "[$(date)] Progress update: CPU=$CPU_USAGE%, Memory=$MEMORY_USAGE%, Duration=${TASK_DURATION}h"

# Resource management
if (( $(echo "$CPU_USAGE > 70" | bc -l 2>/dev/null || echo 0) )); then
    echo "[$(date)] High CPU usage detected, considering throttling..."
fi

# Long-running task warning
if (( $(echo "$TASK_DURATION > 24" | bc -l 2>/dev/null || echo 0) )); then
    echo "[$(date)] Task running for over 24 hours, consider breaking down"
fi
EOF

# Make implementations executable
chmod +x "${HOOKS_DIR}"/*.impl

# Create configuration file
echo "Creating configuration..."
cat > "${CONFIG_DIR}/hooks.conf" << EOF
# Claude Code Cluster Hooks Configuration
HOOKS_ENABLED=true
WEBHOOK_PORT=8888
WEBHOOK_HOST=127.0.0.1
AGENT_NAME=${AGENT_NAME:-unknown}
LOG_LEVEL=INFO
EOF

# Create activation script
cat > "${HOOKS_DIR}/activate.sh" << 'EOF'
#!/bin/bash
# Activate Claude Code Cluster hooks

export CLAUDE_HOOKS_DIR="${HOME}/.claude/hooks"
export PATH="${CLAUDE_HOOKS_DIR}:${PATH}"

# Start webhook server if not running
if ! pgrep -f "webhook-server.py" > /dev/null; then
    echo "Starting webhook server..."
    nohup python3 "${CLAUDE_HOOKS_DIR}/webhook-server.py" > /dev/null 2>&1 &
    echo "Webhook server started on http://127.0.0.1:8888"
fi

echo "Claude Code Cluster hooks activated"
EOF

chmod +x "${HOOKS_DIR}/activate.sh"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Hook system installed in: ${HOOKS_DIR}"
echo ""
echo "To activate hooks:"
echo "  source ${HOOKS_DIR}/activate.sh"
echo ""
echo "To start webhook server:"
echo "  python3 ${HOOKS_DIR}/webhook-server.py"
echo ""
echo "To install as systemd service:"
echo "  sudo cp ${CONFIG_DIR}/claude-webhook.service /etc/systemd/system/"
echo "  sudo systemctl enable claude-webhook"
echo "  sudo systemctl start claude-webhook"
echo ""
echo "Configuration file: ${CONFIG_DIR}/hooks.conf"
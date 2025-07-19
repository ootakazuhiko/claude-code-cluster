#!/bin/bash
# Stop Claude Code Agent
# Usage: ./stop-agent.sh [AGENT_NAME]

set -e

# Default values
AGENT_NAME="${1:-CC01}"
WORKSPACE="${WORKSPACE:-$(pwd)}"

echo "Stopping Claude Code Agent $AGENT_NAME..."

# Find Claude Code process
CLAUDE_PID=$(pgrep -f "claude-code.*$AGENT_NAME" 2>/dev/null || echo "")

if [ -z "$CLAUDE_PID" ]; then
    # Try alternative search
    CLAUDE_PID=$(pgrep -f "claude-code.*config.*claude-code-config.yaml" 2>/dev/null || echo "")
fi

if [ -z "$CLAUDE_PID" ]; then
    echo "No running Claude Code agent found for $AGENT_NAME"
else
    echo "Found Claude Code process: PID $CLAUDE_PID"
    
    # Send SIGTERM for graceful shutdown
    kill -TERM "$CLAUDE_PID" 2>/dev/null || true
    
    # Wait for process to terminate
    echo "Waiting for graceful shutdown..."
    for i in {1..10}; do
        if ! kill -0 "$CLAUDE_PID" 2>/dev/null; then
            echo "Claude Code agent stopped successfully"
            break
        fi
        sleep 1
    done
    
    # Force kill if still running
    if kill -0 "$CLAUDE_PID" 2>/dev/null; then
        echo "Force stopping Claude Code agent..."
        kill -9 "$CLAUDE_PID" 2>/dev/null || true
    fi
fi

# Clean up state files
if [ -f "$WORKSPACE/.agent/state/agent_started" ]; then
    rm -f "$WORKSPACE/.agent/state/agent_started"
fi

if [ -f "$WORKSPACE/.agent/state/current_task.json" ]; then
    echo "Warning: Agent was processing a task when stopped"
    echo "Task info saved in: $WORKSPACE/.agent/state/current_task.json"
fi

# Log shutdown
LOG_FILE="$WORKSPACE/.agent/logs/agent-startup.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Claude Code Agent $AGENT_NAME stopped" | tee -a "$LOG_FILE"

# Post shutdown message to GitHub (if there are open issues)
if command -v gh &> /dev/null; then
    ACTIVE_ISSUE=$(gh issue list --label "${2:-cc01}" --state open --limit 1 --json number -q '.[0].number' 2>/dev/null || echo "")
    if [ -n "$ACTIVE_ISSUE" ]; then
        gh issue comment "$ACTIVE_ISSUE" --body "## 🛑 $AGENT_NAME Agent Stopped

- **Time**: $(date '+%Y-%m-%d %H:%M:%S')
- **Status**: Agent has been shut down

To restart the agent, run: \`./start-agent.sh $AGENT_NAME ${2:-cc01}\`" 2>/dev/null || true
    fi
fi

echo ""
echo "Agent $AGENT_NAME has been stopped"
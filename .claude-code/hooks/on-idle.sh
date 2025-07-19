#!/bin/bash
# Claude Code On-Idle Hook
# Purpose: Check for new tasks when Claude Code is idle

set -e

# Configuration from Claude Code environment
WORKSPACE="${CLAUDE_CODE_WORKSPACE:-/home/work/project}"
AGENT_NAME="${CLAUDE_CODE_AGENT_NAME:-CC01}"
ISSUE_LABEL="${CLAUDE_CODE_ISSUE_LABEL:-cc01}"
LOG_FILE="${CLAUDE_CODE_LOG_FILE:-$WORKSPACE/.agent/logs/claude-code-hook.log}"

# Path to agent scripts
AGENT_SCRIPTS_DIR="${WORKSPACE}/scripts/agent"
INSTRUCTION_HANDLER="${AGENT_SCRIPTS_DIR}/instruction-handler.sh"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [on-idle] $@" >> "$LOG_FILE"
}

# Check if instruction handler exists
if [ ! -x "$INSTRUCTION_HANDLER" ]; then
    log "ERROR: instruction-handler.sh not found or not executable at $INSTRUCTION_HANDLER"
    exit 0  # Exit silently to not interrupt Claude Code
fi

# Export environment for instruction handler
export AGENT_NAME
export ISSUE_LABEL
export WORKSPACE

# Fetch new instructions
log "Checking for new tasks (agent: $AGENT_NAME, label: $ISSUE_LABEL)"
TASK_INFO=$("$INSTRUCTION_HANDLER" 2>&1 || echo "{}")

# Check if we got a valid task
if [ -z "$TASK_INFO" ] || [ "$TASK_INFO" = "{}" ]; then
    log "No new tasks available"
    exit 0
fi

# Extract issue number from task info
ISSUE_NUMBER=$(echo "$TASK_INFO" | jq -r '.issue' 2>/dev/null || echo "")
if [ -z "$ISSUE_NUMBER" ] || [ "$ISSUE_NUMBER" = "null" ]; then
    log "Invalid task info received: $TASK_INFO"
    exit 0
fi

log "Found new task: Issue #$ISSUE_NUMBER"

# Signal Claude Code about the new task
# Claude Code will read this from stdout
cat <<EOF
{
  "action": "new_task",
  "task_info": $TASK_INFO,
  "instruction_file": "$WORKSPACE/.agent/instructions/instruction_${ISSUE_NUMBER}.md"
}
EOF

# Also save the task info for post-command hook
echo "$TASK_INFO" > "$WORKSPACE/.agent/state/current_task.json"

log "Task #$ISSUE_NUMBER ready for processing"
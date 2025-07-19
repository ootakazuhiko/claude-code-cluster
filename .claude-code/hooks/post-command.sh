#!/bin/bash
# Claude Code Post-Command Hook
# Purpose: Generate and submit report after command execution

set -e

# Configuration from Claude Code environment
WORKSPACE="${CLAUDE_CODE_WORKSPACE:-/home/work/project}"
AGENT_NAME="${CLAUDE_CODE_AGENT_NAME:-CC01}"
LOG_FILE="${CLAUDE_CODE_LOG_FILE:-$WORKSPACE/.agent/logs/claude-code-hook.log}"

# Path to agent scripts
AGENT_SCRIPTS_DIR="${WORKSPACE}/scripts/agent"
REPORT_GENERATOR="${AGENT_SCRIPTS_DIR}/report-generator.sh"
TASK_EXECUTOR="${AGENT_SCRIPTS_DIR}/task-executor.sh"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [post-command] $@" >> "$LOG_FILE"
}

# Check if report generator exists
if [ ! -x "$REPORT_GENERATOR" ]; then
    log "ERROR: report-generator.sh not found or not executable at $REPORT_GENERATOR"
    exit 0  # Exit silently
fi

# Check if we have a current task
CURRENT_TASK_FILE="$WORKSPACE/.agent/state/current_task.json"
if [ ! -f "$CURRENT_TASK_FILE" ]; then
    log "No current task found, skipping report"
    exit 0
fi

# Read current task info
TASK_INFO=$(cat "$CURRENT_TASK_FILE")
ISSUE_NUMBER=$(echo "$TASK_INFO" | jq -r '.issue' 2>/dev/null || echo "")

if [ -z "$ISSUE_NUMBER" ] || [ "$ISSUE_NUMBER" = "null" ]; then
    log "Invalid task info in current_task.json"
    exit 0
fi

log "Processing results for task #$ISSUE_NUMBER"

# Get command execution result from Claude Code
# This is passed via environment variables by Claude Code
COMMAND_EXIT_CODE="${CLAUDE_CODE_COMMAND_EXIT_CODE:-0}"
COMMAND_OUTPUT="${CLAUDE_CODE_COMMAND_OUTPUT:-}"
COMMAND_EXECUTED="${CLAUDE_CODE_COMMAND_EXECUTED:-}"

# Determine success based on exit code
if [ "$COMMAND_EXIT_CODE" = "0" ]; then
    SUCCESS="true"
    log "Command completed successfully"
else
    SUCCESS="false"
    log "Command failed with exit code: $COMMAND_EXIT_CODE"
fi

# Create task result for report generator
TASK_RESULT=$(cat <<EOF
{
  "issue": $ISSUE_NUMBER,
  "success": $SUCCESS,
  "exit_code": $COMMAND_EXIT_CODE,
  "command": "$COMMAND_EXECUTED"
}
EOF
)

# Export environment for report generator
export AGENT_NAME
export WORKSPACE

# Save execution details for report
if [ -n "$COMMAND_OUTPUT" ]; then
    echo "$COMMAND_OUTPUT" > "$WORKSPACE/.agent/logs/command_output_${ISSUE_NUMBER}.log"
fi

# Generate and submit report
log "Generating report for task #$ISSUE_NUMBER"
echo "$TASK_RESULT" | "$REPORT_GENERATOR" 2>&1 | tee -a "$LOG_FILE"

# Check if this was a task completion
if [ "$SUCCESS" = "true" ]; then
    # Task completed, clean up current task
    rm -f "$CURRENT_TASK_FILE"
    log "Task #$ISSUE_NUMBER completed and cleared"
    
    # Signal Claude Code that task is complete
    cat <<EOF
{
  "action": "task_complete",
  "issue": $ISSUE_NUMBER,
  "success": true
}
EOF
else
    # Task failed, keep it for retry or manual intervention
    log "Task #$ISSUE_NUMBER failed, keeping for retry"
    
    # Signal Claude Code about failure
    cat <<EOF
{
  "action": "task_failed",
  "issue": $ISSUE_NUMBER,
  "exit_code": $COMMAND_EXIT_CODE,
  "retry_available": true
}
EOF
fi
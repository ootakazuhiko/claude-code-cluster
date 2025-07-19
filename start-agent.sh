#!/bin/bash
# Start Claude Code Agent
# Usage: ./start-agent.sh [AGENT_NAME] [ISSUE_LABEL]

set -e

# Default values
AGENT_NAME="${1:-CC01}"
ISSUE_LABEL="${2:-cc01}"
WORKSPACE="${WORKSPACE:-$(pwd)}"

# Determine agent type from name
case "$AGENT_NAME" in
    CC01|cc01)
        AGENT_TYPE="frontend"
        ;;
    CC02|cc02)
        AGENT_TYPE="backend"
        ;;
    CC03|cc03)
        AGENT_TYPE="infrastructure"
        ;;
    *)
        AGENT_TYPE="general"
        ;;
esac

# Check required environment variables
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "ERROR: ANTHROPIC_API_KEY environment variable is required"
    echo "Please set: export ANTHROPIC_API_KEY='sk-ant-...'"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "ERROR: GITHUB_TOKEN environment variable is required"
    echo "Please set: export GITHUB_TOKEN='ghp_...'"
    exit 1
fi

# Check if Claude Code is installed
if ! command -v claude-code &> /dev/null; then
    echo "ERROR: claude-code command not found"
    echo "Please install Claude Code first"
    exit 1
fi

# Check if agent scripts exist
if [ ! -d "./scripts/agent" ]; then
    echo "ERROR: Agent scripts not found in ./scripts/agent"
    echo "Please ensure you're in the correct directory"
    exit 1
fi

# Create necessary directories
echo "Setting up workspace directories..."
mkdir -p "$WORKSPACE/.agent/logs"
mkdir -p "$WORKSPACE/.agent/state"
mkdir -p "$WORKSPACE/.agent/instructions"

# Export environment variables for Claude Code
export AGENT_NAME
export AGENT_TYPE
export ISSUE_LABEL
export WORKSPACE
export CLAUDE_CODE_WORKSPACE="$WORKSPACE"
export CLAUDE_CODE_AGENT_NAME="$AGENT_NAME"
export CLAUDE_CODE_ISSUE_LABEL="$ISSUE_LABEL"

# Log startup
LOG_FILE="$WORKSPACE/.agent/logs/agent-startup.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Claude Code Agent" | tee -a "$LOG_FILE"
echo "Agent Name: $AGENT_NAME" | tee -a "$LOG_FILE"
echo "Agent Type: $AGENT_TYPE" | tee -a "$LOG_FILE"
echo "Issue Label: $ISSUE_LABEL" | tee -a "$LOG_FILE"
echo "Workspace: $WORKSPACE" | tee -a "$LOG_FILE"

# Create startup marker
echo "$(date +%s)" > "$WORKSPACE/.agent/state/agent_started"

# Post startup message to GitHub (if there are open issues)
if command -v gh &> /dev/null; then
    STARTUP_ISSUE=$(gh issue list --label "$ISSUE_LABEL" --state open --limit 1 --json number -q '.[0].number' 2>/dev/null || echo "")
    if [ -n "$STARTUP_ISSUE" ]; then
        gh issue comment "$STARTUP_ISSUE" --body "## 🤖 $AGENT_NAME Agent Started

- **Time**: $(date '+%Y-%m-%d %H:%M:%S')
- **Type**: $AGENT_TYPE
- **Label**: $ISSUE_LABEL
- **Mode**: Claude Code with Hooks

Agent is now monitoring for tasks labeled with \`$ISSUE_LABEL\`." 2>/dev/null || true
    fi
fi

echo ""
echo "====================================="
echo "Claude Code Agent $AGENT_NAME Started"
echo "====================================="
echo ""
echo "The agent is now running and will:"
echo "1. Check for new GitHub issues with label '$ISSUE_LABEL'"
echo "2. Execute tasks using Claude Code"
echo "3. Report results back to GitHub"
echo ""
echo "To stop the agent, press Ctrl+C"
echo ""

# Start Claude Code with configuration
claude-code --config claude-code-config.yaml \
           --workspace "$WORKSPACE" \
           --log-file "$WORKSPACE/.agent/logs/claude-code.log"
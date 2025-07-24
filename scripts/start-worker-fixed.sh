#!/bin/bash
# Universal worker startup script with tmux server fix
# Usage: ./start-worker-fixed.sh <cc01|cc02|cc03>

if [ -z "$1" ]; then
    printf "Usage: $0 <cc01|cc02|cc03>\n"
    printf "Example: $0 cc01\n"
    exit 1
fi

WORKER_NAME=$(echo "$1" | tr '[:lower:]' '[:upper:]')
WORKER_LABEL=$(echo "$1" | tr '[:upper:]' '[:lower:]')
SESSION_NAME="${WORKER_LABEL}-github"

WORKERS_DIR="$(dirname "$0")"
SCRIPT_DIR="$WORKERS_DIR/claude-code-cluster/scripts"
VENV_DIR="$WORKERS_DIR/claude-code-cluster/.venv"

printf "Starting $WORKER_NAME worker...\n"

# Ensure tmux server is running
if ! tmux list-sessions >/dev/null 2>&1; then
    printf "Starting tmux server...\n"
    tmux start-server
    sleep 1
fi

# Check if already running
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
    printf "$WORKER_NAME is already running. Use 'tmux attach -t $SESSION_NAME' to view.\n"
    exit 1
fi

# Create working directory if not exists
mkdir -p "$WORKERS_DIR/$WORKER_LABEL/workspace"

# Start worker with proper error handling
printf "Creating tmux session...\n"
tmux new-session -d -s $SESSION_NAME -c "$WORKERS_DIR/$WORKER_LABEL" \
  "source $VENV_DIR/bin/activate && WORKER_NAME=$WORKER_NAME WORKER_LABEL=$WORKER_LABEL python3 $SCRIPT_DIR/github-worker-optimized.py || { echo 'Worker failed to start. Press Enter to exit.'; read; }"

# Verify session was created
sleep 2
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
    printf "$WORKER_NAME started successfully!\n"
    printf "View logs with: tmux attach -t $SESSION_NAME\n"
    printf "Stop with: tmux kill-session -t $SESSION_NAME\n"
    
    # Check if worker is actually running
    printf "\nChecking worker status...\n"
    PANE_OUTPUT=$(tmux capture-pane -t $SESSION_NAME -p 2>/dev/null | head -5)
    if [ -n "$PANE_OUTPUT" ]; then
        printf "Worker is running. Initial output:\n"
        echo "$PANE_OUTPUT"
    fi
else
    printf "ERROR: Failed to create tmux session\n"
    printf "Try running manually:\n"
    printf "  cd $WORKERS_DIR/$WORKER_LABEL\n"
    printf "  source ../claude-code-cluster/.venv/bin/activate\n"
    printf "  WORKER_NAME=$WORKER_NAME WORKER_LABEL=$WORKER_LABEL python3 ../claude-code-cluster/scripts/github-worker-optimized.py\n"
    exit 1
fi
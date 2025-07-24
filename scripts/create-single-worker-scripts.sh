#!/bin/bash
# Create individual worker startup scripts for separate PCs
# This script creates individual startup scripts for each worker

set -e

INSTALL_DIR="$HOME/claude-workers"
SCRIPT_DIR="$INSTALL_DIR/claude-code-cluster/scripts"
VENV_DIR="$INSTALL_DIR/claude-code-cluster/.venv"

printf "Creating individual worker scripts...\n"

# Create CC01 startup script
cat > "$INSTALL_DIR/start-cc01.sh" << 'EOF'
#!/bin/bash
WORKERS_DIR="$(dirname "$0")"
SCRIPT_DIR="$WORKERS_DIR/claude-code-cluster/scripts"
VENV_DIR="$WORKERS_DIR/claude-code-cluster/.venv"

printf "Starting CC01 worker...\n"

# Check if already running
if tmux has-session -t cc01-github 2>/dev/null; then
    printf "CC01 is already running. Use 'tmux attach -t cc01-github' to view.\n"
    exit 1
fi

# Start CC01
tmux new-session -d -s cc01-github -c "$WORKERS_DIR/cc01" \
  "source $VENV_DIR/bin/activate && WORKER_NAME=CC01 WORKER_LABEL=cc01 python3 $SCRIPT_DIR/github-worker-optimized.py"

printf "CC01 started successfully!\n"
printf "View logs with: tmux attach -t cc01-github\n"
printf "Stop with: tmux kill-session -t cc01-github\n"
EOF
chmod +x "$INSTALL_DIR/start-cc01.sh"

# Create CC02 startup script
cat > "$INSTALL_DIR/start-cc02.sh" << 'EOF'
#!/bin/bash
WORKERS_DIR="$(dirname "$0")"
SCRIPT_DIR="$WORKERS_DIR/claude-code-cluster/scripts"
VENV_DIR="$WORKERS_DIR/claude-code-cluster/.venv"

printf "Starting CC02 worker...\n"

# Check if already running
if tmux has-session -t cc02-github 2>/dev/null; then
    printf "CC02 is already running. Use 'tmux attach -t cc02-github' to view.\n"
    exit 1
fi

# Start CC02
tmux new-session -d -s cc02-github -c "$WORKERS_DIR/cc02" \
  "source $VENV_DIR/bin/activate && WORKER_NAME=CC02 WORKER_LABEL=cc02 python3 $SCRIPT_DIR/github-worker-optimized.py"

printf "CC02 started successfully!\n"
printf "View logs with: tmux attach -t cc02-github\n"
printf "Stop with: tmux kill-session -t cc02-github\n"
EOF
chmod +x "$INSTALL_DIR/start-cc02.sh"

# Create CC03 startup script
cat > "$INSTALL_DIR/start-cc03.sh" << 'EOF'
#!/bin/bash
WORKERS_DIR="$(dirname "$0")"
SCRIPT_DIR="$WORKERS_DIR/claude-code-cluster/scripts"
VENV_DIR="$WORKERS_DIR/claude-code-cluster/.venv"

printf "Starting CC03 worker...\n"

# Check if already running
if tmux has-session -t cc03-github 2>/dev/null; then
    printf "CC03 is already running. Use 'tmux attach -t cc03-github' to view.\n"
    exit 1
fi

# Start CC03
tmux new-session -d -s cc03-github -c "$WORKERS_DIR/cc03" \
  "source $VENV_DIR/bin/activate && WORKER_NAME=CC03 WORKER_LABEL=cc03 python3 $SCRIPT_DIR/github-worker-optimized.py"

printf "CC03 started successfully!\n"
printf "View logs with: tmux attach -t cc03-github\n"
printf "Stop with: tmux kill-session -t cc03-github\n"
EOF
chmod +x "$INSTALL_DIR/start-cc03.sh"

# Create individual stop scripts
cat > "$INSTALL_DIR/stop-cc01.sh" << 'EOF'
#!/bin/bash
printf "Stopping CC01 worker...\n"
if tmux has-session -t cc01-github 2>/dev/null; then
    tmux kill-session -t cc01-github
    printf "CC01 stopped.\n"
else
    printf "CC01 was not running.\n"
fi
EOF
chmod +x "$INSTALL_DIR/stop-cc01.sh"

cat > "$INSTALL_DIR/stop-cc02.sh" << 'EOF'
#!/bin/bash
printf "Stopping CC02 worker...\n"
if tmux has-session -t cc02-github 2>/dev/null; then
    tmux kill-session -t cc02-github
    printf "CC02 stopped.\n"
else
    printf "CC02 was not running.\n"
fi
EOF
chmod +x "$INSTALL_DIR/stop-cc02.sh"

cat > "$INSTALL_DIR/stop-cc03.sh" << 'EOF'
#!/bin/bash
printf "Stopping CC03 worker...\n"
if tmux has-session -t cc03-github 2>/dev/null; then
    tmux kill-session -t cc03-github
    printf "CC03 stopped.\n"
else
    printf "CC03 was not running.\n"
fi
EOF
chmod +x "$INSTALL_DIR/stop-cc03.sh"

# Create status check for individual workers
cat > "$INSTALL_DIR/check-single-worker.sh" << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    printf "Usage: $0 <cc01|cc02|cc03>\n"
    printf "Check status of a specific worker.\n"
    exit 1
fi

WORKER=$1
SESSION="${WORKER}-github"

printf "=== $WORKER Worker Status ===\n\n"

if tmux has-session -t $SESSION 2>/dev/null; then
    printf "✓ $WORKER: Running\n"
    printf "View logs: tmux attach -t $SESSION\n"
    printf "Stop worker: ./stop-$WORKER.sh\n"
else
    printf "✗ $WORKER: Stopped\n"
    printf "Start worker: ./start-$WORKER.sh\n"
fi

# Check recent activity
STATE_FILE="$HOME/.claude/state/worker-$WORKER.json"
if [ -f "$STATE_FILE" ]; then
    printf "\n=== Recent Activity ===\n"
    last_poll=$(jq -r '.last_poll // "Never"' "$STATE_FILE" 2>/dev/null || echo "Never")
    printf "Last poll: $last_poll\n"
fi

# Check UV environment
printf "\n=== UV Environment ===\n"
VENV_DIR="$(dirname "$0")/claude-code-cluster/.venv"
if [ -d "$VENV_DIR" ]; then
    printf "Virtual environment: Available\n"
else
    printf "Virtual environment: Not found\n"
fi
EOF
chmod +x "$INSTALL_DIR/check-single-worker.sh"

printf "\n=== Individual Worker Scripts Created ===\n"
printf "\nAvailable commands for each PC:\n"
printf "\n=== For PC running CC01 ===\n"
printf "  ./start-cc01.sh     - Start CC01 worker\n"
printf "  ./stop-cc01.sh      - Stop CC01 worker\n"
printf "  ./check-single-worker.sh cc01 - Check CC01 status\n"
printf "\n=== For PC running CC02 ===\n"
printf "  ./start-cc02.sh     - Start CC02 worker\n"
printf "  ./stop-cc02.sh      - Stop CC02 worker\n"
printf "  ./check-single-worker.sh cc02 - Check CC02 status\n"
printf "\n=== For PC running CC03 ===\n"
printf "  ./start-cc03.sh     - Start CC03 worker\n"
printf "  ./stop-cc03.sh      - Stop CC03 worker\n"
printf "  ./check-single-worker.sh cc03 - Check CC03 status\n"
printf "\n=== General commands (available on all PCs) ===\n"
printf "  ./uv-manage.sh shell - Enter UV virtual environment\n"
printf "  ./uv-manage.sh list  - List installed packages\n"
printf "\nTo view worker logs: tmux attach -t <worker>-github\n"
printf "To detach from logs: Ctrl+B then D\n"
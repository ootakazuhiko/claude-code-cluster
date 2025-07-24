#!/bin/bash
# GitHub-based Claude Code Cluster Installation with uv
# Uses uv instead of pip for better Python package management

set -e

printf "=== Claude Code Cluster GitHub Installation (uv) ===\n"
printf "This installs the GitHub-only communication system using uv.\n"
printf "\n"

# Check prerequisites
printf "Checking prerequisites...\n"

# Check Python version
PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' 2>/dev/null || echo "0.0")
if [ "$(printf '%s\n' "3.8" "$PYTHON_VERSION" | sort -V | head -n1)" != "3.8" ]; then
    printf "ERROR: Python 3.8+ required (current: $PYTHON_VERSION)\n"
    exit 1
fi
printf "Python $PYTHON_VERSION - OK\n"

# Check uv
if ! command -v uv &> /dev/null; then
    printf "uv not found. Installing uv...\n"
    # Install uv using the official installer
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Add uv to PATH for current session
    export PATH="$HOME/.local/bin:$PATH"
    
    # Verify installation
    if ! command -v uv &> /dev/null; then
        printf "ERROR: Failed to install uv\n"
        printf "Please install manually: curl -LsSf https://astral.sh/uv/install.sh | sh\n"
        exit 1
    fi
    printf "uv installed - OK\n"
else
    printf "uv - OK\n"
fi

# Check git
if ! command -v git &> /dev/null; then
    printf "ERROR: git not found\n"
    exit 1
fi
printf "git - OK\n"

# Check GitHub token
if [ -z "${GITHUB_TOKEN:-}" ]; then
    printf "\nGitHub token not set.\n"
    printf "Create token at: https://github.com/settings/tokens\n"
    printf "Select 'repo' scope and copy the token.\n"
    printf "\n"
    printf "Enter GitHub token: "
    read -r GITHUB_TOKEN
    
    if [ -z "$GITHUB_TOKEN" ]; then
        printf "ERROR: No token provided\n"
        exit 1
    fi
fi

# Validate token
printf "Validating token..."
if curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | grep -q '"login"'; then
    printf " OK\n"
else
    printf " FAILED\n"
    printf "ERROR: Invalid GitHub token\n"
    exit 1
fi

# Setup directories
INSTALL_DIR="$HOME/claude-workers"
printf "\nCreating directories...\n"
mkdir -p "$INSTALL_DIR"/{cc01,cc02,cc03,manager}/workspace
mkdir -p ~/.claude/state
printf "Directories created\n"

# Clone repository
printf "\nCloning repository...\n"
cd "$INSTALL_DIR"
if [ -d "claude-code-cluster" ]; then
    printf "Updating existing repository...\n"
    cd claude-code-cluster
    git pull
else
    printf "Cloning new repository...\n"
    git clone https://github.com/ootakazuhiko/claude-code-cluster.git
    cd claude-code-cluster
fi
printf "Repository ready\n"

# Install Python dependencies with uv
printf "\nInstalling Python dependencies with uv...\n"
# Create a virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    uv venv
    printf "Virtual environment created\n"
fi

# Install dependencies
uv pip install PyGithub httpx
printf "Dependencies installed with uv\n"

# Make scripts executable
printf "\nSetting up scripts...\n"
chmod +x scripts/github-worker-optimized.py 2>/dev/null || true
chmod +x scripts/start-github-worker.sh 2>/dev/null || true
printf "Scripts ready\n"

# Setup environment
printf "\nConfiguring environment...\n"
if ! grep -q "# Claude Code Cluster (GitHub-based)" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << EOF

# Claude Code Cluster (GitHub-based)
export GITHUB_TOKEN="$GITHUB_TOKEN"
export GITHUB_REPO="${GITHUB_REPO:-ootakazuhiko/claude-code-cluster}"
export CLAUDE_WORKERS_HOME="$INSTALL_DIR"
export PATH="$HOME/.local/bin:\$PATH"
alias claude-workers='cd \$CLAUDE_WORKERS_HOME'
EOF
    printf "Environment variables added to ~/.bashrc\n"
else
    printf "Environment already configured\n"
fi

# Create convenience scripts
printf "\nCreating management scripts...\n"

# Start all workers script
cat > "$INSTALL_DIR/start-all-workers.sh" << 'EOF'
#!/bin/bash
WORKERS_DIR="$(dirname "$0")"
SCRIPT_DIR="$WORKERS_DIR/claude-code-cluster/scripts"
VENV_DIR="$WORKERS_DIR/claude-code-cluster/.venv"

printf "Starting all workers with uv...\n"

# Activate virtual environment and start CC01
tmux new-session -d -s cc01-github -c "$WORKERS_DIR/cc01" \
  "source $VENV_DIR/bin/activate && WORKER_NAME=CC01 WORKER_LABEL=cc01 python3 $SCRIPT_DIR/github-worker-optimized.py"
printf "CC01 started\n"
sleep 2

# Activate virtual environment and start CC02
tmux new-session -d -s cc02-github -c "$WORKERS_DIR/cc02" \
  "source $VENV_DIR/bin/activate && WORKER_NAME=CC02 WORKER_LABEL=cc02 python3 $SCRIPT_DIR/github-worker-optimized.py"
printf "CC02 started\n"
sleep 2

# Activate virtual environment and start CC03
tmux new-session -d -s cc03-github -c "$WORKERS_DIR/cc03" \
  "source $VENV_DIR/bin/activate && WORKER_NAME=CC03 WORKER_LABEL=cc03 python3 $SCRIPT_DIR/github-worker-optimized.py"
printf "CC03 started\n"

printf "\nAll workers started. View with:\n"
printf "  tmux attach -t cc01-github\n"
printf "  tmux attach -t cc02-github\n"
printf "  tmux attach -t cc03-github\n"
EOF
chmod +x "$INSTALL_DIR/start-all-workers.sh"

# Stop all workers script
cat > "$INSTALL_DIR/stop-all-workers.sh" << 'EOF'
#!/bin/bash
printf "Stopping all workers...\n"

for session in cc01-github cc02-github cc03-github; do
    if tmux has-session -t $session 2>/dev/null; then
        tmux kill-session -t $session
        printf "Stopped $session\n"
    fi
done
printf "All workers stopped.\n"
EOF
chmod +x "$INSTALL_DIR/stop-all-workers.sh"

# Status check script
cat > "$INSTALL_DIR/check-status.sh" << 'EOF'
#!/bin/bash
printf "=== Worker Status ===\n\n"

for session in cc01-github cc02-github cc03-github; do
    if tmux has-session -t $session 2>/dev/null; then
        printf "✓ $session: Running\n"
    else
        printf "✗ $session: Stopped\n"
    fi
done

printf "\n=== Recent Activity ===\n"
for state_file in ~/.claude/state/worker-*.json; do
    if [ -f "$state_file" ]; then
        worker=$(basename "$state_file" .json)
        last_poll=$(jq -r '.last_poll // "Never"' "$state_file" 2>/dev/null || echo "Never")
        printf "$worker: Last poll at $last_poll\n"
    fi
done

printf "\n=== UV Environment ===\n"
VENV_DIR="$(dirname "$0")/claude-code-cluster/.venv"
if [ -d "$VENV_DIR" ]; then
    printf "Virtual environment: $VENV_DIR\n"
    if [ -f "$VENV_DIR/pyvenv.cfg" ]; then
        printf "Python version: $(grep "version" "$VENV_DIR/pyvenv.cfg" | cut -d' ' -f3)\n"
    fi
else
    printf "Virtual environment: Not found\n"
fi
EOF
chmod +x "$INSTALL_DIR/check-status.sh"

# Test script
cat > "$INSTALL_DIR/test-worker.sh" << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    printf "Usage: $0 <cc01|cc02|cc03>\n"
    exit 1
fi

WORKER=$1
printf "Creating test issue for $WORKER...\n"

gh issue create \
    --repo "$GITHUB_REPO" \
    --title "Test task for $WORKER - $(date +%Y%m%d-%H%M%S)" \
    --body "Automated test task to verify $WORKER is working correctly." \
    --label "$1"

printf "Test issue created. Check worker logs.\n"
EOF
chmod +x "$INSTALL_DIR/test-worker.sh"

# UV management script
cat > "$INSTALL_DIR/uv-manage.sh" << 'EOF'
#!/bin/bash
VENV_DIR="$(dirname "$0")/claude-code-cluster/.venv"

case "$1" in
    "shell")
        printf "Activating uv virtual environment...\n"
        cd "$(dirname "$0")/claude-code-cluster"
        exec bash -c "source .venv/bin/activate && exec bash"
        ;;
    "install")
        printf "Installing package: $2\n"
        cd "$(dirname "$0")/claude-code-cluster"
        uv pip install "$2"
        ;;
    "list")
        printf "Installed packages:\n"
        cd "$(dirname "$0")/claude-code-cluster"
        uv pip list
        ;;
    "sync")
        printf "Syncing dependencies...\n"
        cd "$(dirname "$0")/claude-code-cluster"
        uv pip sync requirements.txt 2>/dev/null || printf "No requirements.txt found\n"
        ;;
    *)
        printf "UV Management Tool\n\n"
        printf "Usage: $0 <command>\n\n"
        printf "Commands:\n"
        printf "  shell     - Activate virtual environment shell\n"
        printf "  install   - Install a package\n"
        printf "  list      - List installed packages\n"
        printf "  sync      - Sync from requirements.txt\n"
        ;;
esac
EOF
chmod +x "$INSTALL_DIR/uv-manage.sh"

printf "Management scripts created\n"

# Installation complete
printf "\n=== Installation Complete ===\n"
printf "\nInstalled components:\n"
printf "  - Working directory: $INSTALL_DIR\n"
printf "  - Python worker: github-worker-optimized.py\n"
printf "  - UV virtual environment: .venv\n"
printf "  - Management scripts:\n"
printf "    - start-all-workers.sh\n"
printf "    - stop-all-workers.sh\n"
printf "    - check-status.sh\n"
printf "    - test-worker.sh\n"
printf "    - uv-manage.sh (UV utilities)\n"
printf "\n"
printf "Next steps:\n"
printf "\n"
printf "1. Reload environment:\n"
printf "   source ~/.bashrc\n"
printf "\n"
printf "2. Start workers:\n"
printf "   cd $INSTALL_DIR\n"
printf "   ./start-all-workers.sh\n"
printf "\n"
printf "3. Check status:\n"
printf "   ./check-status.sh\n"
printf "\n"
printf "4. Test with issue:\n"
printf "   ./test-worker.sh cc01\n"
printf "\n"
printf "5. Manage UV environment:\n"
printf "   ./uv-manage.sh shell    # Enter virtual environment\n"
printf "   ./uv-manage.sh list     # List packages\n"
printf "\n"
printf "Installation with uv successful!\n"
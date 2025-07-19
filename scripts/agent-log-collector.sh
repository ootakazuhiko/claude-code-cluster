#!/bin/bash
# Claude Code Agent Raw Log Collector
# Collects raw logs and system info, then pushes to GitHub

set -euo pipefail

# Configuration
AGENT_NAME="${AGENT_NAME:-Unknown}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEMP_DIR="/tmp/claude-logs-${AGENT_NAME}-${TIMESTAMP}"
LOG_BRANCH="logs/${AGENT_NAME}/$(date +%Y%m%d)"
PROJECT_DIR="${HOME}/ITDO_ERP2/claude-code-cluster"

# Create temporary directory for logs
mkdir -p "${TEMP_DIR}"

echo "Starting log collection for Agent: ${AGENT_NAME}"
echo "Timestamp: ${TIMESTAMP}"
echo "Collecting to: ${TEMP_DIR}"

# Function to safely copy files
safe_copy() {
    local source=$1
    local dest=$2
    if [ -e "$source" ]; then
        cp -r "$source" "$dest" 2>/dev/null || echo "Failed to copy $source"
    fi
}

# 1. System Information
echo "Collecting system information..."
{
    echo "=== System Information ==="
    echo "Agent: ${AGENT_NAME}"
    echo "Timestamp: $(date)"
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo ""
    echo "=== OS Info ==="
    uname -a
    cat /etc/os-release 2>/dev/null || true
    echo ""
    echo "=== Memory ==="
    free -h
    echo ""
    echo "=== Disk Usage ==="
    df -h
    echo ""
    echo "=== Process List ==="
    ps aux | grep -E "(claude|node|python)" | grep -v grep || true
    echo ""
    echo "=== Network Connections ==="
    ss -an | grep -E "(ESTAB|LISTEN)" | grep -E "(github|140.82|192.30|443|22)" || true
} > "${TEMP_DIR}/system_info.txt"

# 2. Claude Code Session Files
echo "Collecting Claude Code session files..."
mkdir -p "${TEMP_DIR}/claude-sessions"
find ~/.claude* ~/.config -name "*claude*" -type f -mtime -7 2>/dev/null | while read -r file; do
    safe_copy "$file" "${TEMP_DIR}/claude-sessions/"
done

# 3. Shell History (last 1000 lines)
echo "Collecting shell history..."
if [ -f ~/.bash_history ]; then
    tail -1000 ~/.bash_history > "${TEMP_DIR}/bash_history.txt" 2>/dev/null || true
fi
if [ -f ~/.zsh_history ]; then
    tail -1000 ~/.zsh_history > "${TEMP_DIR}/zsh_history.txt" 2>/dev/null || true
fi

# 4. Git Information
echo "Collecting Git information..."
cd "${HOME}/ITDO_ERP2" 2>/dev/null || cd /home/*/ITDO_ERP2 2>/dev/null || {
    echo "Project directory not found" > "${TEMP_DIR}/git_error.txt"
}

if [ -d .git ]; then
    {
        echo "=== Git Status ==="
        git status
        echo ""
        echo "=== Current Branch ==="
        git branch --show-current
        echo ""
        echo "=== Recent Commits (last 50) ==="
        git log --oneline --all --since="7 days ago" --format="%h %ai %an: %s" | head -50
        echo ""
        echo "=== Modified Files ==="
        git diff --name-only
        echo ""
        echo "=== Staged Files ==="
        git diff --cached --name-only
        echo ""
        echo "=== All Branches ==="
        git branch -a
        echo ""
        echo "=== Stash List ==="
        git stash list
    } > "${TEMP_DIR}/git_info.txt" 2>&1
fi

# 5. Recent File Activity
echo "Collecting recent file activity..."
find . -type f -mtime -1 -not -path "./.git/*" 2>/dev/null | head -100 > "${TEMP_DIR}/recent_files.txt"

# 6. Claude Code specific logs (if any)
echo "Looking for Claude Code logs..."
mkdir -p "${TEMP_DIR}/claude-logs"
for log_dir in \
    ~/.claude*/logs \
    ~/.config/claude*/logs \
    ~/.local/share/claude* \
    /tmp/claude* \
    /var/log/claude*
do
    if [ -d "$log_dir" ]; then
        echo "Found log directory: $log_dir"
        find "$log_dir" -name "*.log" -mtime -7 -exec cp {} "${TEMP_DIR}/claude-logs/" \; 2>/dev/null || true
    fi
done

# 7. Environment Variables (filtered for safety)
echo "Collecting environment info..."
env | grep -E "(CLAUDE|PATH|HOME|USER|SHELL|AGENT)" | grep -v -E "(TOKEN|KEY|SECRET|PASSWORD)" > "${TEMP_DIR}/environment.txt"

# 8. Create metadata file
cat > "${TEMP_DIR}/metadata.json" << EOF
{
  "agent": "${AGENT_NAME}",
  "timestamp": "${TIMESTAMP}",
  "collection_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "user": "$(whoami)",
  "log_version": "1.0"
}
EOF

# 9. Push to GitHub
echo "Preparing to push logs to GitHub..."
cd "${PROJECT_DIR}" || {
    echo "ERROR: Project directory not found at ${PROJECT_DIR}"
    echo "Logs collected at: ${TEMP_DIR}"
    exit 1
}

# Ensure we're on main/master branch first
git checkout main 2>/dev/null || git checkout master 2>/dev/null || {
    echo "ERROR: Cannot checkout main branch"
    exit 1
}

# Pull latest changes
git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true

# Create or checkout log branch
git checkout -b "${LOG_BRANCH}" 2>/dev/null || git checkout "${LOG_BRANCH}"

# Create logs directory structure
LOG_DIR="logs/${AGENT_NAME}/${TIMESTAMP}"
mkdir -p "${LOG_DIR}"

# Copy all collected logs
cp -r "${TEMP_DIR}"/* "${LOG_DIR}/"

# Add and commit
git add "${LOG_DIR}"
git commit -m "chore: Add ${AGENT_NAME} logs - ${TIMESTAMP}

Automated log collection from ${AGENT_NAME}
Contains system info, git status, and activity logs
" || {
    echo "No changes to commit"
}

# Push to remote
echo "Pushing logs to GitHub..."
git push origin "${LOG_BRANCH}" || {
    echo "ERROR: Failed to push to GitHub"
    echo "Logs saved locally at: ${LOG_DIR}"
    exit 1
}

# Return to main branch
git checkout main 2>/dev/null || git checkout master 2>/dev/null

# Cleanup temp directory
rm -rf "${TEMP_DIR}"

echo ""
echo "✅ Log collection complete!"
echo "Branch: ${LOG_BRANCH}"
echo "Path: ${LOG_DIR}"
echo ""
echo "To view logs on GitHub:"
echo "  https://github.com/itdojp/ITDO_ERP2/tree/${LOG_BRANCH}/claude-code-cluster/${LOG_DIR}"
echo ""
echo "Logs have been pushed to GitHub for central analysis."
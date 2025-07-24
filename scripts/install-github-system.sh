#!/bin/bash
# Installation script for GitHub-based Claude Code Cluster
# Simple, network-independent worker system

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
INSTALL_DIR="$HOME/claude-workers"
REPO_URL="https://github.com/ootakazuhiko/claude-code-cluster.git"

echo -e "${BLUE}=== Claude Code Cluster (GitHub通信版) インストール ===${NC}"
echo
echo "このインストーラーは、GitHub API経由で通信する"
echo "新しいClaude Code Clusterシステムをセットアップします。"
echo

# Step 1: Check prerequisites
echo -e "${BLUE}Step 1: 前提条件の確認${NC}"

# Check Python version
PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
REQUIRED_VERSION="3.8"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo -e "${RED}エラー: Python $REQUIRED_VERSION 以上が必要です (現在: $PYTHON_VERSION)${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Python $PYTHON_VERSION"

# Check pip
if ! command -v pip3 &> /dev/null; then
    echo -e "${RED}エラー: pip3がインストールされていません${NC}"
    echo "インストール: sudo apt install python3-pip"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} pip3"

# Check git
if ! command -v git &> /dev/null; then
    echo -e "${RED}エラー: gitがインストールされていません${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} git"

# Step 2: Check GitHub token
echo -e "\n${BLUE}Step 2: GitHubトークンの確認${NC}"

if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo -e "${YELLOW}GitHubトークンが設定されていません。${NC}"
    echo
    echo "トークンの作成方法:"
    echo "1. https://github.com/settings/tokens にアクセス"
    echo "2. 'Generate new token (classic)' をクリック"
    echo "3. 'repo' スコープを選択"
    echo "4. トークンを生成してコピー"
    echo
    read -p "GitHubトークンを入力してください: " GITHUB_TOKEN
    
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${RED}エラー: トークンが入力されませんでした${NC}"
        exit 1
    fi
fi

# Validate token
echo -n "トークンを検証中..."
if curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | grep -q '"login"'; then
    echo -e " ${GREEN}✓${NC}"
else
    echo -e " ${RED}✗${NC}"
    echo -e "${RED}エラー: 無効なGitHubトークンです${NC}"
    exit 1
fi

# Step 3: Create directory structure
echo -e "\n${BLUE}Step 3: ディレクトリ構造の作成${NC}"

mkdir -p "$INSTALL_DIR"/{cc01,cc02,cc03,manager}/workspace
mkdir -p ~/.claude/state
echo -e "  ${GREEN}✓${NC} ディレクトリ作成完了"

# Step 4: Clone repository
echo -e "\n${BLUE}Step 4: リポジトリのクローン${NC}"

cd "$INSTALL_DIR"
if [ -d "claude-code-cluster" ]; then
    echo "既存のリポジトリを更新中..."
    cd claude-code-cluster
    git pull
else
    echo "リポジトリをクローン中..."
    git clone "$REPO_URL"
    cd claude-code-cluster
fi
echo -e "  ${GREEN}✓${NC} リポジトリ準備完了"

# Step 5: Install Python dependencies
echo -e "\n${BLUE}Step 5: Python依存関係のインストール${NC}"

pip3 install --user PyGithub httpx
echo -e "  ${GREEN}✓${NC} 依存関係インストール完了"

# Step 6: Make scripts executable
echo -e "\n${BLUE}Step 6: スクリプトの実行権限設定${NC}"

chmod +x scripts/github-worker-optimized.py
chmod +x scripts/start-github-worker.sh
echo -e "  ${GREEN}✓${NC} 実行権限設定完了"

# Step 7: Setup environment
echo -e "\n${BLUE}Step 7: 環境設定${NC}"

# Check if already configured
if ! grep -q "# Claude Code Cluster (GitHub-based)" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << EOF

# Claude Code Cluster (GitHub-based)
export GITHUB_TOKEN="$GITHUB_TOKEN"
export GITHUB_REPO="${GITHUB_REPO:-ootakazuhiko/claude-code-cluster}"
export CLAUDE_WORKERS_HOME="$INSTALL_DIR"
alias claude-workers='cd \$CLAUDE_WORKERS_HOME'
EOF
    echo -e "  ${GREEN}✓${NC} 環境変数を.bashrcに追加"
else
    echo -e "  ${YELLOW}!${NC} 環境変数は既に設定されています"
fi

# Step 8: Create convenience scripts
echo -e "\n${BLUE}Step 8: 便利スクリプトの作成${NC}"

# Start all workers script
cat > "$INSTALL_DIR/start-all-workers.sh" << 'EOF'
#!/bin/bash
# Start all Claude workers in tmux sessions

WORKERS_DIR="$(dirname "$0")"
SCRIPT_DIR="$WORKERS_DIR/claude-code-cluster/scripts"

echo "Starting all workers..."

# Start each worker in tmux
tmux new-session -d -s cc01-github -c "$WORKERS_DIR/cc01" \
  "WORKER_NAME=CC01 WORKER_LABEL=cc01 python3 $SCRIPT_DIR/github-worker-optimized.py"
echo "✓ CC01 started"

sleep 2

tmux new-session -d -s cc02-github -c "$WORKERS_DIR/cc02" \
  "WORKER_NAME=CC02 WORKER_LABEL=cc02 python3 $SCRIPT_DIR/github-worker-optimized.py"
echo "✓ CC02 started"

sleep 2

tmux new-session -d -s cc03-github -c "$WORKERS_DIR/cc03" \
  "WORKER_NAME=CC03 WORKER_LABEL=cc03 python3 $SCRIPT_DIR/github-worker-optimized.py"
echo "✓ CC03 started"

echo
echo "All workers started. View with:"
echo "  tmux attach -t cc01-github"
echo "  tmux attach -t cc02-github"
echo "  tmux attach -t cc03-github"
EOF

chmod +x "$INSTALL_DIR/start-all-workers.sh"

# Stop all workers script
cat > "$INSTALL_DIR/stop-all-workers.sh" << 'EOF'
#!/bin/bash
# Stop all Claude workers

echo "Stopping all workers..."

for session in cc01-github cc02-github cc03-github; do
    if tmux has-session -t $session 2>/dev/null; then
        tmux kill-session -t $session
        echo "✓ $session stopped"
    fi
done

echo "All workers stopped."
EOF

chmod +x "$INSTALL_DIR/stop-all-workers.sh"

# Status check script
cat > "$INSTALL_DIR/check-status.sh" << 'EOF'
#!/bin/bash
# Check status of all workers

echo "=== Worker Status ==="
echo

for session in cc01-github cc02-github cc03-github; do
    if tmux has-session -t $session 2>/dev/null; then
        echo "✓ $session: Running"
    else
        echo "✗ $session: Stopped"
    fi
done

echo
echo "=== Recent Activity ==="
for state_file in ~/.claude/state/worker-*.json; do
    if [ -f "$state_file" ]; then
        worker=$(basename "$state_file" .json)
        last_poll=$(jq -r '.last_poll // "Never"' "$state_file" 2>/dev/null)
        echo "$worker: Last poll at $last_poll"
    fi
done
EOF

chmod +x "$INSTALL_DIR/check-status.sh"

echo -e "  ${GREEN}✓${NC} 便利スクリプト作成完了"

# Step 9: Create test script
echo -e "\n${BLUE}Step 9: テストスクリプトの作成${NC}"

cat > "$INSTALL_DIR/test-worker.sh" << 'EOF'
#!/bin/bash
# Test worker functionality

if [ -z "$1" ]; then
    echo "Usage: $0 <cc01|cc02|cc03>"
    exit 1
fi

WORKER=$1
LABEL=$1

echo "Creating test issue for $WORKER..."

gh issue create \
    --repo "$GITHUB_REPO" \
    --title "Test task for $WORKER - $(date +%Y%m%d-%H%M%S)" \
    --body "This is an automated test task to verify $WORKER is working correctly." \
    --label "$LABEL"

echo "Test issue created. Check worker logs to see if it's detected."
EOF

chmod +x "$INSTALL_DIR/test-worker.sh"

echo -e "  ${GREEN}✓${NC} テストスクリプト作成完了"

# Step 10: Installation summary
echo -e "\n${BLUE}=== インストール完了 ===${NC}"
echo
echo -e "${GREEN}インストールされた項目:${NC}"
echo "  - 作業ディレクトリ: $INSTALL_DIR"
echo "  - Pythonスクリプト: github-worker-optimized.py"
echo "  - 便利スクリプト:"
echo "    - start-all-workers.sh"
echo "    - stop-all-workers.sh"
echo "    - check-status.sh"
echo "    - test-worker.sh"
echo
echo -e "${BLUE}次のステップ:${NC}"
echo
echo "1. 新しいターミナルを開くか、環境をリロード:"
echo "   ${YELLOW}source ~/.bashrc${NC}"
echo
echo "2. ワーカーを起動:"
echo "   ${YELLOW}cd $INSTALL_DIR${NC}"
echo "   ${YELLOW}./start-all-workers.sh${NC}"
echo
echo "3. ステータス確認:"
echo "   ${YELLOW}./check-status.sh${NC}"
echo
echo "4. テストIssue作成:"
echo "   ${YELLOW}./test-worker.sh cc01${NC}"
echo
echo -e "${GREEN}インストールが完了しました！${NC}"
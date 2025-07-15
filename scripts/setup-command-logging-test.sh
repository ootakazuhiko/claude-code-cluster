#!/bin/bash

# Command Logging System Test Setup Script
# 新しいテストプロジェクトでコマンドロギングシステムをセットアップするスクリプト

set -e

echo "🚀 Command Logging System Test Setup"
echo "===================================="

# 設定
WORK_DIR="/tmp/command-logging-test"
CLUSTER_DIR="$WORK_DIR/claude-code-cluster"
TEST_REPO_NAME="test-command-logging-$(date +%Y%m%d%H%M%S)"
GITHUB_USER=$(gh api user -q .login 2>/dev/null || echo "")

# GitHub CLIの確認
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI (gh) is not installed"
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# GitHub認証の確認
if [ -z "$GITHUB_USER" ]; then
    echo "❌ Error: Not authenticated with GitHub"
    echo "Please run: gh auth login"
    exit 1
fi

echo "✅ GitHub User: $GITHUB_USER"

# 作業ディレクトリの作成
echo ""
echo "📁 Creating work directory..."
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# claude-code-clusterのクローン
if [ ! -d "$CLUSTER_DIR" ]; then
    echo ""
    echo "📥 Cloning claude-code-cluster..."
    git clone https://github.com/ootakazuhiko/claude-code-cluster.git
else
    echo ""
    echo "📥 Updating claude-code-cluster..."
    cd "$CLUSTER_DIR"
    git pull origin main
fi

cd "$CLUSTER_DIR"

# 実行権限の付与
echo ""
echo "🔧 Setting permissions..."
chmod +x hooks/*.py

# テストリポジトリの作成
echo ""
echo "📝 Creating test repository: $TEST_REPO_NAME"
read -p "Create public test repository? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    gh repo create "$TEST_REPO_NAME" --public --description "Test project for command logging system"
    
    # リポジトリのクローン
    echo ""
    echo "📥 Cloning test repository..."
    cd "$WORK_DIR"
    git clone "https://github.com/$GITHUB_USER/$TEST_REPO_NAME"
    cd "$TEST_REPO_NAME"
    
    # 基本的なREADMEを作成
    echo "# $TEST_REPO_NAME" > README.md
    echo "" >> README.md
    echo "Test project for Claude Code command logging system" >> README.md
    echo "" >> README.md
    echo "Created: $(date)" >> README.md
    
    git add README.md
    git commit -m "Initial commit"
    git push origin main
    
    # ラベルの作成
    echo ""
    echo "🏷️  Creating labels..."
    gh label create claude-code-task --description "Tasks for Claude Code agents" --color "0075ca" || true
    gh label create test --description "Test tasks" --color "d73a4a" || true
    gh label create backend --description "Backend tasks" --color "1d76db" || true
    gh label create frontend --description "Frontend tasks" --color "5319e7" || true
    
    # テストイシューの作成
    echo ""
    echo "📋 Creating test issues..."
    
    gh issue create --title "Test: Create hello world function" \
        --body "Create a simple hello world function in Python for testing the command logging system" \
        --label claude-code-task,test,backend
    
    gh issue create --title "Test: Add unit tests for hello world" \
        --body "Add comprehensive unit tests for the hello world function" \
        --label claude-code-task,test,backend
    
    gh issue create --title "Test: Create API endpoint" \
        --body "Create a simple REST API endpoint that returns hello world" \
        --label claude-code-task,test,backend
    
    gh issue create --title "Test: Add documentation" \
        --body "Create comprehensive documentation for the test project" \
        --label claude-code-task,test
    
    gh issue create --title "Test: Setup CI/CD pipeline" \
        --body "Create GitHub Actions workflow for testing" \
        --label claude-code-task,test
fi

# セットアップ完了メッセージ
echo ""
echo "✅ Setup Complete!"
echo "=================="
echo ""
echo "📍 Locations:"
echo "   - Claude Code Cluster: $CLUSTER_DIR"
echo "   - Test Repository: $WORK_DIR/$TEST_REPO_NAME"
echo "   - GitHub URL: https://github.com/$GITHUB_USER/$TEST_REPO_NAME"
echo ""
echo "🚀 Quick Start Commands:"
echo ""
echo "1. Start an agent with logging:"
echo "   cd $CLUSTER_DIR"
echo "   python3 hooks/universal-agent-auto-loop-with-logging.py TEST01 $GITHUB_USER $TEST_REPO_NAME --max-iterations 5"
echo ""
echo "2. Monitor logs in real-time (in another terminal):"
echo "   cd $CLUSTER_DIR"
echo "   python3 hooks/view-command-logs.py --agent TEST01-$TEST_REPO_NAME --follow"
echo ""
echo "3. View command statistics:"
echo "   cd $CLUSTER_DIR"
echo "   python3 hooks/view-command-logs.py --agent TEST01-$TEST_REPO_NAME --stats"
echo ""
echo "4. Export logs to JSON:"
echo "   cd $CLUSTER_DIR"
echo "   python3 hooks/view-command-logs.py --agent TEST01-$TEST_REPO_NAME --export /tmp/test_logs.json"
echo ""
echo "📚 For more information, see: $WORK_DIR/ITDO_ERP2/COMMAND_LOGGING_SETUP_GUIDE.md"
#!/bin/bash

# Claude Code Cluster - 自動インストールスクリプト
# Usage: curl -sSL https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/install.sh | bash

set -e

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# OS検出
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            OS="debian"
        elif [ -f /etc/redhat-release ]; then
            OS="rhel"
        else
            OS="linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        error "Unsupported OS: $OSTYPE"
    fi
    
    log "Detected OS: $OS"
}

# 必要なパッケージのインストール
install_dependencies() {
    log "Installing dependencies..."
    
    case $OS in
        "debian")
            sudo apt update
            sudo apt install -y python3.11 python3.11-pip python3.11-venv git curl wget
            
            # GitHub CLI
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            sudo apt update && sudo apt install gh
            ;;
        "rhel")
            sudo yum update -y
            sudo yum install -y python3.11 python3.11-pip git curl wget
            
            # GitHub CLI
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
            sudo yum install -y gh
            ;;
        "macos")
            # Homebrew check
            if ! command -v brew &> /dev/null; then
                warning "Homebrew not found. Installing..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            
            brew install python@3.11 git gh
            ;;
        *)
            error "Unsupported OS for automatic installation: $OS"
            ;;
    esac
    
    success "Dependencies installed"
}

# Python仮想環境の作成
setup_python_env() {
    log "Setting up Python environment..."
    
    # Python3.11の確認
    if ! command -v python3.11 &> /dev/null; then
        if command -v python3 &> /dev/null; then
            PYTHON_CMD="python3"
        else
            error "Python 3.11+ not found"
        fi
    else
        PYTHON_CMD="python3.11"
    fi
    
    # 仮想環境作成
    $PYTHON_CMD -m venv venv
    source venv/bin/activate
    
    # pip upgrade
    pip install --upgrade pip
    
    success "Python environment set up"
}

# リポジトリのクローン
clone_repository() {
    log "Cloning Claude Code Cluster repository..."
    
    if [ -d "claude-code-cluster" ]; then
        warning "Directory already exists. Pulling latest changes..."
        cd claude-code-cluster
        git pull origin main
    else
        git clone https://github.com/ootakazuhiko/claude-code-cluster.git
        cd claude-code-cluster
    fi
    
    success "Repository cloned"
}

# 権限設定
set_permissions() {
    log "Setting permissions..."
    
    chmod +x *.sh
    chmod +x hooks/*.py
    chmod +x scripts/*.sh
    
    success "Permissions set"
}

# 依存関係のインストール
install_python_dependencies() {
    log "Installing Python dependencies..."
    
    source venv/bin/activate
    
    # requirements.txtが存在しない場合の基本的な依存関係
    if [ ! -f "requirements.txt" ]; then
        log "Creating basic requirements.txt..."
        cat > requirements.txt << EOF
requests>=2.31.0
aiohttp>=3.8.0
asyncio>=3.4.3
python-dotenv>=1.0.0
click>=8.1.0
pydantic>=2.0.0
sqlalchemy>=2.0.0
sqlite3
EOF
    fi
    
    pip install -r requirements.txt
    
    success "Python dependencies installed"
}

# 環境設定ファイルの作成
create_env_file() {
    log "Creating environment configuration..."
    
    if [ ! -f ".env" ]; then
        cat > .env << EOF
# Claude Code Cluster Configuration
CLAUDE_API_KEY=your-claude-api-key-here
GITHUB_TOKEN=your-github-token-here

# System Configuration
CLAUDE_MODEL=claude-3-5-sonnet-20241022
AGENT_LOG_LEVEL=INFO
LOG_RETENTION_DAYS=30

# Production Settings
PRODUCTION_MODE=false
MONITORING_ENABLED=true
BACKUP_ENABLED=false

# Agent Configuration
AGENT_CONCURRENCY=2
AGENT_MEMORY_LIMIT=4G
AGENT_TIMEOUT=1800
EOF
        
        chmod 600 .env
        success "Environment file created"
    else
        warning "Environment file already exists"
    fi
}

# 基本的なディレクトリ構造の作成
create_directories() {
    log "Creating directory structure..."
    
    mkdir -p /tmp/claude-code-logs
    mkdir -p /tmp/agent-metrics
    mkdir -p logs
    mkdir -p backups
    
    success "Directory structure created"
}

# GitHub認証のセットアップ
setup_github_auth() {
    log "Setting up GitHub authentication..."
    
    if ! gh auth status &> /dev/null; then
        warning "GitHub CLI not authenticated. Please run 'gh auth login' after installation."
        echo "To authenticate with GitHub later, run:"
        echo "  gh auth login"
    else
        success "GitHub CLI already authenticated"
    fi
}

# 基本的なヘルスチェック
health_check() {
    log "Performing health check..."
    
    # Python環境の確認
    source venv/bin/activate
    python3 --version
    
    # 基本的なインポートテスト
    python3 -c "import sys; print('Python OK')"
    
    # GitHub CLI確認
    if command -v gh &> /dev/null; then
        gh --version
    else
        warning "GitHub CLI not found"
    fi
    
    success "Health check completed"
}

# 使用方法の表示
show_usage() {
    echo ""
    echo "🎉 Claude Code Cluster installation completed!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Set up authentication:"
    echo "   gh auth login"
    echo "   # Edit .env file and add your Claude API key"
    echo ""
    echo "2. Test the installation:"
    echo "   source venv/bin/activate"
    echo "   ./scripts/quick-test-command-logging.sh"
    echo ""
    echo "3. Start an agent:"
    echo "   ./start-agent-sonnet.sh CC01"
    echo ""
    echo "4. Start multiple agents:"
    echo "   ./hooks/start-agent-loop.sh start all"
    echo ""
    echo "5. Monitor agents:"
    echo "   python3 hooks/view-command-logs.py --stats"
    echo ""
    echo "📚 Documentation:"
    echo "   - Complete Guide: ./COMPLETE_DEPLOYMENT_GUIDE.md"
    echo "   - Quick Start: ./QUICK_START_PRODUCTION.md"
    echo "   - Setup Guide: ./COMMAND_LOGGING_SETUP_GUIDE.md"
    echo ""
    echo "🔧 Configuration files:"
    echo "   - Environment: .env"
    echo "   - Agent Config: agent-config/"
    echo "   - Hook Settings: hooks/claude-code-settings.json"
    echo ""
    echo "🆘 Support:"
    echo "   - GitHub Issues: https://github.com/ootakazuhiko/claude-code-cluster/issues"
    echo "   - Documentation: https://github.com/ootakazuhiko/claude-code-cluster#readme"
}

# メイン実行
main() {
    echo "🚀 Claude Code Cluster - Automatic Installation"
    echo "=============================================="
    
    detect_os
    install_dependencies
    clone_repository
    set_permissions
    setup_python_env
    install_python_dependencies
    create_env_file
    create_directories
    setup_github_auth
    health_check
    show_usage
    
    echo ""
    success "Installation completed successfully!"
    echo "Current directory: $(pwd)"
    echo "To activate the environment: source venv/bin/activate"
}

# スクリプト実行
main "$@"
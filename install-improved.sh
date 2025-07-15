#!/bin/bash

# Claude Code Cluster - Improved Installation Script
# Flexible installation with better error handling and non-root support
# Usage: 
#   curl -sSL https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/install-improved.sh | bash
#   ./install.sh [OPTIONS]

set -euo pipefail

# Configuration
SCRIPT_VERSION="2.0.0"
DEFAULT_INSTALL_DIR="$HOME/claude-code-cluster"
DEFAULT_VENV_DIR="venv"
REPO_URL="https://github.com/ootakazuhiko/claude-code-cluster.git"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Global variables
INSTALL_DIR=""
VENV_DIR=""
USE_SUDO=true
FORCE_INSTALL=false
SKIP_DEPS=false
INTERACTIVE=true
OS=""
DISTRO=""
PYTHON_CMD=""
ERRORS=()

# Logging functions
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
}

fatal() {
    error "$1"
    exit 1
}

info() {
    echo -e "${PURPLE}ℹ️  $1${NC}"
}

# Error tracking
track_error() {
    ERRORS+=("$1")
}

show_errors() {
    if [ ${#ERRORS[@]} -gt 0 ]; then
        echo
        error "The following errors occurred during installation:"
        for err in "${ERRORS[@]}"; do
            echo "  - $err"
        done
        echo
        warning "Installation completed with errors. Some features may not work correctly."
        echo "Please check the errors above and the troubleshooting guide."
    fi
}

# Usage information
show_help() {
    cat << EOF
Claude Code Cluster - Installation Script v${SCRIPT_VERSION}

USAGE:
    ./install.sh [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -d, --dir PATH          Installation directory (default: $DEFAULT_INSTALL_DIR)
    -v, --venv PATH         Virtual environment directory name (default: $DEFAULT_VENV_DIR)
    -n, --no-sudo           Don't use sudo for package installation (requires manual setup)
    -f, --force             Force reinstall even if already installed
    -s, --skip-deps         Skip system dependencies installation
    -y, --yes               Non-interactive mode (accept all prompts)
    --version               Show version information

EXAMPLES:
    # Default installation
    ./install.sh

    # Install to custom directory without sudo
    ./install.sh --dir /opt/claude-cluster --no-sudo

    # Force reinstall with automatic yes to all prompts
    ./install.sh --force --yes

    # Skip system dependencies (if already installed)
    ./install.sh --skip-deps

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -v|--venv)
                VENV_DIR="$2"
                shift 2
                ;;
            -n|--no-sudo)
                USE_SUDO=false
                shift
                ;;
            -f|--force)
                FORCE_INSTALL=true
                shift
                ;;
            -s|--skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            -y|--yes)
                INTERACTIVE=false
                shift
                ;;
            --version)
                echo "Claude Code Cluster Installer v${SCRIPT_VERSION}"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Ask for user confirmation
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$INTERACTIVE" = false ]; then
        return 0
    fi
    
    local response
    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n] " -n 1 -r response
    else
        read -p "$prompt [y/N] " -n 1 -r response
    fi
    echo
    
    case "$response" in
        [yY]) return 0 ;;
        [nN]) return 1 ;;
        "") [ "$default" = "y" ] && return 0 || return 1 ;;
        *) [ "$default" = "y" ] && return 0 || return 1 ;;
    esac
}

# OS detection with better error handling
detect_os() {
    log "Detecting operating system..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO="$ID"
            info "Detected: $NAME"
        elif [ -f /etc/debian_version ]; then
            DISTRO="debian"
            info "Detected: Debian-based Linux"
        elif [ -f /etc/redhat-release ]; then
            DISTRO="rhel"
            info "Detected: Red Hat-based Linux"
        else
            DISTRO="unknown"
            warning "Unknown Linux distribution"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
        info "Detected: macOS $(sw_vers -productVersion)"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        DISTRO="windows"
        info "Detected: Windows (Git Bash/Cygwin)"
    else
        error "Unsupported operating system: $OSTYPE"
        info "You can try manual installation following the documentation"
        exit 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Run command with or without sudo
run_cmd() {
    if [ "$USE_SUDO" = true ] && [ "$EUID" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

# Check Python installation
check_python() {
    log "Checking Python installation..."
    
    # Check for different Python versions
    local python_versions=("python3.11" "python3.10" "python3.9" "python3.8" "python3")
    
    for py in "${python_versions[@]}"; do
        if command_exists "$py"; then
            local version=$($py --version 2>&1 | awk '{print $2}')
            local major_minor=$(echo "$version" | cut -d. -f1,2)
            
            # Check if version is 3.8 or higher
            if awk -v ver="$major_minor" 'BEGIN {if (ver >= 3.8) exit 0; else exit 1}'; then
                PYTHON_CMD="$py"
                success "Found Python $version"
                return 0
            fi
        fi
    done
    
    error "Python 3.8 or higher not found"
    return 1
}

# Install system dependencies
install_dependencies() {
    if [ "$SKIP_DEPS" = true ]; then
        warning "Skipping system dependencies installation"
        return 0
    fi
    
    log "Installing system dependencies..."
    
    case "$DISTRO" in
        ubuntu|debian)
            if [ "$USE_SUDO" = false ]; then
                warning "Skipping apt package installation (no-sudo mode)"
                info "Please ensure the following packages are installed:"
                info "  python3-pip python3-venv git curl wget"
                return 0
            fi
            
            log "Updating package list..."
            run_cmd apt update || track_error "Failed to update package list"
            
            log "Installing packages..."
            run_cmd apt install -y python3-pip python3-venv git curl wget || track_error "Failed to install packages"
            
            # Install GitHub CLI if not present
            if ! command_exists gh; then
                log "Installing GitHub CLI..."
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | run_cmd dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | run_cmd tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                run_cmd apt update || track_error "Failed to update package list for GitHub CLI installation"
                run_cmd apt install -y gh || track_error "Failed to install GitHub CLI"
            fi
            ;;
            
        fedora|rhel|centos)
            if [ "$USE_SUDO" = false ]; then
                warning "Skipping yum/dnf package installation (no-sudo mode)"
                info "Please ensure the following packages are installed:"
                info "  python3-pip git curl wget"
                return 0
            fi
            
            local pkg_manager="yum"
            command_exists dnf && pkg_manager="dnf"
            
            log "Installing packages..."
            run_cmd $pkg_manager install -y python3-pip git curl wget || track_error "Failed to install packages"
            
            # Install GitHub CLI if not present
            if ! command_exists gh; then
                log "Installing GitHub CLI..."
                run_cmd $pkg_manager install -y 'dnf-command(config-manager)' || true
                run_cmd $pkg_manager config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
                run_cmd $pkg_manager install -y gh || track_error "Failed to install GitHub CLI"
            fi
            ;;
            
        arch|manjaro)
            if [ "$USE_SUDO" = false ]; then
                warning "Skipping pacman package installation (no-sudo mode)"
                info "Please ensure the following packages are installed:"
                info "  python-pip git curl wget github-cli"
                return 0
            fi
            
            log "Installing packages..."
            run_cmd pacman -Sy --noconfirm python-pip git curl wget github-cli || track_error "Failed to install packages"
            ;;
            
        macos)
            # Check for Homebrew
            if ! command_exists brew; then
                if confirm "Homebrew is not installed. Install it now?" "y"; then
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                else
                    warning "Homebrew is required for automatic dependency installation"
                    info "Please install dependencies manually"
                    return 0
                fi
            fi
            
            log "Installing packages..."
            brew install python@3.11 git gh || track_error "Failed to install packages"
            ;;
            
        windows)
            warning "Windows detected. Please ensure the following are installed:"
            info "  - Python 3.8 or higher"
            info "  - Git"
            info "  - GitHub CLI (optional)"
            info "Visit https://python.org and https://git-scm.com for installers"
            ;;
            
        *)
            warning "Unknown distribution. Please install dependencies manually:"
            info "  - Python 3.8+ with pip and venv"
            info "  - Git"
            info "  - GitHub CLI (optional)"
            ;;
    esac
}

# Setup Python virtual environment
setup_python_env() {
    log "Setting up Python virtual environment..."
    
    if ! check_python; then
        error "Python 3.8 or higher is required"
        info "Please install Python and run the installer again"
        exit 1
    fi
    
    # Check if venv module is available
    if ! $PYTHON_CMD -m venv --help >/dev/null 2>&1; then
        error "Python venv module not found"
        info "Please install python3-venv package"
        exit 1
    fi
    
    # Create virtual environment
    local venv_path="$INSTALL_DIR/$VENV_DIR"
    
    if [ -d "$venv_path" ] && [ "$FORCE_INSTALL" = false ]; then
        warning "Virtual environment already exists at $venv_path"
        if confirm "Remove and recreate?" "n"; then
            rm -rf "$venv_path"
        else
            log "Using existing virtual environment"
            return 0
        fi
    fi
    
    log "Creating virtual environment..."
    $PYTHON_CMD -m venv "$venv_path" || fatal "Failed to create virtual environment"
    
    # Activate and upgrade pip
    log "Upgrading pip..."
    if [ -f "$venv_path/bin/activate" ]; then
        source "$venv_path/bin/activate"
        pip install --upgrade pip setuptools wheel || track_error "Failed to upgrade pip"
    else
        error "Failed to activate virtual environment"
        return 1
    fi
    
    success "Python environment created"
}

# Clone or update repository
setup_repository() {
    log "Setting up Claude Code Cluster repository..."
    
    if [ -d "$INSTALL_DIR/.git" ]; then
        if [ "$FORCE_INSTALL" = true ]; then
            warning "Repository exists. Updating to latest version..."
            cd "$INSTALL_DIR"
            git fetch origin
            git reset --hard origin/main || track_error "Failed to reset repository"
        else
            log "Repository already exists. Pulling latest changes..."
            cd "$INSTALL_DIR"
            git pull origin main || track_error "Failed to update repository"
        fi
    else
        log "Cloning repository..."
        if [ -d "$INSTALL_DIR" ]; then
            if confirm "Directory $INSTALL_DIR exists. Remove it?" "n"; then
                rm -rf "$INSTALL_DIR"
            else
                fatal "Installation directory already exists"
            fi
        fi
        
        git clone "$REPO_URL" "$INSTALL_DIR" || fatal "Failed to clone repository"
        cd "$INSTALL_DIR"
    fi
    
    success "Repository ready"
}

# Set file permissions
set_permissions() {
    log "Setting file permissions..."
    
    cd "$INSTALL_DIR"
    
    # Make scripts executable
    find . -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true
    find hooks -name "*.py" -type f -exec chmod +x {} \; 2>/dev/null || true
    find scripts -name "*.py" -type f -exec chmod +x {} \; 2>/dev/null || true
    
    success "Permissions set"
}

# Install Python dependencies
install_python_dependencies() {
    log "Installing Python dependencies..."
    
    cd "$INSTALL_DIR"
    source "$VENV_DIR/bin/activate"
    
    # Create requirements.txt if it doesn't exist
    if [ ! -f "requirements.txt" ]; then
        log "Creating requirements.txt..."
        cat > requirements.txt << 'EOF'
# Core dependencies
requests>=2.31.0
aiohttp>=3.9.0
python-dotenv>=1.0.0
click>=8.1.0
pydantic>=2.0.0

# Database
sqlalchemy>=2.0.0

# Utilities
colorama>=0.4.6
tabulate>=0.9.0
python-dateutil>=2.8.0

# Development
pytest>=7.0.0
pytest-asyncio>=0.21.0
EOF
    fi
    
    # Install dependencies
    pip install -r requirements.txt || track_error "Failed to install Python dependencies"
    
    success "Python dependencies installed"
}

# Create environment configuration
create_env_file() {
    log "Creating environment configuration..."
    
    cd "$INSTALL_DIR"
    
    if [ -f ".env" ] && [ "$FORCE_INSTALL" = false ]; then
        warning ".env file already exists"
        if ! confirm "Overwrite?" "n"; then
            return 0
        fi
    fi
    
    cat > .env << 'EOF'
# Claude Code Cluster Configuration
# Please update these values with your actual credentials

# API Keys (REQUIRED)
CLAUDE_API_KEY=your-claude-api-key-here
GITHUB_TOKEN=your-github-token-here

# Model Configuration
CLAUDE_MODEL=claude-3-5-sonnet-20241022
CLAUDE_MODEL_FALLBACK=claude-3-opus-20240229

# Agent Configuration
AGENT_LOG_LEVEL=INFO
AGENT_CONCURRENCY=2
AGENT_MEMORY_LIMIT=4G
AGENT_TIMEOUT=1800
AGENT_RETRY_ATTEMPTS=3

# System Configuration
LOG_RETENTION_DAYS=30
MAX_LOG_SIZE_MB=100
BACKUP_ENABLED=false
MONITORING_ENABLED=true

# Performance Settings
CACHE_ENABLED=true
CACHE_TTL_SECONDS=300
CONNECTION_POOL_SIZE=10

# Production Settings
PRODUCTION_MODE=false
DEBUG_MODE=false
ENABLE_TELEMETRY=false
EOF
    
    chmod 600 .env
    success "Environment file created"
    
    warning "Please edit .env file and add your API keys"
}

# Create directory structure
create_directories() {
    log "Creating directory structure..."
    
    # Create necessary directories
    local dirs=(
        "/tmp/claude-code-logs"
        "/tmp/agent-metrics"
        "$INSTALL_DIR/logs"
        "$INSTALL_DIR/backups"
        "$INSTALL_DIR/data"
        "$HOME/.claude-code-cluster"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir" 2>/dev/null || track_error "Failed to create directory: $dir"
    done
    
    # Create user config directory
    if [ ! -f "$HOME/.claude-code-cluster/config.json" ]; then
        cat > "$HOME/.claude-code-cluster/config.json" << EOF
{
    "install_dir": "$INSTALL_DIR",
    "venv_dir": "$VENV_DIR",
    "version": "$SCRIPT_VERSION",
    "installed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    fi
    
    success "Directory structure created"
}

# Setup shell integration
setup_shell_integration() {
    log "Setting up shell integration..."
    
    local shell_rc=""
    local shell_name=""
    
    # Detect shell
    if [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
        shell_name="bash"
    elif [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
        shell_name="zsh"
    else
        warning "Unknown shell. Skipping shell integration"
        return 0
    fi
    
    # Create alias function
    local alias_content="
# Claude Code Cluster
alias ccc='cd $INSTALL_DIR && source $VENV_DIR/bin/activate'
alias ccc-logs='python3 $INSTALL_DIR/hooks/view-command-logs.py'
alias ccc-agent='$INSTALL_DIR/start-agent-sonnet.sh'
"
    
    # Check if already added
    if grep -q "Claude Code Cluster" "$shell_rc" 2>/dev/null; then
        log "Shell integration already exists"
    else
        if confirm "Add Claude Code Cluster aliases to $shell_rc?" "y"; then
            echo "$alias_content" >> "$shell_rc"
            success "Shell integration added to $shell_rc"
            info "Run 'source $shell_rc' to load the aliases"
        fi
    fi
}

# Run health checks
health_check() {
    log "Running health checks..."
    
    cd "$INSTALL_DIR"
    source "$VENV_DIR/bin/activate"
    
    # Check Python
    log "Python version: $($PYTHON_CMD --version)"
    
    # Check imports
    log "Testing Python imports..."
    python3 -c "
import sys
import os
try:
    import requests
    import aiohttp
    import click
    print('✓ Core imports successful')
except ImportError as e:
    print(f'✗ Import error: {e}')
    sys.exit(1)
" || track_error "Python import test failed"
    
    # Check GitHub CLI
    if command_exists gh; then
        log "GitHub CLI version: $(gh --version | head -1)"
        if ! gh auth status >/dev/null 2>&1; then
            warning "GitHub CLI not authenticated. Run: gh auth login"
        else
            success "GitHub CLI authenticated"
        fi
    else
        warning "GitHub CLI not found. Some features may be limited"
    fi
    
    # Check directories
    for dir in "/tmp/claude-code-logs" "$INSTALL_DIR/logs"; do
        if [ -w "$dir" ]; then
            success "Directory writable: $dir"
        else
            track_error "Directory not writable: $dir"
        fi
    done
    
    # Check executables
    local executables=(
        "start-agent-sonnet.sh"
        "hooks/command_logger.py"
        "hooks/view-command-logs.py"
    )
    
    for exe in "${executables[@]}"; do
        if [ -x "$INSTALL_DIR/$exe" ]; then
            success "Executable found: $exe"
        else
            track_error "Executable not found or not executable: $exe"
        fi
    done
}

# Show completion message
show_completion() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    success "Claude Code Cluster Installation Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    info "Installation Directory: $INSTALL_DIR"
    info "Virtual Environment: $INSTALL_DIR/$VENV_DIR"
    echo
    echo "📋 Next Steps:"
    echo
    echo "1. Configure API keys:"
    echo "   cd $INSTALL_DIR"
    echo "   nano .env  # Add your Claude API key and GitHub token"
    echo
    echo "2. Authenticate GitHub CLI:"
    echo "   gh auth login"
    echo
    echo "3. Activate the environment:"
    echo "   cd $INSTALL_DIR"
    echo "   source $VENV_DIR/bin/activate"
    echo
    echo "4. Run a test:"
    echo "   ./scripts/quick-test-command-logging.sh"
    echo
    echo "5. Start an agent:"
    echo "   ./start-agent-sonnet.sh CC01"
    echo
    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "✨ Installation completed successfully!"
    else
        show_errors
    fi
    echo
    echo "📚 Documentation:"
    echo "   - Setup Guide: $INSTALL_DIR/COMMAND_LOGGING_SETUP_GUIDE.md"
    echo "   - Deployment: $INSTALL_DIR/COMPLETE_DEPLOYMENT_GUIDE.md"
    echo "   - GitHub: https://github.com/ootakazuhiko/claude-code-cluster"
    echo
}

# Main installation function
main() {
    echo "🚀 Claude Code Cluster - Flexible Installation Script v${SCRIPT_VERSION}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    # Set defaults if not provided
    INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
    VENV_DIR="${VENV_DIR:-$DEFAULT_VENV_DIR}"
    
    # Show configuration
    info "Configuration:"
    info "  Install Directory: $INSTALL_DIR"
    info "  Virtual Environment: $VENV_DIR"
    info "  Use sudo: $USE_SUDO"
    info "  Force install: $FORCE_INSTALL"
    info "  Skip dependencies: $SKIP_DEPS"
    echo
    
    if [ "$INTERACTIVE" = true ]; then
        if ! confirm "Continue with installation?" "y"; then
            echo "Installation cancelled."
            exit 0
        fi
    fi
    
    # Run installation steps
    detect_os
    install_dependencies
    setup_repository
    set_permissions
    setup_python_env
    install_python_dependencies
    create_env_file
    create_directories
    setup_shell_integration
    health_check
    show_completion
}

# Handle script interruption
trap 'error "Installation interrupted"; show_errors; exit 1' INT TERM

# Parse arguments and run
parse_args "$@"
main
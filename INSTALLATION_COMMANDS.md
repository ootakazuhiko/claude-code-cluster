# Installation Commands - Safe & Simple

## Quick Commands (Recommended)

### Uninstall Old System
```bash
curl -sSL https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/scripts/safe-uninstall.sh | bash
```

### Install New System (UV Version - Recommended)
```bash
curl -sSL https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/scripts/install-github-uv.sh | bash
```

### Install New System (pip3 Version)
```bash
curl -sSL https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/scripts/install-github-simple.sh | bash
```

## Alternative Methods (If curl fails)

### Download and Run Locally

```bash
# Uninstall
wget https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/scripts/safe-uninstall.sh
chmod +x safe-uninstall.sh
./safe-uninstall.sh

# Install (UV version - recommended)
wget https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/scripts/install-github-uv.sh
chmod +x install-github-uv.sh
./install-github-uv.sh

# Install (pip3 version)
wget https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/scripts/install-github-simple.sh
chmod +x install-github-simple.sh
./install-github-simple.sh
```

### Clone Repository Method

```bash
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster

# Uninstall old system
./scripts/safe-uninstall.sh

# Install new system (UV version - recommended)
./scripts/install-github-uv.sh

# Or install pip3 version
./scripts/install-github-simple.sh
```

## Features of Safe Scripts

### safe-uninstall.sh
- English-only messages
- Printf-only (no echo compatibility issues)
- Automatic backup creation
- Preserves workspace data
- Robust error handling

### install-github-uv.sh (Recommended)
- English-only interface
- UV package manager (automatic installation)
- Virtual environment with uv venv
- UV management utilities included
- GitHub token validation
- Creates comprehensive management scripts

### install-github-simple.sh
- English-only interface
- pip3 dependency checking
- GitHub token validation
- Creates management scripts
- Environment configuration

## After Installation

```bash
# Reload environment
source ~/.bashrc

# Go to workers directory
cd ~/claude-workers

# Start all workers
./start-all-workers.sh

# Check status
./check-status.sh

# Test functionality
./test-worker.sh cc01

# For UV installations only:
# Enter UV virtual environment
./uv-manage.sh shell

# List UV packages
./uv-manage.sh list
```

## Troubleshooting

If you encounter "command not found" errors with curl method:
1. Use the wget method instead
2. Or clone the repository and run locally
3. Check your terminal encoding (should be UTF-8)

The safe scripts are designed to work in any environment with minimal dependencies.
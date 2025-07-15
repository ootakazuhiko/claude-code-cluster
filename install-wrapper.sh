#!/bin/bash

# Claude Code Cluster - Installation Wrapper
# Simplified installation with auto-detection and smart defaults

set -euo pipefail

# Detect if running as root and adjust accordingly
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Running as root. Installing for user installation..."
    INSTALL_USER="${SUDO_USER:-$USER}"
    INSTALL_HOME="$(getent passwd $INSTALL_USER | cut -d: -f6)"
    EXTRA_ARGS="--dir $INSTALL_HOME/claude-code-cluster"
else
    INSTALL_USER="$USER"
    INSTALL_HOME="$HOME"
    EXTRA_ARGS=""
    
    # Check if we can use sudo
    if ! sudo -n true 2>/dev/null; then
        echo "ℹ️  No sudo access detected. Installing in user mode..."
        EXTRA_ARGS="$EXTRA_ARGS --no-sudo"
    fi
fi

# Download the improved installer if needed
INSTALLER_PATH="./install-improved.sh"

if [ ! -f "$INSTALLER_PATH" ]; then
    echo "📥 Downloading installer..."
    curl -fsSL https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/install-improved.sh -o "$INSTALLER_PATH"
    chmod +x "$INSTALLER_PATH"
fi

# Run the installer with smart defaults
echo "🚀 Starting Claude Code Cluster installation..."
echo "   User: $INSTALL_USER"
echo "   Home: $INSTALL_HOME"
echo

# Execute installer
if [ "$EUID" -eq 0 ]; then
    # If root, run as the target user
    su - "$INSTALL_USER" -c "cd $(pwd) && $INSTALLER_PATH $EXTRA_ARGS $@"
else
    # Run directly
    "$INSTALLER_PATH" $EXTRA_ARGS "$@"
fi
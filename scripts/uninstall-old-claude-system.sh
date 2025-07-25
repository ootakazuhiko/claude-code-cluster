#!/bin/bash
# Complete uninstall script for old Claude Code Cluster system

set -e

printf "=== Old Claude Code Cluster System Uninstaller ===\n"
printf "This will remove ALL old system components.\n"
printf "Continue? (y/N): "
read -n 1 -r REPLY
printf "\n"

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    printf "Cancelled.\n"
    exit 1
fi

# Create backup directory
BACKUP_DIR="$HOME/claude-old-system-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
printf "\nBackup directory: $BACKUP_DIR\n"

# 1. Stop all old services
printf "\n1. Stopping old services...\n"

# Stop systemd services
for service in claude-router claude-cc01 claude-cc02 claude-cc03 claude-issue-monitor; do
    if systemctl --user is-active --quiet $service 2>/dev/null; then
        systemctl --user stop $service
        printf "   Stopped $service\n"
    fi
    if [ -f "$HOME/.config/systemd/user/$service.service" ]; then
        systemctl --user disable $service 2>/dev/null || true
        rm -f "$HOME/.config/systemd/user/$service.service"
        printf "   Removed $service.service\n"
    fi
done
systemctl --user daemon-reload 2>/dev/null || true

# Kill old tmux sessions
for session in cc01 cc02 cc03 manager router; do
    if tmux has-session -t $session 2>/dev/null; then
        tmux kill-session -t $session
        printf "   Killed tmux session: $session\n"
    fi
done

# Kill old processes
pkill -f "central-router.py" 2>/dev/null || true
pkill -f "webhook-server" 2>/dev/null || true
pkill -f "issue-monitor.py" 2>/dev/null || true
pkill -f "claude-agent" 2>/dev/null || true

# 2. Backup important data
printf "\n2. Backing up important data...\n"

# Backup workspaces
if [ -d "/home/claude-cluster/agents" ]; then
    for agent in cc01 cc02 cc03 manager; do
        if [ -d "/home/claude-cluster/agents/$agent/workspace" ]; then
            cp -r "/home/claude-cluster/agents/$agent/workspace" "$BACKUP_DIR/${agent}-workspace"
            printf "   Backed up $agent workspace\n"
        fi
    done
fi

# Backup config
if [ -d "/home/claude-cluster/config" ]; then
    cp -r "/home/claude-cluster/config" "$BACKUP_DIR/config"
    printf "   Backed up config\n"
fi

# Backup logs
if [ -d "/home/claude-cluster/shared/logs" ]; then
    cp -r "/home/claude-cluster/shared/logs" "$BACKUP_DIR/logs"
    printf "   Backed up logs\n"
fi

# 3. Remove old directories
printf "\n3. Removing old directories...\n"

# Remove main cluster directory
if [ -d "/home/claude-cluster" ]; then
    rm -rf /home/claude-cluster
    printf "   Removed /home/claude-cluster\n"
fi

# Remove agent directories in home
for dir in ~/claude-agent-* ~/claude-cc0* ~/cc01 ~/cc02 ~/cc03; do
    if [ -d "$dir" ] && [ "$dir" != "$HOME/claude-workers" ]; then
        rm -rf "$dir"
        printf "   Removed $dir\n"
    fi
done

# 4. Remove old scripts and commands
printf "\n4. Removing old commands...\n"

# Remove from /usr/local/bin
for cmd in claude-cluster my-tasks my-pr check-ci claude-agent; do
    if [ -L "/usr/local/bin/$cmd" ] || [ -f "/usr/local/bin/$cmd" ]; then
        sudo rm -f "/usr/local/bin/$cmd"
        printf "   Removed /usr/local/bin/$cmd\n"
    fi
done

# Remove from ~/bin
if [ -d "$HOME/bin" ]; then
    for cmd in my-tasks my-pr check-ci claude-agent; do
        if [ -f "$HOME/bin/$cmd" ]; then
            rm -f "$HOME/bin/$cmd"
            printf "   Removed ~/bin/$cmd\n"
        fi
    done
fi

# 5. Clean environment variables
printf "\n5. Cleaning environment variables...\n"

# Backup bashrc
cp ~/.bashrc "$BACKUP_DIR/.bashrc.backup" 2>/dev/null || true

# Remove old Claude cluster lines
sed -i '/# Claude Code Cluster$/d' ~/.bashrc 2>/dev/null || true
sed -i '/# Claude Code Cluster (old)/d' ~/.bashrc 2>/dev/null || true
sed -i '/export CLUSTER_HOME=/d' ~/.bashrc 2>/dev/null || true
sed -i '/export WEBHOOK_PORT=/d' ~/.bashrc 2>/dev/null || true
sed -i '/export CLAUDE_AGENT_ID=/d' ~/.bashrc 2>/dev/null || true
sed -i '/export AGENT_NAME=/d' ~/.bashrc 2>/dev/null || true
sed -i '/claude-cluster\/scripts/d' ~/.bashrc 2>/dev/null || true
sed -i '/alias my-tasks=/d' ~/.bashrc 2>/dev/null || true
sed -i '/alias my-pr=/d' ~/.bashrc 2>/dev/null || true
sed -i '/alias check-ci=/d' ~/.bashrc 2>/dev/null || true

printf "   Cleaned ~/.bashrc\n"

# 6. Clean crontab
printf "\n6. Cleaning crontab...\n"
crontab -l 2>/dev/null | grep -v "claude-cluster" | grep -v "claude-agent" | crontab - 2>/dev/null || true
printf "   Cleaned crontab\n"

# 7. Remove Python packages (old system)
printf "\n7. Cleaning Python packages...\n"
pip3 uninstall -y claude-agent 2>/dev/null || true
pip3 uninstall -y claude-cluster 2>/dev/null || true

# 8. Final cleanup
printf "\n8. Final cleanup...\n"

# Remove .claude directories (old format)
if [ -d "$HOME/.claude-agent" ]; then
    rm -rf "$HOME/.claude-agent"
    printf "   Removed ~/.claude-agent\n"
fi

# Remove old hooks
for agent_dir in /home/claude-cluster/agents/*/; do
    if [ -d "$agent_dir/.claude/hooks" ]; then
        rm -rf "$agent_dir/.claude/hooks"
    fi
done

printf "\n=== Uninstall Complete ===\n"
printf "\nBackup saved to: $BACKUP_DIR\n"
printf "\nRemoved:\n"
printf "  - Old systemd services\n"
printf "  - Old tmux sessions\n"
printf "  - /home/claude-cluster directory\n"
printf "  - Old command aliases (my-tasks, my-pr, check-ci)\n"
printf "  - Old environment variables (CLAUDE_AGENT_ID, etc.)\n"
printf "  - Old Python packages\n"
printf "\nIMPORTANT: Restart your terminal or run:\n"
printf "  source ~/.bashrc\n"
printf "\nThe new Claude Code Cluster system in ~/claude-workers is preserved.\n"
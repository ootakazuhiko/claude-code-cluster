#!/bin/bash
# Safe uninstall for Claude Code Cluster

set -e

printf "=== Claude Code Cluster Uninstall ===\n"
printf "This will remove old system components.\n"
printf "Continue? (y/N): "
read -n 1 -r REPLY
printf "\n"

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    printf "Cancelled.\n"
    exit 1
fi

# Stop services
printf "\nStopping services...\n"
command -v claude-cluster >/dev/null && claude-cluster stop 2>/dev/null || true

# Stop systemd services
for service in claude-router claude-cc01 claude-cc02 claude-cc03 claude-issue-monitor; do
    systemctl --user is-active --quiet $service 2>/dev/null && {
        systemctl --user stop $service
        printf "Stopped $service\n"
    } || true
done

# Kill tmux sessions  
for session in cc01 cc02 cc03 manager router; do
    tmux has-session -t $session 2>/dev/null && {
        tmux kill-session -t $session
        printf "Killed session $session\n"
    } || true
done

# Kill processes
pkill -f "central-router.py" 2>/dev/null || true
pkill -f "webhook-server" 2>/dev/null || true
pkill -f "issue-monitor.py" 2>/dev/null || true

# Backup data
BACKUP_DIR="$HOME/claude-cluster-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
printf "\nBacking up to: $BACKUP_DIR\n"

[ -d "/home/claude-cluster/agents" ] && {
    for agent in cc01 cc02 cc03 manager; do
        [ -d "/home/claude-cluster/agents/$agent/workspace" ] && {
            cp -r "/home/claude-cluster/agents/$agent/workspace" "$BACKUP_DIR/${agent}-workspace"
            printf "Backed up $agent workspace\n"
        }
    done
}

[ -d "/home/claude-cluster/config" ] && {
    cp -r "/home/claude-cluster/config" "$BACKUP_DIR/config"
    printf "Backed up config\n"
}

[ -d "/home/claude-cluster/shared/logs" ] && {
    cp -r "/home/claude-cluster/shared/logs" "$BACKUP_DIR/logs"
    printf "Backed up logs\n"
}

# Remove systemd services
printf "\nRemoving systemd services...\n"
for service in claude-router claude-cc01 claude-cc02 claude-cc03 claude-issue-monitor; do
    [ -f "$HOME/.config/systemd/user/$service.service" ] && {
        systemctl --user disable $service 2>/dev/null || true
        rm -f "$HOME/.config/systemd/user/$service.service"
        printf "Removed $service\n"
    }
done
systemctl --user daemon-reload 2>/dev/null || true

# Remove global commands
[ -L "/usr/local/bin/claude-cluster" ] && {
    sudo rm -f /usr/local/bin/claude-cluster
    printf "Removed global claude-cluster command\n"
}

# Clean directories
printf "\nCleaning directories...\n"
[ -d "/home/claude-cluster" ] && {
    rm -rf /home/claude-cluster/scripts/management/central-router.py 2>/dev/null || true
    rm -rf /home/claude-cluster/scripts/github-integration/ 2>/dev/null || true
    rm -rf /home/claude-cluster/hooks/ 2>/dev/null || true
    
    for agent in cc01 cc02 cc03 manager; do
        rm -rf "/home/claude-cluster/agents/$agent/.claude/hooks" 2>/dev/null || true
    done
    printf "Cleaned system files (workspaces preserved)\n"
}

# Clean environment
printf "Cleaning environment variables...\n"
cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d) 2>/dev/null || true
sed -i '/# Claude Code Cluster$/d' ~/.bashrc 2>/dev/null || true
sed -i '/export CLUSTER_HOME=/d' ~/.bashrc 2>/dev/null || true
sed -i '/export WEBHOOK_PORT=/d' ~/.bashrc 2>/dev/null || true
sed -i '/export AGENT_NAME=/d' ~/.bashrc 2>/dev/null || true
sed -i '/claude-cluster\/scripts/d' ~/.bashrc 2>/dev/null || true

printf "\n=== Uninstall Complete ===\n"
printf "Backup location: $BACKUP_DIR\n"
printf "Please restart terminal for environment changes.\n"
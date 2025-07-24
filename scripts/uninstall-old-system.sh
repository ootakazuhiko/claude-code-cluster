#!/bin/bash
# Uninstall script for old Claude Code Cluster system
# This removes the HTTP webhook-based system components

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

printf "${BLUE}=== Claude Code Cluster 旧システム アンインストール ===${NC}\n"
printf "\n"
printf "${YELLOW}警告: このスクリプトは旧システムのコンポーネントを削除します。${NC}\n"
printf "${YELLOW}作業データは保持されますが、念のためバックアップを推奨します。${NC}\n"
printf "\n"

read -p "続行しますか？ (y/N): " -n 1 -r
printf "\n"

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    printf "キャンセルしました。\n"
    exit 1
fi

# Step 1: Stop all services
printf "\n${BLUE}Step 1: サービスの停止${NC}\n"

# Stop claude-cluster command if exists
if command -v claude-cluster &> /dev/null; then
    printf "Claude Clusterを停止中...\n"
    claude-cluster stop 2>/dev/null || true
fi

# Stop systemd services
printf "systemdサービスを停止中...\n"
for service in claude-router claude-cc01 claude-cc02 claude-cc03 claude-issue-monitor; do
    if systemctl --user is-active --quiet $service 2>/dev/null; then
        systemctl --user stop $service
        printf "  ${GREEN}✓${NC} $service stopped\n"
    fi
done

# Kill tmux sessions
printf "tmuxセッションを終了中...\n"
for session in cc01 cc02 cc03 manager router; do
    if tmux has-session -t $session 2>/dev/null; then
        tmux kill-session -t $session
        printf "  ${GREEN}✓${NC} $session killed\n"
    fi
done

# Kill any remaining processes
printf "残存プロセスを終了中...\n"
pkill -f "central-router.py" 2>/dev/null || true
pkill -f "webhook-server" 2>/dev/null || true
pkill -f "issue-monitor.py" 2>/dev/null || true

# Step 2: Backup important data
printf "\n${BLUE}Step 2: データのバックアップ${NC}\n"

BACKUP_DIR="$HOME/claude-cluster-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup workspaces if they exist
if [ -d "/home/claude-cluster/agents" ]; then
    printf "ワークスペースをバックアップ中...\n"
    for agent in cc01 cc02 cc03 manager; do
        if [ -d "/home/claude-cluster/agents/$agent/workspace" ]; then
            cp -r "/home/claude-cluster/agents/$agent/workspace" "$BACKUP_DIR/${agent}-workspace"
            printf "  ${GREEN}✓${NC} $agent workspace backed up\n"
        fi
    done
fi

# Backup configs
if [ -d "/home/claude-cluster/config" ]; then
    printf "設定ファイルをバックアップ中...\n"
    cp -r "/home/claude-cluster/config" "$BACKUP_DIR/config"
    printf "  ${GREEN}✓${NC} Config backed up\n"
fi

# Backup logs
if [ -d "/home/claude-cluster/shared/logs" ]; then
    printf "ログをバックアップ中...\n"
    cp -r "/home/claude-cluster/shared/logs" "$BACKUP_DIR/logs"
    printf "  ${GREEN}✓${NC} Logs backed up\n"
fi

printf "${GREEN}バックアップ完了: $BACKUP_DIR${NC}\n"

# Step 3: Remove systemd services
printf "\n${BLUE}Step 3: systemdサービスの削除${NC}\n"

for service in claude-router claude-cc01 claude-cc02 claude-cc03 claude-issue-monitor; do
    if [ -f "$HOME/.config/systemd/user/$service.service" ]; then
        systemctl --user disable $service 2>/dev/null || true
        rm -f "$HOME/.config/systemd/user/$service.service"
        printf "  ${GREEN}✓${NC} $service removed\n"
    fi
done

systemctl --user daemon-reload

# Step 4: Remove global commands
printf "\n${BLUE}Step 4: グローバルコマンドの削除${NC}\n"

if [ -L "/usr/local/bin/claude-cluster" ]; then
    sudo rm -f /usr/local/bin/claude-cluster
    printf "  ${GREEN}✓${NC} /usr/local/bin/claude-cluster removed\n"
fi

# Step 5: Clean up directories
printf "\n${BLUE}Step 5: ディレクトリのクリーンアップ${NC}\n"

# Remove specific components but keep workspaces
if [ -d "/home/claude-cluster" ]; then
    printf "旧システムファイルを削除中...\n"
    
    # Remove scripts
    rm -rf /home/claude-cluster/scripts/management/central-router.py 2>/dev/null || true
    rm -rf /home/claude-cluster/scripts/github-integration/ 2>/dev/null || true
    
    # Remove hooks
    rm -rf /home/claude-cluster/hooks/ 2>/dev/null || true
    
    # Remove agent hooks but keep workspaces
    for agent in cc01 cc02 cc03 manager; do
        rm -rf "/home/claude-cluster/agents/$agent/.claude/hooks" 2>/dev/null || true
    done
    
    printf "  ${GREEN}✓${NC} System files removed (workspaces preserved)\n"
fi

# Step 6: Clean environment variables
printf "\n${BLUE}Step 6: 環境変数のクリーンアップ${NC}\n"

# Create backup of bashrc
cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d)

# Remove old environment variables
sed -i '/# Claude Code Cluster$/d' ~/.bashrc
sed -i '/export CLUSTER_HOME=/d' ~/.bashrc
sed -i '/export WEBHOOK_PORT=/d' ~/.bashrc
sed -i '/export AGENT_NAME=/d' ~/.bashrc
sed -i '/claude-cluster\/scripts/d' ~/.bashrc

printf "  ${GREEN}✓${NC} Environment variables cleaned\n"

# Step 7: Check ports
printf "\n${BLUE}Step 7: ポート解放の確認${NC}\n"

PORTS_IN_USE=false
for port in 8888 8881 8882 8883; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        printf "  ${YELLOW}!${NC} Port $port is still in use\n"
        PORTS_IN_USE=true
    else
        printf "  ${GREEN}✓${NC} Port $port is free\n"
    fi
done

if [ "$PORTS_IN_USE" = true ]; then
    printf "${YELLOW}警告: 一部のポートがまだ使用中です。再起動を推奨します。${NC}\n"
fi

# Step 8: Summary
printf "\n${BLUE}=== アンインストール完了 ===${NC}\n"
printf "\n"
printf "${GREEN}削除された項目:${NC}\n"
printf "  - systemdサービス\n"
printf "  - グローバルコマンド (/usr/local/bin/claude-cluster)\n"
printf "  - Webhook/Routerスクリプト\n"
printf "  - Hookシステム\n"
printf "  - 環境変数設定\n"
printf "\n"
printf "${YELLOW}保持された項目:${NC}\n"
printf "  - ワークスペースデータ\n"
printf "  - バックアップ: $BACKUP_DIR\n"
printf "\n"
printf "${BLUE}次のステップ:${NC}\n"
printf "1. 新しいターミナルを開いて環境をリロード\n"
printf "2. 新システムの導入ガイドに従って設定\n"
printf "\n"
printf "${GREEN}旧システムのアンインストールが完了しました。${NC}\n"
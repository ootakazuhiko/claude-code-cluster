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

echo -e "${BLUE}=== Claude Code Cluster 旧システム アンインストール ===${NC}"
echo
echo -e "${YELLOW}警告: このスクリプトは旧システムのコンポーネントを削除します。${NC}"
echo -e "${YELLOW}作業データは保持されますが、念のためバックアップを推奨します。${NC}"
echo

read -p "続行しますか？ (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "キャンセルしました。"
    exit 1
fi

# Step 1: Stop all services
echo -e "\n${BLUE}Step 1: サービスの停止${NC}"

# Stop claude-cluster command if exists
if command -v claude-cluster &> /dev/null; then
    echo "Claude Clusterを停止中..."
    claude-cluster stop 2>/dev/null || true
fi

# Stop systemd services
echo "systemdサービスを停止中..."
for service in claude-router claude-cc01 claude-cc02 claude-cc03 claude-issue-monitor; do
    if systemctl --user is-active --quiet $service 2>/dev/null; then
        systemctl --user stop $service
        echo -e "  ${GREEN}✓${NC} $service stopped"
    fi
done

# Kill tmux sessions
echo "tmuxセッションを終了中..."
for session in cc01 cc02 cc03 manager router; do
    if tmux has-session -t $session 2>/dev/null; then
        tmux kill-session -t $session
        echo -e "  ${GREEN}✓${NC} $session killed"
    fi
done

# Kill any remaining processes
echo "残存プロセスを終了中..."
pkill -f "central-router.py" 2>/dev/null || true
pkill -f "webhook-server" 2>/dev/null || true
pkill -f "issue-monitor.py" 2>/dev/null || true

# Step 2: Backup important data
echo -e "\n${BLUE}Step 2: データのバックアップ${NC}"

BACKUP_DIR="$HOME/claude-cluster-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup workspaces if they exist
if [ -d "/home/claude-cluster/agents" ]; then
    echo "ワークスペースをバックアップ中..."
    for agent in cc01 cc02 cc03 manager; do
        if [ -d "/home/claude-cluster/agents/$agent/workspace" ]; then
            cp -r "/home/claude-cluster/agents/$agent/workspace" "$BACKUP_DIR/${agent}-workspace"
            echo -e "  ${GREEN}✓${NC} $agent workspace backed up"
        fi
    done
fi

# Backup configs
if [ -d "/home/claude-cluster/config" ]; then
    echo "設定ファイルをバックアップ中..."
    cp -r "/home/claude-cluster/config" "$BACKUP_DIR/config"
    echo -e "  ${GREEN}✓${NC} Config backed up"
fi

# Backup logs
if [ -d "/home/claude-cluster/shared/logs" ]; then
    echo "ログをバックアップ中..."
    cp -r "/home/claude-cluster/shared/logs" "$BACKUP_DIR/logs"
    echo -e "  ${GREEN}✓${NC} Logs backed up"
fi

echo -e "${GREEN}バックアップ完了: $BACKUP_DIR${NC}"

# Step 3: Remove systemd services
echo -e "\n${BLUE}Step 3: systemdサービスの削除${NC}"

for service in claude-router claude-cc01 claude-cc02 claude-cc03 claude-issue-monitor; do
    if [ -f "$HOME/.config/systemd/user/$service.service" ]; then
        systemctl --user disable $service 2>/dev/null || true
        rm -f "$HOME/.config/systemd/user/$service.service"
        echo -e "  ${GREEN}✓${NC} $service removed"
    fi
done

systemctl --user daemon-reload

# Step 4: Remove global commands
echo -e "\n${BLUE}Step 4: グローバルコマンドの削除${NC}"

if [ -L "/usr/local/bin/claude-cluster" ]; then
    sudo rm -f /usr/local/bin/claude-cluster
    echo -e "  ${GREEN}✓${NC} /usr/local/bin/claude-cluster removed"
fi

# Step 5: Clean up directories
echo -e "\n${BLUE}Step 5: ディレクトリのクリーンアップ${NC}"

# Remove specific components but keep workspaces
if [ -d "/home/claude-cluster" ]; then
    echo "旧システムファイルを削除中..."
    
    # Remove scripts
    rm -rf /home/claude-cluster/scripts/management/central-router.py 2>/dev/null || true
    rm -rf /home/claude-cluster/scripts/github-integration/ 2>/dev/null || true
    
    # Remove hooks
    rm -rf /home/claude-cluster/hooks/ 2>/dev/null || true
    
    # Remove agent hooks but keep workspaces
    for agent in cc01 cc02 cc03 manager; do
        rm -rf "/home/claude-cluster/agents/$agent/.claude/hooks" 2>/dev/null || true
    done
    
    echo -e "  ${GREEN}✓${NC} System files removed (workspaces preserved)"
fi

# Step 6: Clean environment variables
echo -e "\n${BLUE}Step 6: 環境変数のクリーンアップ${NC}"

# Create backup of bashrc
cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d)

# Remove old environment variables
sed -i '/# Claude Code Cluster$/d' ~/.bashrc
sed -i '/export CLUSTER_HOME=/d' ~/.bashrc
sed -i '/export WEBHOOK_PORT=/d' ~/.bashrc
sed -i '/export AGENT_NAME=/d' ~/.bashrc
sed -i '/claude-cluster\/scripts/d' ~/.bashrc

echo -e "  ${GREEN}✓${NC} Environment variables cleaned"

# Step 7: Check ports
echo -e "\n${BLUE}Step 7: ポート解放の確認${NC}"

PORTS_IN_USE=false
for port in 8888 8881 8882 8883; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo -e "  ${YELLOW}!${NC} Port $port is still in use"
        PORTS_IN_USE=true
    else
        echo -e "  ${GREEN}✓${NC} Port $port is free"
    fi
done

if [ "$PORTS_IN_USE" = true ]; then
    echo -e "${YELLOW}警告: 一部のポートがまだ使用中です。再起動を推奨します。${NC}"
fi

# Step 8: Summary
echo -e "\n${BLUE}=== アンインストール完了 ===${NC}"
echo
echo -e "${GREEN}削除された項目:${NC}"
echo "  - systemdサービス"
echo "  - グローバルコマンド (/usr/local/bin/claude-cluster)"
echo "  - Webhook/Routerスクリプト"
echo "  - Hookシステム"
echo "  - 環境変数設定"
echo
echo -e "${YELLOW}保持された項目:${NC}"
echo "  - ワークスペースデータ"
echo "  - バックアップ: $BACKUP_DIR"
echo
echo -e "${BLUE}次のステップ:${NC}"
echo "1. 新しいターミナルを開いて環境をリロード"
echo "2. 新システムの導入ガイドに従って設定"
echo
echo -e "${GREEN}旧システムのアンインストールが完了しました。${NC}"
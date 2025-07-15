# Claude Code Cluster - 本番環境クイックスタート

## 🚀 10分で本番環境を構築

### 前提条件
- Ubuntu 20.04+ サーバー
- 4GB RAM以上
- sudoアクセス権限
- GitHub APIアクセス

## ⚡ 自動インストールスクリプト

### 1. ワンライナーセットアップ
```bash
curl -sSL https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/install.sh | bash
```

### 2. 手動セットアップ（推奨）
```bash
# 1. 必要なパッケージのインストール
sudo apt update && sudo apt install -y python3.11 python3.11-pip git curl

# 2. GitHub CLI インストール
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
sudo apt update && sudo apt install gh

# 3. Claude Code Cluster のクローン
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster

# 4. 権限設定
chmod +x *.sh hooks/*.py scripts/*.sh

# 5. 環境設定
cp .env.example .env
```

### 3. 認証設定
```bash
# GitHub認証
gh auth login

# Claude API キー設定
read -s -p "Claude API Key: " CLAUDE_API_KEY
echo "export CLAUDE_API_KEY='$CLAUDE_API_KEY'" >> ~/.bashrc
source ~/.bashrc
```

### 4. エージェント起動
```bash
# 単一エージェント起動
./start-agent-sonnet.sh CC01

# 複数エージェント起動
./hooks/start-agent-loop.sh start all
```

## 🔧 設定ファイルテンプレート

### .env ファイル
```bash
# API設定
CLAUDE_API_KEY=your-claude-api-key
GITHUB_TOKEN=your-github-token

# システム設定
CLAUDE_MODEL=claude-3-5-sonnet-20241022
AGENT_LOG_LEVEL=INFO
LOG_RETENTION_DAYS=30

# 本番環境設定
PRODUCTION_MODE=true
MONITORING_ENABLED=true
BACKUP_ENABLED=true
```

### systemd サービス設定
```bash
# 自動サービス作成
sudo tee /etc/systemd/system/claude-agent@.service << EOF
[Unit]
Description=Claude Code Agent %i
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/claude-code-cluster
ExecStart=/home/ubuntu/claude-code-cluster/start-agent-sonnet.sh %i
Restart=always
RestartSec=10
Environment=PYTHONPATH=/home/ubuntu/claude-code-cluster

[Install]
WantedBy=multi-user.target
EOF

# サービス有効化
sudo systemctl daemon-reload
sudo systemctl enable claude-agent@CC01
sudo systemctl start claude-agent@CC01
sudo systemctl enable claude-agent@CC02
sudo systemctl start claude-agent@CC02
sudo systemctl enable claude-agent@CC03
sudo systemctl start claude-agent@CC03
```

## 📊 監視とヘルスチェック

### 基本的な監視
```bash
# エージェント状態確認
./hooks/start-agent-loop.sh status all

# ログの確認
python3 hooks/view-command-logs.py --stats

# システムリソース確認
htop
```

### 自動ヘルスチェック
```bash
# ヘルスチェックスクリプト
tee /home/ubuntu/health-check.sh << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/claude-health-check.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# エージェント状態確認
if ! pgrep -f "python3.*universal-agent" > /dev/null; then
    echo "$DATE: CRITICAL - No agents running" >> $LOG_FILE
    systemctl restart claude-agent@CC01
    systemctl restart claude-agent@CC02
    systemctl restart claude-agent@CC03
else
    echo "$DATE: OK - Agents running" >> $LOG_FILE
fi

# ディスク使用量確認
DISK_USAGE=$(df /tmp | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "$DATE: WARNING - High disk usage: $DISK_USAGE%" >> $LOG_FILE
    # ログクリーンアップ
    find /tmp/claude-code-logs -name "*.log" -mtime +7 -delete
fi
EOF

chmod +x /home/ubuntu/health-check.sh

# cron設定
(crontab -l 2>/dev/null; echo "*/5 * * * * /home/ubuntu/health-check.sh") | crontab -
```

## 🔐 セキュリティ設定

### 基本的なセキュリティ
```bash
# ファイアウォール設定
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 8000/tcp

# ログディレクトリの保護
chmod 700 /tmp/claude-code-logs/
chown -R ubuntu:ubuntu /tmp/claude-code-logs/

# API キーの保護
chmod 600 .env
```

### SSL/TLS設定（オプション）
```bash
# Let's Encrypt証明書
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.com

# nginx設定
sudo apt install nginx
sudo tee /etc/nginx/sites-available/claude-cluster << 'EOF'
server {
    listen 443 ssl;
    server_name your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/claude-cluster /etc/nginx/sites-enabled/
sudo systemctl reload nginx
```

## 📈 パフォーマンス最適化

### システム最適化
```bash
# カーネルパラメータ調整
sudo tee -a /etc/sysctl.conf << 'EOF'
# Claude Code Cluster最適化
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65535
vm.swappiness = 10
fs.file-max = 65535
EOF

sudo sysctl -p

# システムリミット調整
sudo tee -a /etc/security/limits.conf << 'EOF'
ubuntu soft nofile 65535
ubuntu hard nofile 65535
ubuntu soft nproc 65535
ubuntu hard nproc 65535
EOF
```

### エージェント最適化
```bash
# 環境変数設定
export PYTHONUNBUFFERED=1
export PYTHONOPTIMIZE=1
export AGENT_CONCURRENCY=4
export AGENT_MEMORY_LIMIT=4G
```

## 🔄 バックアップとリストア

### 自動バックアップ
```bash
# バックアップスクリプト
tee /home/ubuntu/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/claude-backup.log"

mkdir -p $BACKUP_DIR

# 設定ファイルのバックアップ
tar -czf $BACKUP_DIR/config_$DATE.tar.gz \
    /home/ubuntu/claude-code-cluster/.env \
    /home/ubuntu/claude-code-cluster/agent-config/ \
    /home/ubuntu/claude-code-cluster/hooks/claude-code-settings.json

# ログのバックアップ
tar -czf $BACKUP_DIR/logs_$DATE.tar.gz /tmp/claude-code-logs/

# 古いバックアップの削除
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "$(date): Backup completed - $DATE" >> $LOG_FILE
EOF

chmod +x /home/ubuntu/backup.sh

# 日次バックアップ設定
(crontab -l 2>/dev/null; echo "0 2 * * * /home/ubuntu/backup.sh") | crontab -
```

## 🚨 トラブルシューティング

### よくある問題と解決策

#### エージェントが起動しない
```bash
# 1. ログの確認
journalctl -u claude-agent@CC01 -f

# 2. 権限確認
ls -la /home/ubuntu/claude-code-cluster/

# 3. 依存関係の確認
python3 -c "import sys; print(sys.version)"
which python3
```

#### パフォーマンス問題
```bash
# 1. リソース使用量確認
htop
iotop
nethogs

# 2. ログサイズ確認
du -sh /tmp/claude-code-logs/

# 3. プロセス数確認
ps aux | grep python3 | wc -l
```

#### メモリリーク
```bash
# 1. メモリ使用量監視
while true; do
    ps aux | grep python3 | grep universal-agent | awk '{print $6}' | sort -n | tail -1
    sleep 60
done

# 2. 定期再起動（必要に応じて）
sudo systemctl restart claude-agent@CC01
```

## 📞 緊急時の対応

### 緊急停止
```bash
# 全エージェント停止
./hooks/start-agent-loop.sh stop all
sudo systemctl stop claude-agent@CC01
sudo systemctl stop claude-agent@CC02
sudo systemctl stop claude-agent@CC03
```

### 緊急復旧
```bash
# 1. 設定の確認
source .env
echo $CLAUDE_API_KEY

# 2. 最小限の起動
./start-agent-sonnet.sh CC01

# 3. 段階的な復旧
./hooks/start-agent-loop.sh start CC01
sleep 30
./hooks/start-agent-loop.sh start CC02
sleep 30
./hooks/start-agent-loop.sh start CC03
```

## 📊 運用メトリクス

### KPI監視
```bash
# 日次レポート生成
tee /home/ubuntu/daily-report.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y-%m-%d)
REPORT_FILE="/home/ubuntu/reports/daily_$DATE.txt"

mkdir -p /home/ubuntu/reports

echo "Claude Code Cluster Daily Report - $DATE" > $REPORT_FILE
echo "=============================================" >> $REPORT_FILE

# エージェント統計
python3 /home/ubuntu/claude-code-cluster/hooks/view-command-logs.py --stats >> $REPORT_FILE

# システムリソース
echo -e "\nSystem Resources:" >> $REPORT_FILE
free -h >> $REPORT_FILE
df -h >> $REPORT_FILE

# プロセス情報
echo -e "\nActive Processes:" >> $REPORT_FILE
ps aux | grep python3 | grep -v grep >> $REPORT_FILE

# ログファイルサイズ
echo -e "\nLog Directory Size:" >> $REPORT_FILE
du -sh /tmp/claude-code-logs/ >> $REPORT_FILE
EOF

chmod +x /home/ubuntu/daily-report.sh

# 日次レポート実行
(crontab -l 2>/dev/null; echo "0 1 * * * /home/ubuntu/daily-report.sh") | crontab -
```

---

🎯 **10分で本番環境が構築できます！**

🔧 **カスタマイズ**: 必要に応じて設定を調整してください

📈 **スケーリング**: 需要に応じてエージェントを追加できます

🚨 **サポート**: 問題が発生した場合は、GitHubのIssuesで報告してください
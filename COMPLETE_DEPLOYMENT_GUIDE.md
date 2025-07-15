# Claude Code Cluster - 完全導入手順書

## 🚀 概要

claude-code-clusterは、GitHubリポジトリでの自動化されたコード開発とメンテナンスを実現する分散エージェントシステムです。このガイドでは、フル機能のエージェント・サーバシステムの完全な導入手順を説明します。

## 📋 システム構成

### アーキテクチャ概要
```
┌─────────────────────────────────────────────────────────────┐
│                    Claude Code Cluster                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Agent CC01  │  │ Agent CC02  │  │ Agent CC03  │          │
│  │ (Backend)   │  │ (Database)  │  │ (Frontend)  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Agent CC04  │  │ Agent CC05  │  │ Manager     │          │
│  │ (DevOps)    │  │ (Security)  │  │ (Opus)      │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Command     │  │ Monitoring  │  │ GitHub      │          │
│  │ Logger      │  │ System      │  │ Integration │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

### コンポーネント
- **Agent Sonnet System**: 専門化されたエージェント（CC01-CC05）
- **Universal Agent Auto-Loop**: 自動タスク処理システム
- **Command Logging System**: 包括的なコマンド記録
- **Monitoring & Metrics**: パフォーマンス監視
- **GitHub Integration**: リポジトリ連携

## 📋 システム要件

### 最小システム要件
- **OS**: Linux (Ubuntu 20.04+ 推奨), macOS 10.15+, Windows 10+ (WSL2)
- **CPU**: 4コア以上
- **メモリ**: 16GB以上
- **ストレージ**: 500GB以上
- **ネットワーク**: 安定したインターネット接続

### 推奨システム要件
- **CPU**: 8コア以上
- **メモリ**: 32GB以上
- **ストレージ**: 1TB SSD
- **ネットワーク**: ギガビットイーサネット

### 必要なソフトウェア
- **Python**: 3.11以上
- **Node.js**: 20 LTS以上
- **Docker**: 20.10以上
- **Git**: 2.30以上
- **GitHub CLI**: 2.0以上

## 🔧 事前準備

### 1. 基本環境のセットアップ

#### Ubuntu/Debian
```bash
# システムアップデート
sudo apt update && sudo apt upgrade -y

# 必要なパッケージのインストール
sudo apt install -y python3.11 python3.11-pip python3.11-venv nodejs npm git curl wget

# GitHub CLI のインストール
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh

# Docker のインストール
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

#### macOS
```bash
# Homebrew のインストール (未インストールの場合)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 必要なパッケージのインストール
brew install python@3.11 node@20 git gh docker
```

### 2. 認証設定

#### GitHub CLI認証
```bash
# GitHub認証
gh auth login

# 認証確認
gh auth status
```

#### Claude API設定
```bash
# Claude API キーの設定
export CLAUDE_API_KEY="your-claude-api-key"
echo 'export CLAUDE_API_KEY="your-claude-api-key"' >> ~/.bashrc
```

## 🚀 導入手順

### Phase 1: リポジトリのクローンと基本設定

```bash
# 1. リポジトリのクローン
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster

# 2. 権限設定
chmod +x *.sh
chmod +x hooks/*.py
chmod +x scripts/*.sh

# 3. 基本設定ファイルの作成
cp .env.example .env
```

### Phase 2: Python環境のセットアップ

```bash
# 1. Python仮想環境の作成
python3.11 -m venv venv
source venv/bin/activate

# 2. 依存関係のインストール
pip install -r requirements.txt

# 3. パッケージの確認
pip list
```

### Phase 3: エージェント設定

#### Agent Sonnet Systemの設定
```bash
# 1. エージェント設定の確認
ls -la agent-config/

# 2. デフォルト設定の適用
source agent-config/sonnet-default.sh

# 3. 各エージェントの設定確認
./start-agent-sonnet.sh CC01 --dry-run
./start-agent-sonnet.sh CC02 --dry-run
./start-agent-sonnet.sh CC03 --dry-run
```

#### Universal Agent Auto-Loop設定
```bash
# 1. 設定ファイルの確認
cat hooks/claude-code-settings.json

# 2. ログディレクトリの作成
mkdir -p /tmp/claude-code-logs

# 3. 設定の検証
python3 hooks/universal-agent-auto-loop-with-logging.py --help
```

### Phase 4: Command Logging Systemの設定

```bash
# 1. ログシステムの初期化
python3 hooks/command_logger.py

# 2. ログビューアーの確認
python3 hooks/view-command-logs.py --help

# 3. サンプルログの作成
./scripts/quick-test-command-logging.sh
```

### Phase 5: 監視システムの設定

```bash
# 1. 監視ディレクトリの作成
mkdir -p /tmp/agent-metrics

# 2. 監視スクリプトの実行権限付与
chmod +x hooks/start-agent-loop.sh

# 3. 監視システムの起動テスト
./hooks/start-agent-loop.sh status all
```

## 🎯 運用開始

### 1. 単一エージェントの起動

#### CC01 (Backend Specialist)の起動
```bash
# Sonnet設定での起動
./start-agent-sonnet.sh CC01

# Universal systemでの起動
python3 hooks/universal-agent-auto-loop-with-logging.py CC01 owner repo --max-iterations 10
```

#### CC02 (Database Specialist)の起動
```bash
# Sonnet設定での起動
./start-agent-sonnet.sh CC02

# Universal systemでの起動
python3 hooks/universal-agent-auto-loop-with-logging.py CC02 owner repo --specialization "Database Specialist"
```

#### CC03 (Frontend Specialist)の起動
```bash
# Sonnet設定での起動
./start-agent-sonnet.sh CC03

# Universal systemでの起動
python3 hooks/universal-agent-auto-loop-with-logging.py CC03 owner repo --labels frontend ui react
```

### 2. マルチエージェントシステムの起動

#### 全エージェントの一括起動
```bash
# 管理スクリプトを使用
./hooks/start-agent-loop.sh start all

# 個別起動
./hooks/start-agent-loop.sh start CC01 &
./hooks/start-agent-loop.sh start CC02 &
./hooks/start-agent-loop.sh start CC03 &
./hooks/start-agent-loop.sh start CC04 &
./hooks/start-agent-loop.sh start CC05 &
```

### 3. 監視とログの確認

#### リアルタイム監視
```bash
# 全エージェントの状況確認
./hooks/start-agent-loop.sh status all

# ログのリアルタイム表示
python3 hooks/view-command-logs.py --follow

# 特定エージェントの監視
python3 hooks/view-command-logs.py --agent CC01 --follow
```

#### パフォーマンス監視
```bash
# メトリクスの表示
./hooks/start-agent-loop.sh metrics all

# 統計情報の表示
python3 hooks/view-command-logs.py --stats

# ログのエクスポート
python3 hooks/view-command-logs.py --export /tmp/system-logs.json
```

## 🔧 設定カスタマイズ

### 1. エージェント設定のカスタマイズ

#### 専門化の設定
```bash
# CC04 (DevOps Specialist)の設定
python3 hooks/universal-agent-auto-loop-with-logging.py CC04 owner repo \
  --specialization "DevOps Specialist" \
  --labels devops ci-cd deployment \
  --keywords docker kubernetes pipeline \
  --cooldown 120

# CC05 (Security Specialist)の設定
python3 hooks/universal-agent-auto-loop-with-logging.py CC05 owner repo \
  --specialization "Security Specialist" \
  --labels security audit vulnerability \
  --keywords security auth encryption \
  --cooldown 90
```

### 2. 監視設定のカスタマイズ

#### claude-code-settings.jsonの編集
```json
{
  "agent_configurations": {
    "CC01": {
      "specialization": "Backend Specialist",
      "labels": ["claude-code-task", "backend", "cc01"],
      "priority_keywords": ["backend", "api", "database", "python", "fastapi"],
      "max_task_duration": 1800,
      "cooldown_time": 60
    }
  },
  "monitoring": {
    "enabled": true,
    "log_level": "INFO",
    "metrics_collection": true,
    "performance_tracking": true
  }
}
```

## 🐛 トラブルシューティング

### 1. 一般的な問題と解決策

#### エージェントが起動しない場合
```bash
# 1. 権限確認
ls -la *.sh hooks/*.py

# 2. Python環境確認
python3 --version
pip list | grep claude

# 3. 依存関係の再インストール
pip install --force-reinstall -r requirements.txt
```

#### GitHub認証エラー
```bash
# 1. 認証状態確認
gh auth status

# 2. 再認証
gh auth login --force

# 3. 権限確認
gh api user
```

#### ログが記録されない場合
```bash
# 1. ログディレクトリの確認
ls -la /tmp/claude-code-logs/

# 2. 権限設定
chmod 755 /tmp/claude-code-logs/
chown -R $USER:$USER /tmp/claude-code-logs/

# 3. ログシステムの再起動
python3 hooks/command_logger.py
```

### 2. パフォーマンスの最適化

#### メモリ使用量の最適化
```bash
# 1. システムリソースの確認
htop
free -h

# 2. エージェント数の調整
./hooks/start-agent-loop.sh stop all
./hooks/start-agent-loop.sh start CC01
./hooks/start-agent-loop.sh start CC02
```

#### 実行速度の最適化
```bash
# 1. クールダウン時間の調整
python3 hooks/universal-agent-auto-loop-with-logging.py CC01 owner repo --cooldown 30

# 2. 並列処理の最適化
export PYTHONPATH="/tmp/claude-code-cluster:$PYTHONPATH"
```

## 📊 運用管理

### 1. 日常的な運用タスク

#### システムヘルスチェック
```bash
# 1. 全エージェントの状態確認
./hooks/start-agent-loop.sh status all

# 2. ログの確認
python3 hooks/view-command-logs.py --stats

# 3. システムリソースの確認
df -h
free -h
```

#### 定期メンテナンス
```bash
# 1. ログのローテーション
find /tmp/claude-code-logs -name "*.log" -mtime +7 -delete

# 2. メトリクスのクリーンアップ
sqlite3 /tmp/claude-code-logs/agent-*/command_history.db "DELETE FROM command_history WHERE timestamp < date('now', '-30 days');"

# 3. システムアップデート
git pull origin main
pip install --upgrade -r requirements.txt
```

### 2. スケーリング

#### 水平スケーリング
```bash
# 1. 新しいエージェントの追加
python3 hooks/universal-agent-auto-loop-with-logging.py CC06 owner repo \
  --specialization "QA Specialist" \
  --labels qa testing \
  --keywords test quality automation

# 2. 負荷分散の確認
python3 hooks/view-command-logs.py --stats
```

#### 垂直スケーリング
```bash
# 1. リソース制限の調整
ulimit -n 4096
export PYTHONUNBUFFERED=1

# 2. 並行処理数の増加
export AGENT_CONCURRENCY=4
```

## 🔒 セキュリティ設定

### 1. 基本的なセキュリティ設定

#### API キーの安全な管理
```bash
# 1. 環境変数ファイルの作成
cat > .env << EOF
CLAUDE_API_KEY=your-api-key-here
GITHUB_TOKEN=your-github-token-here
EOF

# 2. 権限設定
chmod 600 .env

# 3. .gitignoreへの追加
echo ".env" >> .gitignore
```

#### ログのセキュリティ
```bash
# 1. ログディレクトリの権限設定
chmod 700 /tmp/claude-code-logs/

# 2. 機密情報のフィルタリング
export LOG_FILTER_PATTERNS="password,token,key,secret"
```

### 2. 本番環境での追加設定

#### ファイアウォール設定
```bash
# 1. UFWの設定 (Ubuntu)
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 8000/tcp  # API server
sudo ufw allow 3000/tcp  # Monitoring dashboard
```

#### SSL/TLS設定
```bash
# 1. 証明書の生成
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# 2. HTTPS設定
export HTTPS_CERT_PATH="/path/to/cert.pem"
export HTTPS_KEY_PATH="/path/to/key.pem"
```

## 📈 監視とアラート

### 1. 基本的な監視

#### システムメトリクス
```bash
# 1. CPU使用率の監視
top -p $(pgrep -f "python3.*universal-agent")

# 2. メモリ使用量の監視
ps aux | grep python3 | grep universal-agent

# 3. ディスク使用量の監視
du -sh /tmp/claude-code-logs/
```

#### アプリケーションメトリクス
```bash
# 1. エージェント統計の表示
python3 hooks/view-command-logs.py --stats

# 2. 成功率の監視
python3 hooks/view-command-logs.py --agent CC01 --stats | grep "Success"

# 3. 応答時間の監視
python3 hooks/view-command-logs.py --type GH_API --stats
```

### 2. アラート設定

#### 簡単なアラート
```bash
# 1. エージェント停止の検知
#!/bin/bash
if ! pgrep -f "python3.*universal-agent" > /dev/null; then
    echo "ALERT: Agent stopped at $(date)" | mail -s "Agent Alert" admin@example.com
fi

# 2. エラー率の監視
#!/bin/bash
ERROR_RATE=$(python3 hooks/view-command-logs.py --stats | grep "error_rate" | cut -d: -f2)
if (( $(echo "$ERROR_RATE > 0.1" | bc -l) )); then
    echo "ALERT: High error rate: $ERROR_RATE" | mail -s "High Error Rate" admin@example.com
fi
```

## 🎯 本番環境デプロイメント

### 1. 本番環境の準備

#### システム設定
```bash
# 1. システムユーザーの作成
sudo useradd -m -s /bin/bash claude-agent
sudo usermod -aG docker claude-agent

# 2. ディレクトリ構造の作成
sudo mkdir -p /opt/claude-code-cluster
sudo chown claude-agent:claude-agent /opt/claude-code-cluster

# 3. ログディレクトリの設定
sudo mkdir -p /var/log/claude-code-cluster
sudo chown claude-agent:claude-agent /var/log/claude-code-cluster
```

#### systemdサービスの設定
```bash
# 1. サービスファイルの作成
sudo cat > /etc/systemd/system/claude-agent-cc01.service << EOF
[Unit]
Description=Claude Code Agent CC01
After=network.target

[Service]
Type=simple
User=claude-agent
WorkingDirectory=/opt/claude-code-cluster
ExecStart=/opt/claude-code-cluster/venv/bin/python3 hooks/universal-agent-auto-loop-with-logging.py CC01 owner repo
Restart=always
RestartSec=10
Environment=PYTHONPATH=/opt/claude-code-cluster

[Install]
WantedBy=multi-user.target
EOF

# 2. サービスの有効化
sudo systemctl daemon-reload
sudo systemctl enable claude-agent-cc01
sudo systemctl start claude-agent-cc01
```

### 2. 高可用性設定

#### 複数サーバーでのデプロイ
```bash
# Server 1: CC01, CC02
./hooks/start-agent-loop.sh start CC01 &
./hooks/start-agent-loop.sh start CC02 &

# Server 2: CC03, CC04
./hooks/start-agent-loop.sh start CC03 &
./hooks/start-agent-loop.sh start CC04 &

# Server 3: CC05, Manager
./hooks/start-agent-loop.sh start CC05 &
```

#### 負荷分散設定
```bash
# 1. nginx設定
sudo cat > /etc/nginx/sites-available/claude-cluster << EOF
upstream claude_agents {
    server 127.0.0.1:8001;
    server 127.0.0.1:8002;
    server 127.0.0.1:8003;
}

server {
    listen 80;
    location / {
        proxy_pass http://claude_agents;
    }
}
EOF

# 2. 設定の有効化
sudo ln -s /etc/nginx/sites-available/claude-cluster /etc/nginx/sites-enabled/
sudo systemctl reload nginx
```

## 📚 追加リソース

### 1. ドキュメント
- [Quick Start Guide](./scripts/setup-command-logging-test.sh)
- [Command Logging System](./COMMAND_LOGGING_SETUP_GUIDE.md)
- [Agent Sonnet Documentation](./AGENT_SONNET_SYSTEM_DOCUMENTATION.md)

### 2. サポートとコミュニティ
- **GitHub Issues**: https://github.com/ootakazuhiko/claude-code-cluster/issues
- **Discussions**: https://github.com/ootakazuhiko/claude-code-cluster/discussions

### 3. 開発者向けリソース
- **API Documentation**: `/docs/api/`
- **Contributing Guide**: `/CONTRIBUTING.md`
- **Development Setup**: `/docs/development/`

## 🔄 アップデート手順

### 1. 定期アップデート
```bash
# 1. バックアップの作成
tar -czf claude-cluster-backup-$(date +%Y%m%d).tar.gz /opt/claude-code-cluster

# 2. 新しいバージョンの取得
cd /opt/claude-code-cluster
git pull origin main

# 3. 依存関係のアップデート
pip install --upgrade -r requirements.txt

# 4. サービスの再起動
sudo systemctl restart claude-agent-cc01
sudo systemctl restart claude-agent-cc02
sudo systemctl restart claude-agent-cc03
```

### 2. 緊急アップデート
```bash
# 1. 全エージェントの停止
./hooks/start-agent-loop.sh stop all

# 2. 高速アップデート
git fetch origin main
git reset --hard origin/main

# 3. 即座の再起動
./hooks/start-agent-loop.sh start all
```

---

🚀 **このガイドにより、claude-code-clusterの完全な導入と運用が可能になります。**

📧 **サポート**: 問題が発生した場合は、GitHubのIssuesで報告してください。

🔧 **カスタマイズ**: 特定のニーズに合わせて設定をカスタマイズできます。

🎯 **目標**: 高品質で効率的な自動化されたコード開発環境の実現
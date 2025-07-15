# Claude Code Cluster - 詳細インストール手順書

## 🎯 対象プロジェクト：ITDO_ERP2

このガイドは、ITDO_ERP2プロジェクトでclaude-code-clusterを使用するための詳細な手順を提供します。

## 📋 前提条件

### 必要なソフトウェア
- Python 3.11以上
- Git 2.30以上
- GitHub CLI 2.0以上
- Podman 3.0以上（ITDO_ERP2プロジェクト用）

### 確認コマンド
```bash
python3 --version    # Python 3.11.x
git --version       # git version 2.30.x
gh --version        # gh version 2.x.x
podman --version    # podman version 3.x.x
```

## 🚀 ステップ1: 作業ディレクトリの準備

### 1.1 claude-code-clusterのセットアップ

```bash
# 作業ディレクトリへ移動
cd /tmp

# claude-code-clusterリポジトリをクローン
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster

# 最新版を取得
git pull origin main

# 現在の作業ディレクトリを確認
pwd
# 出力: /tmp/claude-code-cluster
```

### 1.2 ITDO_ERP2プロジェクトの確認

```bash
# ITDO_ERP2プロジェクトの場所を確認
ls -la /mnt/c/work/ITDO_ERP2/

# プロジェクトディレクトリへ移動
cd /mnt/c/work/ITDO_ERP2

# プロジェクト構造を確認
tree -L 2 .
# または
find . -maxdepth 2 -type d
```

## 🔧 ステップ2: Python環境のセットアップ

### 2.1 requirements.txtの作成

claude-code-clusterにはrequirements.txtが含まれていないため、作成します：

```bash
# claude-code-clusterディレクトリで作業
cd /tmp/claude-code-cluster

# requirements.txtを作成
cat > requirements.txt << 'EOF'
# Core dependencies
requests>=2.31.0
aiohttp>=3.9.0
asyncio>=3.4.3
python-dotenv>=1.0.0
click>=8.1.0
pydantic>=2.0.0

# Database and storage
sqlalchemy>=2.0.0

# GitHub integration
PyGithub>=1.59.0
gitpython>=3.1.0

# Utilities
colorama>=0.4.6
tabulate>=0.9.0
python-dateutil>=2.8.0
psutil>=5.9.0

# Testing (optional)
pytest>=7.0.0
pytest-asyncio>=0.21.0
pytest-cov>=4.0.0
EOF

# requirements.txtの内容を確認
cat requirements.txt
```

### 2.2 Python仮想環境の作成

```bash
# 現在のディレクトリを確認
pwd
# 出力: /tmp/claude-code-cluster

# Python仮想環境を作成
python3 -m venv venv

# 仮想環境の作成を確認
ls -la venv/
# bin/, include/, lib/, pyvenv.cfg が確認できること

# 仮想環境をアクティベート
source venv/bin/activate

# アクティベートの確認（プロンプトが変わる）
echo $VIRTUAL_ENV
# 出力: /tmp/claude-code-cluster/venv

# pipをアップグレード
pip install --upgrade pip setuptools wheel

# 依存関係をインストール
pip install -r requirements.txt

# インストール完了の確認
pip list
pip freeze > installed_packages.txt
```

## 🔑 ステップ3: 認証設定

### 3.1 GitHub CLI認証

```bash
# GitHub CLIの認証状態を確認
gh auth status

# 認証が必要な場合
gh auth login

# 認証タイプの選択:
# 1. GitHub.com を選択
# 2. HTTPS を選択
# 3. Yes (git credential helper) を選択
# 4. Browser でログイン

# 認証確認
gh auth status
gh api user
```

### 3.2 環境変数の設定

```bash
# 現在のディレクトリを確認
pwd
# 出力: /tmp/claude-code-cluster

# .envファイルを作成
cat > .env << 'EOF'
# Claude Code Cluster Configuration
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

# System Configuration
LOG_RETENTION_DAYS=30
BACKUP_ENABLED=false
MONITORING_ENABLED=true

# ITDO_ERP2 Project Configuration
ITDO_ERP2_PATH=/mnt/c/work/ITDO_ERP2
CONTAINER_RUNTIME=podman
EOF

# .envファイルの権限設定
chmod 600 .env

# .envファイルの内容確認（API keyは表示されない）
cat .env | grep -v "API_KEY\|TOKEN"
```

## 🐳 ステップ4: Podman設定（ITDO_ERP2用）

### 4.1 Podmanの確認とセットアップ

```bash
# Podmanの動作確認
podman --version
podman info

# podman-composeがインストールされているか確認
podman-compose --version || pip install podman-compose

# ITDO_ERP2プロジェクトのPodman設定確認
cd /mnt/c/work/ITDO_ERP2

# Docker Composeファイルを確認
ls -la infra/
cat infra/compose-data.yaml

# Podmanでデータレイヤーを起動
podman-compose -f infra/compose-data.yaml up -d

# コンテナの状態確認
podman ps
podman-compose -f infra/compose-data.yaml ps
```

### 4.2 データベース接続確認

```bash
# PostgreSQL接続確認
podman exec -it $(podman ps -q --filter "name=postgres") psql -U itdo_user -d itdo_erp_dev -c "SELECT version();"

# Redis接続確認
podman exec -it $(podman ps -q --filter "name=redis") redis-cli ping
```

## 🛠️ ステップ5: claude-code-clusterの設定

### 5.1 実行権限の設定

```bash
# claude-code-clusterディレクトリに戻る
cd /tmp/claude-code-cluster

# 全スクリプトファイルに実行権限を付与
find . -name "*.sh" -type f -exec chmod +x {} \;
find . -name "*.py" -type f -exec chmod +x {} \;

# 権限設定の確認
ls -la *.sh
ls -la hooks/*.py
ls -la scripts/*.sh
```

### 5.2 ログディレクトリの作成

```bash
# claude-code-clusterのログディレクトリを作成
mkdir -p /tmp/claude-code-logs

# ITDO_ERP2用のログディレクトリも作成
mkdir -p /tmp/claude-code-logs/itdo-erp2

# 権限設定
chmod 755 /tmp/claude-code-logs
chmod 755 /tmp/claude-code-logs/itdo-erp2

# 作成確認
ls -la /tmp/claude-code-logs/
```

### 5.3 エージェント設定ファイルの作成

```bash
# 現在のディレクトリを確認
pwd
# 出力: /tmp/claude-code-cluster

# エージェント設定ディレクトリを作成
mkdir -p agent-config

# ITDO_ERP2用のエージェント設定を作成
cat > agent-config/itdo-erp2.json << 'EOF'
{
  "project_name": "ITDO_ERP2",
  "project_path": "/mnt/c/work/ITDO_ERP2",
  "container_runtime": "podman",
  "agents": {
    "CC01": {
      "specialization": "Backend & Database Specialist",
      "labels": ["backend", "database", "fastapi", "postgresql"],
      "keywords": ["python", "fastapi", "sqlalchemy", "postgresql", "redis"],
      "working_directory": "/mnt/c/work/ITDO_ERP2/backend"
    },
    "CC02": {
      "specialization": "DevOps & Infrastructure Specialist", 
      "labels": ["devops", "infrastructure", "ci-cd", "docker"],
      "keywords": ["podman", "docker", "ci", "cd", "deployment"],
      "working_directory": "/mnt/c/work/ITDO_ERP2"
    },
    "CC03": {
      "specialization": "Frontend & Testing Specialist",
      "labels": ["frontend", "testing", "react", "typescript"],
      "keywords": ["react", "typescript", "vitest", "testing", "ui"],
      "working_directory": "/mnt/c/work/ITDO_ERP2/frontend"
    }
  }
}
EOF

# 設定ファイルの確認
cat agent-config/itdo-erp2.json
```

## 🧪 ステップ6: 動作テスト

### 6.1 基本機能テスト

```bash
# 現在のディレクトリとPython環境を確認
pwd
# 出力: /tmp/claude-code-cluster
echo $VIRTUAL_ENV
# 出力: /tmp/claude-code-cluster/venv

# コマンドロガーのテスト
python3 hooks/command_logger.py

# ログビューアーのテスト
python3 hooks/view-command-logs.py --help

# クイックテストの実行
if [ -f scripts/quick-test-command-logging.sh ]; then
    ./scripts/quick-test-command-logging.sh
else
    echo "クイックテストスクリプトが見つかりません"
fi
```

### 6.2 ITDO_ERP2との連携テスト

```bash
# ITDO_ERP2プロジェクトの状態確認
cd /mnt/c/work/ITDO_ERP2

# GitHubリポジトリの確認
gh repo view
gh issue list --limit 5

# Podmanコンテナの状態確認
podman ps

# claude-code-clusterディレクトリに戻る
cd /tmp/claude-code-cluster

# ITDO_ERP2向けエージェントの起動テスト（dry run）
python3 hooks/universal-agent-auto-loop-with-logging.py TEST01 itdojp ITDO_ERP2 \
  --specialization "Test Agent" \
  --labels test \
  --keywords test \
  --max-iterations 1 \
  --dry-run 2>/dev/null || echo "Dry run機能がない場合は正常"
```

## 📊 ステップ7: エージェントの起動

### 7.1 単体エージェントの起動

```bash
# 現在のディレクトリを確認
pwd
# 出力: /tmp/claude-code-cluster

# 仮想環境がアクティブか確認
echo $VIRTUAL_ENV
# 出力: /tmp/claude-code-cluster/venv

# CC01エージェントの起動（Backend specialist）
python3 hooks/universal-agent-auto-loop-with-logging.py CC01 itdojp ITDO_ERP2 \
  --specialization "Backend & Database Specialist" \
  --labels backend database fastapi postgresql \
  --keywords python fastapi sqlalchemy postgresql redis \
  --max-iterations 5 \
  --cooldown 300 &

# プロセスID保存
CC01_PID=$!
echo "CC01 PID: $CC01_PID"

# ログの確認
sleep 5
python3 hooks/view-command-logs.py --agent CC01-ITDO_ERP2 --limit 10
```

### 7.2 複数エージェントの起動

```bash
# CC02エージェントの起動（DevOps specialist）
python3 hooks/universal-agent-auto-loop-with-logging.py CC02 itdojp ITDO_ERP2 \
  --specialization "DevOps & Infrastructure Specialist" \
  --labels devops infrastructure ci-cd docker \
  --keywords podman docker ci cd deployment \
  --max-iterations 5 \
  --cooldown 300 &

CC02_PID=$!
echo "CC02 PID: $CC02_PID"

# CC03エージェントの起動（Frontend specialist）
python3 hooks/universal-agent-auto-loop-with-logging.py CC03 itdojp ITDO_ERP2 \
  --specialization "Frontend & Testing Specialist" \
  --labels frontend testing react typescript \
  --keywords react typescript vitest testing ui \
  --max-iterations 5 \
  --cooldown 300 &

CC03_PID=$!
echo "CC03 PID: $CC03_PID"

# 全エージェントの起動確認
ps aux | grep "universal-agent-auto-loop"
```

## 📈 ステップ8: 監視とログ確認

### 8.1 リアルタイム監視

```bash
# 現在のディレクトリを確認
pwd
# 出力: /tmp/claude-code-cluster

# 全エージェントのログをリアルタイムで監視
python3 hooks/view-command-logs.py --follow

# 別のターミナルで特定エージェントを監視
python3 hooks/view-command-logs.py --agent CC01-ITDO_ERP2 --follow

# 統計情報の確認
python3 hooks/view-command-logs.py --stats
```

### 8.2 ログのエクスポート

```bash
# 現在のディレクトリを確認
pwd
# 出力: /tmp/claude-code-cluster

# ログをJSONファイルにエクスポート
python3 hooks/view-command-logs.py --export /tmp/claude-logs-$(date +%Y%m%d_%H%M%S).json

# エクスポートファイルの確認
ls -la /tmp/claude-logs-*.json
```

## 🔧 ステップ9: ITDO_ERP2プロジェクトでの使用

### 9.1 プロジェクト固有の設定

```bash
# ITDO_ERP2プロジェクトディレクトリに移動
cd /mnt/c/work/ITDO_ERP2

# プロジェクト用の設定ファイルを作成
cat > .claude-code-config.json << 'EOF'
{
  "project_type": "ERP_system",
  "technology_stack": {
    "backend": "Python FastAPI",
    "frontend": "React TypeScript",
    "database": "PostgreSQL",
    "cache": "Redis",
    "container": "Podman"
  },
  "work_directories": {
    "backend": "./backend",
    "frontend": "./frontend",
    "infrastructure": "./infra",
    "scripts": "./scripts"
  },
  "container_commands": {
    "start_data": "podman-compose -f infra/compose-data.yaml up -d",
    "stop_data": "podman-compose -f infra/compose-data.yaml down",
    "status": "podman-compose -f infra/compose-data.yaml ps"
  }
}
EOF

# 設定ファイルの確認
cat .claude-code-config.json
```

### 9.2 Podmanコンテナとの連携

```bash
# データレイヤーの起動
podman-compose -f infra/compose-data.yaml up -d

# コンテナ状態の確認
podman ps

# バックエンドテストの実行
cd backend
python3 -m pytest tests/ -v

# フロントエンドテストの実行
cd ../frontend
npm test
```

## 🚨 トラブルシューティング

### 一般的な問題と解決方法

#### 1. Python環境の問題

```bash
# 仮想環境の再作成
cd /tmp/claude-code-cluster
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

#### 2. 権限エラー

```bash
# ログディレクトリの権限修正
sudo chown -R $USER:$USER /tmp/claude-code-logs
chmod -R 755 /tmp/claude-code-logs
```

#### 3. Podmanの問題

```bash
# Podmanサービスの確認
systemctl --user status podman.socket
systemctl --user start podman.socket

# コンテナの再起動
cd /mnt/c/work/ITDO_ERP2
podman-compose -f infra/compose-data.yaml down
podman-compose -f infra/compose-data.yaml up -d
```

#### 4. エージェントが起動しない

```bash
# ログの確認
python3 /tmp/claude-code-cluster/hooks/view-command-logs.py --limit 20

# プロセスの確認
ps aux | grep python3 | grep universal-agent

# 手動でのテスト実行
cd /tmp/claude-code-cluster
python3 hooks/universal-agent-auto-loop-with-logging.py --help
```

## 📝 使用方法のまとめ

1. **基本的な作業フロー**
   - `/tmp/claude-code-cluster` でエージェントを起動
   - `/mnt/c/work/ITDO_ERP2` でプロジェクト作業
   - Podmanでデータレイヤーを管理

2. **重要なディレクトリ**
   - `/tmp/claude-code-cluster`: claude-code-clusterシステム
   - `/tmp/claude-code-logs`: ログファイル
   - `/mnt/c/work/ITDO_ERP2`: ITDO_ERP2プロジェクト

3. **必須の環境変数**
   - `CLAUDE_API_KEY`: Claude APIキー
   - `GITHUB_TOKEN`: GitHub認証トークン
   - `VIRTUAL_ENV`: Python仮想環境パス

---

このガイドに従うことで、ITDO_ERP2プロジェクトでclaude-code-clusterを正常に動作させることができます。
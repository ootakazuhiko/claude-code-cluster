# Claude Code Cluster PoC - 使用ガイド

## 📋 目次

1. [概要](#概要)
2. [前提条件](#前提条件)
3. [動作環境](#動作環境)
4. [セットアップ手順](#セットアップ手順)
5. [実行方法](#実行方法)
6. [動作確認](#動作確認)
7. [トラブルシューティング](#トラブルシューティング)
8. [制限事項](#制限事項)

## 🎯 概要

Claude Code Cluster PoCは、**Claude Code CLI**を複数のPCで分散実行し、GitHub Issue駆動で自動的にコード生成・PR作成を行うシステムです。

### 重要な注意事項
- 本PoCは**Claude Code CLI**を使用します（Claude APIではありません）
- 各PCに**独立したClaude Code環境**が必要です
- **最低5台のPC**が必要です（調整サーバー1台 + 専門Agent PC 4台）

## 🔧 前提条件

### 必須要件

#### 1. Claude Code CLI
- **各PCにClaude Code CLIがインストール済み**であること
- Claude Code CLIが**認証済み**で使用可能な状態であること
- CLIバージョン: 最新版推奨

```bash
# Claude Code CLIの確認
claude-code --version

# 認証状態の確認
claude-code auth status
```

#### 2. GitHub アカウント
- **Personal Access Token (PAT)** が必要
- 必要な権限: `repo`, `workflow`, `write:packages`
- 各Agent PCごとに異なるトークンを推奨

#### 3. ハードウェア要件

| PC種別 | 最小構成 | 推奨構成 | 用途 |
|--------|----------|----------|------|
| **Coordinator PC** | 4 cores, 8GB RAM, 100GB SSD | 8 cores, 16GB RAM, 500GB SSD | タスク調整・管理 |
| **Backend PC** | 4 cores, 16GB RAM, 500GB SSD | 8 cores, 32GB RAM, 1TB NVMe | Python/API開発 |
| **Frontend PC** | 4 cores, 16GB RAM, 500GB SSD | 8 cores, 32GB RAM, 1TB NVMe | React/TypeScript開発 |
| **Testing PC** | 4 cores, 16GB RAM, 500GB SSD | 8 cores, 32GB RAM, 1TB NVMe | テスト実行 |
| **DevOps PC** | 4 cores, 16GB RAM, 500GB SSD | 8 cores, 32GB RAM, 1TB NVMe | インフラ/デプロイ |

#### 4. ソフトウェア要件
- **OS**: Ubuntu 22.04 LTS（全PC）
- **Python**: 3.11以上
- **Docker**: 24.0以上（Coordinator PCのみ）
- **Git**: 2.34以上

## 🌐 動作環境

### ネットワーク構成

```
┌─────────────────────────────────────────────────────────┐
│                  インターネット                          │
│                       ↑                                 │
│                    GitHub                               │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────┴─────────────────────────────────┐
│                 内部ネットワーク                        │
│                  192.168.1.0/24                         │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │Coordinator  │  │Backend PC   │  │Frontend PC  │   │
│  │192.168.1.10 │  │192.168.1.11 │  │192.168.1.12 │   │
│  └─────────────┘  └─────────────┘  └─────────────┘   │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐                     │
│  │Testing PC   │  │DevOps PC    │                     │
│  │192.168.1.13 │  │192.168.1.14 │                     │
│  └─────────────┘  └─────────────┘                     │
└─────────────────────────────────────────────────────────┘
```

### ポート使用

| サービス | ポート | 用途 |
|---------|--------|------|
| Coordinator API | 8080 | タスク管理API |
| Webhook Server | 80/443 | GitHub Webhook受信 |
| Agent API | 8000 | 各Agent PCのAPI |
| PostgreSQL | 5432 | Coordinator DB |
| Redis | 6379 | キャッシュ・キュー |

## 📦 セットアップ手順

### Step 1: Coordinator PC セットアップ

#### 1.1 基本環境準備

```bash
# システム更新
sudo apt update && sudo apt upgrade -y

# 必要パッケージインストール
sudo apt install -y python3.11 python3.11-venv python3-pip \
    docker.io docker-compose postgresql-client redis-tools \
    git curl wget nginx

# Dockerグループ追加
sudo usermod -aG docker $USER
newgrp docker
```

#### 1.2 Coordinator アプリケーションセットアップ

```bash
# リポジトリクローン
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster/claude-code-cluster-poc

# Python仮想環境作成
python3.11 -m venv venv
source venv/bin/activate

# 依存関係インストール
pip install -e .

# 環境設定
cp .env.example .env
```

#### 1.3 環境変数設定

`.env`ファイルを編集：

```bash
# GitHub設定
GITHUB_TOKEN=ghp_your_coordinator_github_token
GIT_USER_NAME=Coordinator Bot
GIT_USER_EMAIL=coordinator@your-domain.com

# Claude Code CLI設定
CLAUDE_CODE_CLI_PATH=/usr/local/bin/claude-code

# データベース設定
DATABASE_URL=postgresql://coordinator:password@localhost:5432/coordinator_db
REDIS_URL=redis://localhost:6379/0

# Webhook設定
WEBHOOK_SECRET=your_webhook_secret_here
WEBHOOK_PORT=8080
```

#### 1.4 データベース・Redis起動

```bash
# Docker Composeで起動
cd coordinator/
docker-compose up -d postgres redis

# データベース初期化
python manage.py db init
python manage.py db migrate
```

### Step 2: Agent PC セットアップ（各専門PC共通）

#### 2.1 基本環境準備

```bash
# システム更新
sudo apt update && sudo apt upgrade -y

# 基本パッケージ
sudo apt install -y python3.11 python3.11-venv python3-pip \
    git curl wget build-essential

# Claude Code CLIがインストール済みか確認
claude-code --version
# もしインストールされていない場合は、公式手順に従ってインストール
```

#### 2.2 Agent デーモンセットアップ

```bash
# Agentディレクトリ作成
sudo mkdir -p /opt/claude-agent/{config,workspaces,logs}
sudo chown -R $USER:$USER /opt/claude-agent

# リポジトリクローン
cd /opt/claude-agent
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster/agent

# Python仮想環境
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Step 3: 専門環境別セットアップ

#### 3.1 Backend PC 追加セットアップ

```bash
# Python開発ツール
pip install poetry uv pytest black isort mypy pylint

# データベースクライアント
sudo apt install -y postgresql-client mysql-client redis-tools

# API開発ツール
pip install httpie jq
```

**Agent設定ファイル** (`/opt/claude-agent/config/agent.yml`):

```yaml
agent_id: backend-specialist-001
hostname: 192.168.1.11
coordinator_url: http://192.168.1.10:8080
specialties:
  - backend
  - api
  - database
  - python
workspace_root: /opt/claude-agent/workspaces
max_concurrent_tasks: 2
github_token: ghp_backend_pc_github_token
```

#### 3.2 Frontend PC 追加セットアップ

```bash
# Node.js環境
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20

# Frontend開発ツール
npm install -g yarn typescript @types/node
npm install -g create-react-app next create-vite
npm install -g prettier eslint

# ブラウザ
sudo apt install -y chromium-browser firefox
```

**Agent設定ファイル** (`/opt/claude-agent/config/agent.yml`):

```yaml
agent_id: frontend-specialist-001
hostname: 192.168.1.12
coordinator_url: http://192.168.1.10:8080
specialties:
  - frontend
  - react
  - typescript
  - ui
workspace_root: /opt/claude-agent/workspaces
max_concurrent_tasks: 2
github_token: ghp_frontend_pc_github_token
```

#### 3.3 Testing PC 追加セットアップ

```bash
# Python テストツール
pip install pytest pytest-cov pytest-asyncio selenium

# JavaScript テストツール
npm install -g jest @testing-library/react cypress playwright

# ブラウザドライバー
sudo apt install -y chromium-chromedriver geckodriver

# 負荷テストツール
sudo apt install -y apache2-utils siege
```

**Agent設定ファイル** (`/opt/claude-agent/config/agent.yml`):

```yaml
agent_id: testing-specialist-001
hostname: 192.168.1.13
coordinator_url: http://192.168.1.10:8080
specialties:
  - testing
  - qa
  - pytest
  - jest
  - e2e
workspace_root: /opt/claude-agent/workspaces
max_concurrent_tasks: 3
github_token: ghp_testing_pc_github_token
```

#### 3.4 DevOps PC 追加セットアップ

```bash
# コンテナツール
sudo apt install -y docker.io docker-compose
sudo usermod -aG docker $USER

# Kubernetes ツール
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# インフラツール
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Cloud CLI
# AWS CLI, gcloud, Azure CLI のインストール（必要に応じて）
```

**Agent設定ファイル** (`/opt/claude-agent/config/agent.yml`):

```yaml
agent_id: devops-specialist-001
hostname: 192.168.1.14
coordinator_url: http://192.168.1.10:8080
specialties:
  - devops
  - docker
  - kubernetes
  - ci
  - infrastructure
workspace_root: /opt/claude-agent/workspaces
max_concurrent_tasks: 2
github_token: ghp_devops_pc_github_token
```

## 🚀 実行方法

### 1. サービス起動

#### Coordinator PC

```bash
# 1. データベース・Redis確認
docker-compose ps

# 2. Coordinator API起動
cd /path/to/claude-code-cluster/coordinator
source venv/bin/activate
python -m uvicorn main:app --host 0.0.0.0 --port 8080

# 3. Webhook Server起動（別ターミナル）
python webhook_server.py
```

#### 各Agent PC

```bash
# Agent daemon起動
cd /opt/claude-agent/claude-code-cluster/agent
source venv/bin/activate
python agent_daemon.py --config /opt/claude-agent/config/agent.yml
```

### 2. GitHub Webhook設定

1. GitHubリポジトリの Settings → Webhooks → Add webhook
2. 設定内容:
   - **Payload URL**: `http://your-coordinator-domain/webhook/github`
   - **Content type**: `application/json`
   - **Secret**: `.env`の`WEBHOOK_SECRET`と同じ値
   - **Events**: `Issues`, `Pull requests`

### 3. 動作テスト

```bash
# 1. ヘルスチェック（Coordinator PCから）
curl http://192.168.1.10:8080/health
curl http://192.168.1.11:8000/health  # Backend Agent
curl http://192.168.1.12:8000/health  # Frontend Agent
curl http://192.168.1.13:8000/health  # Testing Agent
curl http://192.168.1.14:8000/health  # DevOps Agent

# 2. Agent状態確認
curl http://192.168.1.10:8080/api/agents

# 3. テストIssue作成
# GitHubで新しいIssueを作成し、Webhookが動作することを確認
```

## 🔍 動作確認

### 正常動作の確認ポイント

1. **Webhook受信確認**
   ```bash
   # Coordinator ログ確認
   tail -f /var/log/coordinator/webhook.log
   ```

2. **タスク割り当て確認**
   ```bash
   # タスク一覧
   curl http://192.168.1.10:8080/api/tasks
   ```

3. **Agent実行確認**
   ```bash
   # 各Agent PCのログ
   tail -f /opt/claude-agent/logs/agent.log
   ```

4. **Claude Code実行確認**
   ```bash
   # ワークスペース確認
   ls -la /opt/claude-agent/workspaces/
   ```

### 期待される動作フロー

1. GitHub Issueが作成される
2. Webhook経由でCoordinatorが受信
3. Issue内容を解析し、専門分野を判定
4. 適切なAgent PCにタスクを割り当て
5. Agent PCでClaude Code CLIが実行される
6. コードが生成され、テストが実行される
7. GitHub上にPRが作成される
8. Issueに対してPRリンクがコメントされる

## 🔧 トラブルシューティング

### よくある問題と解決方法

#### 1. Claude Code CLIが見つからない

**エラー**: `Claude Code CLI not found`

**解決方法**:
```bash
# CLIパスを確認
which claude-code

# 環境変数に追加
echo 'export PATH=$PATH:/path/to/claude-code' >> ~/.bashrc
source ~/.bashrc

# Agent設定ファイルのパスを更新
vim /opt/claude-agent/config/agent.yml
```

#### 2. Agent PCがCoordinatorに接続できない

**エラー**: `Failed to connect to coordinator`

**解決方法**:
```bash
# ネットワーク接続確認
ping 192.168.1.10

# ファイアウォール確認
sudo ufw status

# 必要なポートを開放
sudo ufw allow from 192.168.1.0/24 to any port 8080
sudo ufw allow 8000
```

#### 3. GitHub Webhookが届かない

**エラー**: Webhookイベントが受信されない

**解決方法**:
1. GitHub Webhook設定の「Recent Deliveries」を確認
2. Webhook URLが正しいか確認
3. Secretが一致しているか確認
4. ファイアウォールで80/443ポートが開いているか確認

#### 4. Claude Code実行エラー

**エラー**: `Claude Code execution failed`

**解決方法**:
```bash
# Claude Code CLIの認証状態確認
claude-code auth status

# 手動でClaude Code実行テスト
cd /opt/claude-agent/workspaces/test
claude-code --prompt "Create a simple hello world Python script"
```

## ⚠️ 制限事項

### 現在のPoC制限

1. **セキュリティ**
   - HTTPSは未実装（本番環境では必須）
   - Agent間通信の暗号化なし
   - シークレット管理が基本的

2. **スケーラビリティ**
   - 固定5台構成（動的スケーリング非対応）
   - 単一Coordinatorのため単一障害点
   - ファイルベースの状態管理

3. **Claude Code CLI依存**
   - Claude Code CLIの制限がそのまま適用
   - 認証トークンの有効期限管理が必要
   - API レート制限の考慮が必要

4. **運用機能**
   - 監視・アラート機能が基本的
   - バックアップ・リストア機能なし
   - ログローテーション未実装

### 推奨使用シナリオ

✅ **適している用途**:
- 小〜中規模チームでの自動化実験
- Claude Code機能の検証
- 専門分野別開発の効率化研究
- GitHub連携ワークフローの検証

❌ **適していない用途**:
- 本番環境での使用
- 大規模プロジェクト
- 機密性の高いコード
- 24/7稼働が必要なシステム

## 📞 サポート

### ログファイル位置

| コンポーネント | ログファイル |
|---------------|-------------|
| Coordinator API | `/var/log/coordinator/api.log` |
| Webhook Server | `/var/log/coordinator/webhook.log` |
| Agent Daemon | `/opt/claude-agent/logs/agent.log` |
| Claude Code実行 | `/opt/claude-agent/workspaces/*/claude_code.log` |

### デバッグモード

```bash
# 環境変数設定
export LOG_LEVEL=DEBUG

# Agentを詳細ログで起動
python agent_daemon.py --config agent.yml --debug
```

---

**重要**: このPoCは実験的な実装です。本番環境での使用には、セキュリティ強化、冗長性、監視システムなどの追加実装が必要です。
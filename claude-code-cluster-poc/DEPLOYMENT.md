# Claude Code Cluster PoC - デプロイメントガイド

## 🎯 デプロイメント方式の選択

### 用途別推奨構成

| 用途 | 推奨方式 | 必要台数 | セットアップ時間 |
|------|----------|----------|------------------|
| **個人開発・学習** | ローカル単体 | 1台 | 15分 |
| **チーム検証** | Docker Compose | 1台 | 30分 |
| **小規模運用** | 分散クラスター | 2-3台 | 1-2時間 |
| **負荷テスト** | Kubernetes | 3-5台 | 2-4時間 |

## 🔧 方式1: ローカル単体構成

### 概要
- 一台のPC上で完結
- 最も簡単、設定が少ない
- 個人開発やアルゴリズム検証に最適

### 必要リソース
- **CPU**: 2コア以上
- **メモリ**: 4GB以上
- **ストレージ**: 2GB空き容量
- **OS**: Windows 10+, macOS 10.15+, Ubuntu 18.04+

### セットアップ

```bash
# 1. リポジトリクローン
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster/claude-code-cluster-poc

# 2. 環境構築
uv venv && source .venv/bin/activate
uv pip install -e .

# 3. 設定
cp .env.example .env
# .env ファイルを編集してAPI キーを設定

# 4. セットアップ確認
claude-cluster setup

# 5. 動作テスト
claude-cluster workflow --issue 1 --repo your-username/test-repo
```

### メリット・デメリット

**✅ メリット:**
- セットアップが簡単
- ネットワーク設定不要
- デバッグが容易

**❌ デメリット:**
- 処理能力が限定的
- 専門Agent機能が制限される
- 分散処理の検証ができない

## 🐳 方式2: Docker Compose構成

### 概要
- 一台のマシン上で複数サービスを模擬
- クラスター機能のテストが可能
- CI/CDパイプラインでの利用に適している

### 必要リソース
- **CPU**: 4コア以上
- **メモリ**: 8GB以上
- **Docker**: 20.10+
- **Docker Compose**: 2.0+

### ディレクトリ構成

```
claude-code-cluster-poc/
├── docker-compose.yml          # メインの構成ファイル
├── Dockerfile                  # 共通イメージ
├── .env                       # 環境変数
└── compose/
    ├── coordinator.yml        # 調整サーバー設定
    ├── agents.yml            # Agent群設定
    └── monitoring.yml        # 監視設定（オプション）
```

### デプロイ手順

#### 1. 基本セットアップ

```bash
# 環境変数設定
cat > .env << EOF
GITHUB_TOKEN=ghp_your_github_token_here
ANTHROPIC_API_KEY=sk-ant-your_anthropic_key_here
COORDINATOR_HOST=coordinator
COORDINATOR_PORT=8001
EOF

# 全サービス起動
docker-compose up -d

# ログ確認
docker-compose logs -f
```

#### 2. サービス構成確認

```bash
# 実行中サービス確認
docker-compose ps

# 期待される出力:
# coordinator    0.0.0.0:8001->8001/tcp   Running
# agent-backend  0.0.0.0:8002->8002/tcp   Running  
# agent-frontend 0.0.0.0:8003->8003/tcp   Running
# agent-testing  0.0.0.0:8004->8004/tcp   Running
# agent-devops   0.0.0.0:8005->8005/tcp   Running
# webhook-server 0.0.0.0:8000->8000/tcp   Running
```

#### 3. 動作確認

```bash
# ヘルスチェック
curl http://localhost:8001/health

# クラスター状態
curl http://localhost:8001/api/cluster/status | jq

# テストタスク投入
curl -X POST http://localhost:8001/api/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "task_id": "test-001",
    "priority": "medium",
    "requirements": ["backend"]
  }'
```

### カスタマイズ

#### Agentのスケーリング

```bash
# Backend Agentを3台に増加
docker-compose up -d --scale agent-backend=3

# 負荷分散確認
curl http://localhost:8001/api/cluster/status
```

#### 外部ネットワークアクセス

```yaml
# docker-compose.override.yml
version: '3.8'
services:
  webhook-server:
    ports:
      - "80:8000"  # HTTP
      - "443:8000" # HTTPS（リバースプロキシ使用時）
```

## 🌐 方式3: 分散クラスター構成

### 概要
- 複数の物理/仮想マシンで構成
- 真の負荷分散とフォルトトレラント
- 本格的な検証・小規模運用に対応

### アーキテクチャ設計

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Coordinator   │    │  Agent Node 1   │    │  Agent Node 2   │
│  (192.168.1.10) │    │ (192.168.1.11)  │    │ (192.168.1.12)  │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │Coordinator  │ │    │ │Backend Agent│ │    │ │Frontend     │ │
│ │API :8001    │◄┼────┼►│    :8002    │ │    │ │Agent :8003  │ │
│ │             │ │    │ │             │ │    │ │             │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │Webhook      │ │    │ │Testing Agent│ │    │ │DevOps Agent │ │
│ │Server :8000 │ │    │ │    :8004    │ │    │ │    :8005    │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### サーバー要件

#### Coordinatorノード（1台）
- **CPU**: 2コア
- **メモリ**: 4GB
- **ストレージ**: SSD 20GB
- **ネットワーク**: 固定IP推奨
- **OS**: Ubuntu 20.04 LTS

#### Agentノード（2-4台）
- **CPU**: 4コア
- **メモリ**: 8GB  
- **ストレージ**: SSD 10GB
- **ネットワーク**: 調整サーバーとの通信可能
- **OS**: Ubuntu 20.04 LTS または Docker対応OS

### デプロイ手順

#### 1. Coordinatorサーバーセットアップ

```bash
# サーバー1 (192.168.1.10)
# アプリケーションインストール
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster/claude-code-cluster-poc

# Python環境セットアップ
curl -LsSf https://astral.sh/uv/install.sh | sh
uv venv && source .venv/bin/activate
uv pip install -e .

# 環境設定
cp .env.example .env
# APIキーを設定

# systemdサービス作成
sudo tee /etc/systemd/system/claude-coordinator.service << EOF
[Unit]
Description=Claude Code Cluster Coordinator
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/claude-code-cluster/claude-code-cluster-poc
ExecStart=/home/ubuntu/claude-code-cluster/claude-code-cluster-poc/.venv/bin/claude-cluster-distributed start-coordinator --host 0.0.0.0 --port 8001
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# サービス開始
sudo systemctl daemon-reload
sudo systemctl enable claude-coordinator
sudo systemctl start claude-coordinator

# 動作確認
curl http://localhost:8001/health
```

#### 2. Agentノードセットアップ

```bash
# サーバー2 (192.168.1.11) - Backend専門
# 基本セットアップ（上記と同様）
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster/claude-code-cluster-poc
uv venv && source .venv/bin/activate
uv pip install -e .

# Backend Agent サービス
sudo tee /etc/systemd/system/claude-backend-agent.service << EOF
[Unit]
Description=Claude Backend Agent
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/claude-code-cluster/claude-code-cluster-poc
ExecStart=/home/ubuntu/claude-code-cluster/claude-code-cluster-poc/.venv/bin/claude-cluster-distributed start-node --coordinator-host 192.168.1.10 --coordinator-port 8001 --agent-port 8002 --specialties backend,api,database --max-tasks 2 --node-id backend-node-001
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable claude-backend-agent
sudo systemctl start claude-backend-agent
```

```bash
# サーバー3 (192.168.1.12) - Frontend専門
# Frontend Agent サービス
sudo tee /etc/systemd/system/claude-frontend-agent.service << EOF
[Unit]
Description=Claude Frontend Agent
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/claude-code-cluster/claude-code-cluster-poc
ExecStart=/home/ubuntu/claude-code-cluster/claude-code-cluster-poc/.venv/bin/claude-cluster-distributed start-node --coordinator-host 192.168.1.10 --coordinator-port 8001 --agent-port 8003 --specialties frontend,react,ui --max-tasks 2 --node-id frontend-node-001
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable claude-frontend-agent
sudo systemctl start claude-frontend-agent
```

#### 3. ファイアウォール設定

```bash
# 全サーバーで実行
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 8000:8005/tcp  # Claude services
sudo ufw enable

# Coordinatorサーバーでのみ実行
sudo ufw allow 80/tcp   # HTTP（Webhook用）
sudo ufw allow 443/tcp  # HTTPS（Webhook用）
```

#### 4. 動作確認とテスト

```bash
# Coordinatorサーバーから確認
curl http://192.168.1.10:8001/api/cluster/status

# 期待される出力例:
{
  "nodes": {
    "total": 2,
    "online": 2,
    "offline": 0
  },
  "tasks": {
    "total": 0,
    "pending": 0,
    "active": 0,
    "completed": 0
  },
  "node_details": [
    {
      "node_id": "backend-node-001",
      "host": "192.168.1.11",
      "port": 8002,
      "status": "online",
      "specialties": ["backend", "api", "database"]
    },
    {
      "node_id": "frontend-node-001", 
      "host": "192.168.1.12",
      "port": 8003,
      "status": "online",
      "specialties": ["frontend", "react", "ui"]
    }
  ]
}

# テストタスク実行
claude-cluster-distributed workflow \
  --issue 123 \
  --repo username/test-repo \
  --distributed \
  --coordinator-host 192.168.1.10 \
  --coordinator-port 8001
```

## ☸️ 方式4: Kubernetes構成（上級）

### 概要
- コンテナオーケストレーション
- 自動スケーリング・復旧
- 本格的な運用環境

### 前提条件
- Kubernetes クラスター (1.20+)
- kubectl 設定済み
- Helm 3.0+ (推奨)

### Helm Chart作成

```bash
# Helm Chart初期化
helm create claude-cluster
cd claude-cluster

# values.yaml 設定例
cat > values.yaml << EOF
replicaCount: 1

coordinator:
  enabled: true
  port: 8001
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi

agents:
  backend:
    replicas: 2
    port: 8002
    specialties: "backend,api,database"
  frontend:
    replicas: 2
    port: 8003
    specialties: "frontend,react,ui"
  testing:
    replicas: 1
    port: 8004
    specialties: "testing,qa,pytest"
  devops:
    replicas: 1
    port: 8005
    specialties: "devops,docker,ci"

secrets:
  githubToken: ""  # base64エンコード済み
  anthropicApiKey: ""  # base64エンコード済み

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: claude-cluster.example.com
      paths:
        - path: /
          pathType: Prefix
EOF
```

### デプロイメント

```bash
# Namespace作成
kubectl create namespace claude-cluster

# Secret作成
kubectl create secret generic claude-secrets \
  --from-literal=github-token=$GITHUB_TOKEN \
  --from-literal=anthropic-api-key=$ANTHROPIC_API_KEY \
  -n claude-cluster

# Helm デプロイ
helm install claude-cluster . -n claude-cluster

# 状態確認
kubectl get pods -n claude-cluster
kubectl get services -n claude-cluster
```

## 🔧 運用・監視

### ログ管理

#### systemd環境
```bash
# サービスログ確認
sudo journalctl -u claude-coordinator -f
sudo journalctl -u claude-backend-agent -f

# ログローテーション設定
sudo tee /etc/logrotate.d/claude-cluster << EOF
/var/log/claude-cluster/*.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 0644 ubuntu ubuntu
}
EOF
```

#### Docker環境
```bash
# ログ確認
docker-compose logs -f coordinator
docker-compose logs -f agent-backend

# ログサイズ制限
# docker-compose.yml に追加
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### 監視とアラート

#### 基本監視スクリプト

```bash
#!/bin/bash
# healthcheck.sh

COORDINATOR_URL="http://192.168.1.10:8001"

# ヘルスチェック
check_health() {
    local url=$1
    local service=$2
    
    if curl -s -f "$url/health" > /dev/null; then
        echo "✅ $service: OK"
        return 0
    else
        echo "❌ $service: FAILED"
        return 1
    fi
}

# 各サービスをチェック
check_health "$COORDINATOR_URL" "Coordinator"
check_health "http://192.168.1.11:8002" "Backend Agent"
check_health "http://192.168.1.12:8003" "Frontend Agent"

# クラスター状態
echo "📊 Cluster Status:"
curl -s "$COORDINATOR_URL/api/cluster/status" | jq .
```

#### crontab設定

```bash
# 5分ごとにヘルスチェック実行
crontab -e

# 追加する行:
*/5 * * * * /home/ubuntu/scripts/healthcheck.sh >> /var/log/claude-healthcheck.log 2>&1
```

### バックアップ

#### 状態データバックアップ

```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backup/claude-cluster"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# 状態ファイルバックアップ
cp /home/ubuntu/claude-code-cluster/claude-code-cluster-poc/cluster_state.json \
   "$BACKUP_DIR/cluster_state_$DATE.json"

# 設定ファイルバックアップ
cp /home/ubuntu/claude-code-cluster/claude-code-cluster-poc/.env \
   "$BACKUP_DIR/env_$DATE.backup"

# 古いバックアップ削除（30日以上）
find "$BACKUP_DIR" -name "*.json" -mtime +30 -delete
find "$BACKUP_DIR" -name "*.backup" -mtime +30 -delete

echo "Backup completed: $DATE"
```

## 🔒 セキュリティ考慮事項

### ネットワークセキュリティ

```bash
# SSH鍵認証のみ許可
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# 不要なサービス停止
sudo systemctl disable apache2 2>/dev/null || true
sudo systemctl disable nginx 2>/dev/null || true
```

### API キー管理

```bash
# 環境変数での管理（推奨）
export GITHUB_TOKEN=$(cat /secure/github_token)
export ANTHROPIC_API_KEY=$(cat /secure/anthropic_key)

# ファイル権限設定
chmod 600 .env
chown ubuntu:ubuntu .env
```

### リバースプロキシ設定（nginx）

```nginx
# /etc/nginx/sites-available/claude-cluster
server {
    listen 80;
    server_name claude-cluster.example.com;
    
    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /webhook/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 📊 パフォーマンス最適化

### リソース使用量目安

| コンポーネント | CPU | メモリ | 説明 |
|---------------|-----|--------|------|
| Coordinator | 0.5-1.0 CPU | 1-2GB | タスク調整・API処理 |
| Backend Agent | 1.0-2.0 CPU | 2-4GB | コード生成（複雑） |
| Frontend Agent | 0.5-1.0 CPU | 1-2GB | UI コード生成 |
| Testing Agent | 0.5-1.5 CPU | 1-3GB | テスト生成 |
| DevOps Agent | 0.5-1.0 CPU | 1-2GB | 設定ファイル生成 |

### スケーリング指針

```bash
# CPU使用率が70%を超えた場合の追加ノード
docker-compose up -d --scale agent-backend=3

# メモリ使用率確認
docker stats --no-stream

# 適切なスケーリング判断
curl http://localhost:8001/api/queue/status
```

---

**注意**: 本ドキュメントはPoC環境での使用を想定しています。本番環境では、さらなるセキュリティ強化、監視システム、災害復旧計画が必要です。
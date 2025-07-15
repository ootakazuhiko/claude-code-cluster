# ITDO_ERP2プロジェクト用Podmanセットアップガイド

## 🐳 概要

このガイドは、ITDO_ERP2プロジェクトでPodmanを使用してデータレイヤー（PostgreSQL, Redis, Keycloak）を管理する方法を説明します。

## 📋 前提条件

- Podman 3.0以上がインストールされている
- podman-composeがインストールされている
- ITDO_ERP2プロジェクトが `/mnt/c/work/ITDO_ERP2` にクローンされている

## 🛠️ セットアップ手順

### 1. Podmanの確認

```bash
# Podmanのバージョン確認
podman --version

# Podmanの動作確認
podman info

# podman-composeのインストール確認
podman-compose --version

# インストールされていない場合
pip install podman-compose
```

### 2. ITDO_ERP2プロジェクトの準備

```bash
# プロジェクトディレクトリに移動
cd /mnt/c/work/ITDO_ERP2

# 現在のディレクトリ構造を確認
ls -la
# 以下が確認できること:
# - backend/
# - frontend/
# - infra/
# - scripts/
# - Makefile

# インフラ設定ファイルの確認
ls -la infra/
cat infra/compose-data.yaml
```

### 3. データレイヤーの起動

```bash
# 現在のディレクトリを確認
pwd
# 出力: /mnt/c/work/ITDO_ERP2

# データレイヤーコンテナの起動
podman-compose -f infra/compose-data.yaml up -d

# コンテナの状態確認
podman ps
podman-compose -f infra/compose-data.yaml ps

# ログの確認
podman-compose -f infra/compose-data.yaml logs
```

### 4. データベース接続確認

```bash
# PostgreSQL接続確認
podman exec -it $(podman ps -q --filter "name=postgres") psql -U itdo_user -d itdo_erp_dev

# PostgreSQL内でのテーブル確認
\dt
\q

# Redis接続確認
podman exec -it $(podman ps -q --filter "name=redis") redis-cli ping
# 出力: PONG

# Keycloak確認（ブラウザで）
echo "Keycloak Admin: http://localhost:8080"
echo "pgAdmin: http://localhost:8081"
```

### 5. 開発環境の起動

```bash
# 現在のディレクトリを確認
pwd
# 出力: /mnt/c/work/ITDO_ERP2

# バックエンドの起動（新しいターミナル）
cd backend
python3 -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# フロントエンドの起動（別のターミナル）
cd frontend
npm run dev
```

## 🔧 Makefileコマンド

ITDO_ERP2プロジェクトで使用できるMakefileコマンド：

```bash
# データレイヤーの起動
make start-data

# データレイヤーの停止
make stop-data

# データレイヤーの状態確認
make status

# 開発サーバーの起動
make dev

# テストの実行
make test

# セキュリティスキャン
make security-scan

# 型チェック
make typecheck

# リントの実行
make lint
```

## 📊 claude-code-clusterとの連携

### 1. エージェント起動時の設定

```bash
# claude-code-clusterディレクトリに移動
cd /tmp/claude-code-cluster

# 仮想環境をアクティベート
source venv/bin/activate

# ITDO_ERP2用エージェントの起動
python3 hooks/universal-agent-auto-loop-with-logging.py CC01 itdojp ITDO_ERP2 \
  --specialization "Backend & Database Specialist" \
  --labels backend database fastapi postgresql \
  --keywords python fastapi sqlalchemy postgresql redis podman \
  --max-iterations 5 \
  --cooldown 300
```

### 2. Podmanコンテナの監視

```bash
# コンテナの状態をリアルタイムで監視
watch podman ps

# リソース使用量の確認
podman stats

# 特定コンテナのログ監視
podman logs -f itdo_erp_postgres
podman logs -f itdo_erp_redis
```

## 🧪 テストと検証

### 1. データベーステスト

```bash
# ITDO_ERP2プロジェクトディレクトリで
cd /mnt/c/work/ITDO_ERP2

# バックエンドテストの実行
cd backend
python3 -m pytest tests/ -v

# 統合テストの実行
python3 -m pytest tests/integration/ -v

# データベースマイグレーションテスト
python3 -m alembic upgrade head
```

### 2. フロントエンドテスト

```bash
# フロントエンドテストの実行
cd frontend
npm test

# E2Eテストの実行
npm run test:e2e

# ビルドテスト
npm run build
```

## 🔒 セキュリティ設定

### 1. コンテナセキュリティ

```bash
# セキュリティスキャンの実行
podman run --rm -v $(pwd):/app -w /app \
  docker.io/aquasec/trivy:latest \
  fs --security-checks vuln,config .

# コンテナの脆弱性チェック
podman run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  docker.io/aquasec/trivy:latest \
  image postgres:15
```

### 2. ネットワークセキュリティ

```bash
# Podmanネットワークの確認
podman network ls

# ファイアウォール設定（必要に応じて）
sudo ufw allow 5432/tcp  # PostgreSQL
sudo ufw allow 6379/tcp  # Redis
sudo ufw allow 8080/tcp  # Keycloak
```

## 🚨 トラブルシューティング

### 1. コンテナが起動しない

```bash
# ログの詳細確認
podman-compose -f infra/compose-data.yaml logs --tail=50

# コンテナの再起動
podman-compose -f infra/compose-data.yaml restart

# 完全な再作成
podman-compose -f infra/compose-data.yaml down
podman-compose -f infra/compose-data.yaml up -d --force-recreate
```

### 2. ポートの競合

```bash
# ポートの使用状況確認
ss -tulpn | grep :5432
ss -tulpn | grep :6379
ss -tulpn | grep :8080

# プロセスの終了
sudo lsof -ti:5432 | xargs sudo kill -9
sudo lsof -ti:6379 | xargs sudo kill -9
```

### 3. データベース接続エラー

```bash
# 接続文字列の確認
echo "postgresql://itdo_user:itdo_password@localhost:5432/itdo_erp_dev"

# 手動接続テスト
psql -h localhost -p 5432 -U itdo_user -d itdo_erp_dev

# 権限の確認
podman exec -it $(podman ps -q --filter "name=postgres") \
  psql -U itdo_user -d itdo_erp_dev -c "SELECT current_user, current_database();"
```

### 4. パフォーマンス問題

```bash
# リソース使用量の確認
podman stats --no-stream

# システムリソースの確認
free -h
df -h
iostat -x 1
```

## 📋 定期メンテナンス

### 1. データベースのバックアップ

```bash
# PostgreSQLのバックアップ
podman exec -it $(podman ps -q --filter "name=postgres") \
  pg_dump -U itdo_user itdo_erp_dev > backup_$(date +%Y%m%d).sql

# バックアップの確認
ls -la backup_*.sql
```

### 2. ログのローテーション

```bash
# コンテナログのクリーンアップ
podman container prune -f

# システムの掃除
podman system prune -a -f
```

### 3. 更新

```bash
# イメージの更新
podman pull postgres:15
podman pull redis:7
podman pull quay.io/keycloak/keycloak:latest

# コンテナの再構築
podman-compose -f infra/compose-data.yaml up -d --force-recreate
```

## 📚 参考情報

### 重要なURL

- **バックエンドAPI**: http://localhost:8000
- **フロントエンド**: http://localhost:3000
- **Keycloak**: http://localhost:8080
- **pgAdmin**: http://localhost:8081

### 設定ファイル

- `infra/compose-data.yaml`: Podmanコンテナ設定
- `backend/app/core/config.py`: バックエンド設定
- `frontend/vite.config.ts`: フロントエンド設定

### ログファイル

- Podmanログ: `podman logs <container_name>`
- アプリケーションログ: `/mnt/c/work/ITDO_ERP2/logs/`
- claude-code-clusterログ: `/tmp/claude-code-logs/`

---

このガイドに従うことで、ITDO_ERP2プロジェクトでPodmanを使用したデータレイヤーの管理が可能になります。
# ITDO_ERP2用 Claude Code Cluster クイックスタート

## 🚀 5分でセットアップ

### 前提条件の確認
```bash
python3 --version    # 3.11+
podman --version     # 3.0+
gh --version         # 2.0+
```

### 1. リポジトリのクローンと依存関係インストール
```bash
# claude-code-clusterのセットアップ
cd /tmp
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster

# Python環境の準備
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. 認証設定
```bash
# GitHub認証
gh auth login

# 環境変数設定
cat > .env << 'EOF'
CLAUDE_API_KEY=your-claude-api-key-here
GITHUB_TOKEN=your-github-token-here
CLAUDE_MODEL=claude-3-5-sonnet-20241022
EOF
chmod 600 .env
```

### 3. ITDO_ERP2データレイヤー起動
```bash
# ITDO_ERP2プロジェクトでPodmanコンテナ起動
cd /mnt/c/work/ITDO_ERP2
podman-compose -f infra/compose-data.yaml up -d

# 起動確認
podman ps
```

### 4. ログディレクトリ作成
```bash
mkdir -p /tmp/claude-code-logs
chmod 755 /tmp/claude-code-logs
```

### 5. エージェント起動
```bash
# claude-code-clusterディレクトリに戻る
cd /tmp/claude-code-cluster
source venv/bin/activate

# CC01エージェント起動
python3 hooks/universal-agent-auto-loop-with-logging.py CC01 itdojp ITDO_ERP2 \
  --specialization "Backend & Database Specialist" \
  --labels backend database fastapi postgresql \
  --max-iterations 5 \
  --cooldown 300 &

# ログ確認
python3 hooks/view-command-logs.py --agent CC01-ITDO_ERP2 --follow
```

## 🔧 よくある問題と解決法

### エラー1: requirements.txtが見つからない
```bash
# 解決方法：requirements.txtを作成
cd /tmp/claude-code-cluster
cat > requirements.txt << 'EOF'
requests>=2.31.0
aiohttp>=3.9.0
python-dotenv>=1.0.0
click>=8.1.0
pydantic>=2.0.0
sqlalchemy>=2.0.0
PyGithub>=1.59.0
colorama>=0.4.6
EOF
```

### エラー2: Podmanコンテナが起動しない
```bash
# 解決方法：コンテナの再起動
cd /mnt/c/work/ITDO_ERP2
podman-compose -f infra/compose-data.yaml down
podman-compose -f infra/compose-data.yaml up -d
```

### エラー3: 権限エラー
```bash
# 解決方法：権限の修正
cd /tmp/claude-code-cluster
chmod +x hooks/*.py
chmod +x scripts/*.sh
```

## 📊 動作確認

### 1. エージェントの状態確認
```bash
# プロセス確認
ps aux | grep "universal-agent"

# ログ確認
python3 hooks/view-command-logs.py --stats
```

### 2. ITDO_ERP2の動作確認
```bash
# データベース接続確認
podman exec -it $(podman ps -q --filter "name=postgres") psql -U itdo_user -d itdo_erp_dev -c "SELECT version();"

# Redis接続確認
podman exec -it $(podman ps -q --filter "name=redis") redis-cli ping
```

### 3. 統合テスト
```bash
# バックエンドテスト
cd /mnt/c/work/ITDO_ERP2/backend
python3 -m pytest tests/ -v

# フロントエンドテスト
cd /mnt/c/work/ITDO_ERP2/frontend
npm test
```

## 📋 次のステップ

1. **複数エージェントの起動**: CC02, CC03エージェントも起動
2. **モニタリング**: リアルタイム監視の設定
3. **カスタマイズ**: プロジェクト固有の設定調整

詳細な手順は `DETAILED_INSTALLATION_GUIDE.md` を参照してください。
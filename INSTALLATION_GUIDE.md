# Claude Code エージェントシステム導入ガイド

## 目次
1. [システム概要](#システム概要)
2. [システム要件](#システム要件)
3. [事前準備](#事前準備)
4. [インストール手順](#インストール手順)
5. [初期設定](#初期設定)
6. [動作確認](#動作確認)
7. [運用開始](#運用開始)
8. [よくある質問](#よくある質問)

## システム概要

Claude Code エージェントシステムは、GitHub Issues を介して自動的にタスクを処理する分散型開発支援システムです。

### アーキテクチャ
```
GitHub Issues → Claude Code Agents → Task Execution → GitHub Comments
     ↑                                                        ↓
     └────────────────── Continuous Loop ────────────────────┘
```

### エージェント種別
- **CC01**: Frontend エージェント（React, TypeScript, UI/UX）
- **CC02**: Backend エージェント（Python, FastAPI, データベース）
- **CC03**: Infrastructure エージェント（CI/CD, Docker, 自動化）

## システム要件

### ハードウェア要件
- **CPU**: 4コア以上（推奨: 8コア）
- **メモリ**: 8GB以上（推奨: 16GB）
- **ストレージ**: 50GB以上の空き容量
- **ネットワーク**: 安定したインターネット接続

### ソフトウェア要件
- **OS**: Ubuntu 20.04+ / macOS 12+ / Windows 10+ (WSL2)
- **Claude Code CLI**: 最新版
- **Git**: 2.25+
- **GitHub CLI**: 2.0+
- **Bash**: 4.0+
- **Python**: 3.8+（CC02用）
- **Node.js**: 18+（CC01用）

### 必要なアカウント・トークン
- **Anthropic API Key**: Claude API アクセス用
- **GitHub Personal Access Token**: 以下のスコープが必要
  - `repo`: リポジトリへのフルアクセス
  - `workflow`: GitHub Actions の操作
  - `write:org`: Organization の読み取り（必要に応じて）

## 事前準備

### 1. Claude Code CLI のインストール

```bash
# Claude Code CLI のインストール（公式手順に従う）
# 例: macOS の場合
brew install claude-code

# または、直接ダウンロード
curl -L https://claude.ai/download/claude-code-cli | bash
```

### 2. GitHub CLI のインストール

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install gh

# macOS
brew install gh

# その他のOS
# https://cli.github.com/ を参照
```

### 3. API キーの取得

#### Anthropic API Key
1. https://console.anthropic.com/ にアクセス
2. API Keys セクションに移動
3. 新しい API キーを生成
4. 安全な場所に保存

#### GitHub Personal Access Token
1. GitHub Settings → Developer settings → Personal access tokens
2. "Generate new token (classic)" をクリック
3. 必要なスコープを選択:
   - `repo` (Full control of private repositories)
   - `workflow` (Update GitHub Action workflows)
4. トークンを生成して保存

### 4. 認証設定

```bash
# GitHub CLI の認証
gh auth login
# → GitHub.com を選択
# → HTTPS を選択
# → トークンで認証
# → 作成したトークンを貼り付け

# 認証確認
gh auth status
```

## インストール手順

### Step 1: リポジトリのクローン

```bash
# 作業ディレクトリの作成
mkdir -p ~/claude-agents
cd ~/claude-agents

# claude-code-cluster のクローン
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster
```

### Step 2: プロジェクトへのファイルコピー

```bash
# プロジェクトディレクトリに移動
cd /path/to/your/project

# 必要なファイルをコピー
cp -r ~/claude-agents/claude-code-cluster/scripts ./
cp -r ~/claude-agents/claude-code-cluster/.claude-code ./
cp ~/claude-agents/claude-code-cluster/claude-code-config.yaml ./
cp ~/claude-agents/claude-code-cluster/start-agent.sh ./
cp ~/claude-agents/claude-code-cluster/stop-agent.sh ./

# 実行権限の付与
chmod +x scripts/agent/*.sh
chmod +x .claude-code/hooks/*.sh
chmod +x *.sh
```

### Step 3: ディレクトリ構造の作成

```bash
# エージェント用ディレクトリの作成
mkdir -p .agent/logs
mkdir -p .agent/state
mkdir -p .agent/instructions

# .gitignore への追加
echo ".agent/" >> .gitignore
echo ".env" >> .gitignore
```

## 初期設定

### 1. 環境変数の設定

```bash
# .env ファイルの作成
cat > .env << 'EOF'
# API Keys
export ANTHROPIC_API_KEY="sk-ant-api03-xxxxx"
export GITHUB_TOKEN="ghp_xxxxx"

# Project Settings
export WORKSPACE="$(pwd)"
export GITHUB_REPOSITORY="owner/repo"  # あなたのリポジトリに変更

# Agent Labels
export CC01_LABEL="cc01"
export CC02_LABEL="cc02"
export CC03_LABEL="cc03"

# Optional Settings
export CLAUDE_MODEL="claude-3-opus-20240229"
export LOG_LEVEL="info"
EOF

# 環境変数の読み込み
source .env
```

### 2. 設定ファイルのカスタマイズ

```bash
# claude-code-config.yaml を編集
vi claude-code-config.yaml
```

主な設定項目：
```yaml
# エージェント名とタイプを環境に合わせて調整
agent:
  name: "${AGENT_NAME:-CC01}"
  type: "${AGENT_TYPE:-frontend}"
  
  # ワークスペースパスの確認
  workspace:
    base: "${WORKSPACE:-/home/work/project}"
    
  # GitHubリポジトリの設定
  github:
    repository: "${GITHUB_REPOSITORY:-owner/repo}"
    labels:
      - "${ISSUE_LABEL:-cc01}"
```

### 3. GitHub ラベルの作成

```bash
# プロジェクトリポジトリでラベルを作成
gh label create cc01 --description "Frontend tasks for CC01" --color "7057ff"
gh label create cc02 --description "Backend tasks for CC02" --color "008672"
gh label create cc03 --description "Infrastructure tasks for CC03" --color "d876e3"

# 優先度ラベル（オプション）
gh label create "priority-high" --color "d73a4a"
gh label create "priority-low" --color "0e8a16"
```

## 動作確認

### 1. 環境チェックスクリプト

```bash
# check-environment.sh
cat > check-environment.sh << 'EOF'
#!/bin/bash
echo "=== Environment Check ==="

# Check commands
echo -n "Claude Code CLI: "
command -v claude-code >/dev/null && echo "✓ Installed" || echo "✗ Not found"

echo -n "GitHub CLI: "
command -v gh >/dev/null && echo "✓ Installed" || echo "✗ Not found"

echo -n "Git: "
command -v git >/dev/null && echo "✓ Installed" || echo "✗ Not found"

# Check API keys
echo -n "ANTHROPIC_API_KEY: "
[ -n "$ANTHROPIC_API_KEY" ] && echo "✓ Set" || echo "✗ Not set"

echo -n "GITHUB_TOKEN: "
[ -n "$GITHUB_TOKEN" ] && echo "✓ Set" || echo "✗ Not set"

# Check GitHub auth
echo -n "GitHub Auth: "
gh auth status >/dev/null 2>&1 && echo "✓ Authenticated" || echo "✗ Not authenticated"

# Check directories
echo -n "Agent directories: "
[ -d ".agent/logs" ] && [ -d ".agent/state" ] && echo "✓ Created" || echo "✗ Missing"

# Check scripts
echo -n "Agent scripts: "
[ -x "scripts/agent/agent-loop.sh" ] && echo "✓ Executable" || echo "✗ Not found/executable"
EOF

chmod +x check-environment.sh
./check-environment.sh
```

### 2. テストタスクの実行

```bash
# シンプルなテストタスクを作成
gh issue create \
  --title "[CC01] Installation Test" \
  --label "cc01" \
  --body "Test task for installation verification.

Task: Create a file named 'installation-test.txt' with content 'Installation successful!'

This is an automated test to verify the agent system is working correctly."

# エージェントを起動（別ターミナル推奨）
./start-agent.sh CC01 cc01

# ログを監視
tail -f .agent/logs/*.log

# 結果を確認
ls -la installation-test.txt
gh issue list --label cc01
```

## 運用開始

### 1. Production 設定

```bash
# production.env
cat > production.env << 'EOF'
# Production settings
export LOG_LEVEL="warning"
export CLAUDE_CODE_TIMEOUT=3600
export MAX_ITERATIONS=0  # 無限ループ
export LOOP_DELAY=60     # 60秒間隔
EOF
```

### 2. 複数エージェントの起動

```bash
# Screen を使用した例
screen -S cc01 -dm bash -c "source .env && ./start-agent.sh CC01 cc01"
screen -S cc02 -dm bash -c "source .env && ./start-agent.sh CC02 cc02"
screen -S cc03 -dm bash -c "source .env && ./start-agent.sh CC03 cc03"

# 状態確認
screen -ls
```

### 3. サービス化（systemd）

```bash
# /etc/systemd/system/claude-agent@.service
sudo tee /etc/systemd/system/claude-agent@.service << EOF
[Unit]
Description=Claude Code Agent %i
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PWD
EnvironmentFile=$PWD/.env
ExecStart=$PWD/start-agent.sh %i %i
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# サービスの有効化と起動
sudo systemctl daemon-reload
sudo systemctl enable claude-agent@cc01 claude-agent@cc02 claude-agent@cc03
sudo systemctl start claude-agent@cc01 claude-agent@cc02 claude-agent@cc03
```

### 4. 監視とログ

```bash
# 監視ダッシュボードスクリプト
cat > monitor-dashboard.sh << 'EOF'
#!/bin/bash
while true; do
  clear
  echo "=== Claude Agent Dashboard ==="
  echo "Time: $(date)"
  echo ""
  echo "Agent Status:"
  systemctl status claude-agent@cc01 --no-pager | grep Active
  systemctl status claude-agent@cc02 --no-pager | grep Active
  systemctl status claude-agent@cc03 --no-pager | grep Active
  echo ""
  echo "Recent Activity:"
  tail -n 3 .agent/logs/agent-loop.log
  echo ""
  echo "Open Issues:"
  gh issue list --label "cc01,cc02,cc03" --limit 5
  sleep 10
done
EOF

chmod +x monitor-dashboard.sh
```

## よくある質問

### Q: エージェントが Issue を処理しない
A: 以下を確認してください：
- Issue に正しいラベル（cc01/cc02/cc03）が付いているか
- エージェントが起動しているか（`ps aux | grep start-agent`）
- ログにエラーが出ていないか（`.agent/logs/`）

### Q: Claude Code が見つからないエラー
A: Claude Code CLI が正しくインストールされ、PATH に含まれているか確認：
```bash
which claude-code
echo $PATH
```

### Q: API レート制限エラー
A: 以下の対策を検討：
- `LOOP_DELAY` を増やす（例: 120秒）
- 同時実行エージェント数を減らす
- API キーの使用状況を確認

### Q: 複数プロジェクトでの運用
A: 各プロジェクトで別々の設定：
```bash
# プロジェクトごとに異なるラベルを使用
# Project A: cc01-proj-a, cc02-proj-a, cc03-proj-a
# Project B: cc01-proj-b, cc02-proj-b, cc03-proj-b
```

## 次のステップ

1. [OPERATION_GUIDE.md](./OPERATION_GUIDE.md) - 日常運用ガイド
2. [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - トラブルシューティング
3. [ADVANCED_CONFIG.md](./ADVANCED_CONFIG.md) - 高度な設定

## サポート

問題が発生した場合：
1. ログファイルを確認（`.agent/logs/`）
2. [GitHub Issues](https://github.com/ootakazuhiko/claude-code-cluster/issues) で報告
3. エラーメッセージと環境情報を含めてください
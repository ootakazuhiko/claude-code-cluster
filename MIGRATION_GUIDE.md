# Claude Code エージェントシステム移行ガイド

## 概要
このドキュメントは、現行の Claude Code 運用から新しいエージェントシステムへの移行手順を説明します。

## 前提条件

### 現行システムの想定
- Claude Code を手動またはスクリプトで運用中
- GitHub Issues を手動で確認・対応
- 複数のエージェント（CC01/CC02/CC03）を個別に運用

### 必要な環境
- Claude Code CLI がインストール済み
- GitHub CLI (`gh`) がインストール済み
- Git がインストール済み
- Bash シェル環境（Linux/macOS/WSL）

## 移行手順

### Phase 1: 準備（システム稼働中）

#### 1.1 リポジトリのクローン
```bash
# 作業ディレクトリに移動
cd /home/work

# claude-code-cluster リポジトリをクローン
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster
```

#### 1.2 環境変数の準備
```bash
# .env ファイルを作成
cat > .env << 'EOF'
# Claude API キー
export ANTHROPIC_API_KEY="sk-ant-..."

# GitHub トークン（repo, workflow スコープが必要）
export GITHUB_TOKEN="ghp_..."

# プロジェクトのワークスペース
export WORKSPACE="/home/work/ITDO_ERP2"

# エージェント設定
export CC01_LABEL="cc01"
export CC02_LABEL="cc02"
export CC03_LABEL="cc03"
EOF

# 環境変数を読み込み
source .env
```

#### 1.3 動作確認
```bash
# GitHub 認証確認
gh auth status

# Claude Code 動作確認
claude-code --version

# ワークスペース確認
ls -la $WORKSPACE
```

### Phase 2: 現行システムの停止

#### 2.1 実行中のタスクの確認
```bash
# 現在実行中の Claude Code プロセスを確認
ps aux | grep claude-code

# 実行中の GitHub Actions を確認
gh workflow list --all
gh run list --limit 5
```

#### 2.2 現行システムの停止
```bash
# Claude Code プロセスの停止
pkill -f claude-code

# 自動化スクリプトの停止（存在する場合）
# systemctl stop claude-agent  # systemd の場合
# supervisorctl stop all       # supervisor の場合
```

#### 2.3 作業状態の保存
```bash
# 現在の作業をコミット
cd $WORKSPACE
git add -A
git commit -m "WIP: Migrating to new agent system"
git push
```

### Phase 3: 新システムのセットアップ

#### 3.1 エージェントスクリプトのコピー
```bash
# claude-code-cluster から必要なファイルをコピー
cd /home/work/claude-code-cluster

# スクリプトディレクトリをプロジェクトにコピー
cp -r scripts $WORKSPACE/
cp -r .claude-code $WORKSPACE/
cp claude-code-config.yaml $WORKSPACE/
cp start-agent.sh $WORKSPACE/
cp stop-agent.sh $WORKSPACE/

# 実行権限を付与
chmod +x $WORKSPACE/scripts/agent/*.sh
chmod +x $WORKSPACE/.claude-code/hooks/*.sh
chmod +x $WORKSPACE/*.sh
```

#### 3.2 設定ファイルの調整
```bash
cd $WORKSPACE

# claude-code-config.yaml を編集
# プロジェクト固有の設定に調整
vi claude-code-config.yaml

# 主な調整項目：
# - workspace.base: プロジェクトパスの確認
# - github.repository: リポジトリ名の設定
# - agent.name: エージェント名の設定
```

#### 3.3 ディレクトリ構造の準備
```bash
# エージェント用ディレクトリを作成
mkdir -p $WORKSPACE/.agent/logs
mkdir -p $WORKSPACE/.agent/state
mkdir -p $WORKSPACE/.agent/instructions

# .gitignore に追加
echo ".agent/" >> $WORKSPACE/.gitignore
```

### Phase 4: 新システムの起動

#### 4.1 単一エージェントでのテスト
```bash
cd $WORKSPACE

# CC01（Frontend）エージェントを起動
./start-agent.sh CC01 cc01

# 別ターミナルで動作確認
tail -f .agent/logs/agent-startup.log
tail -f .agent/logs/claude-code-hook.log
```

#### 4.2 テストタスクの作成
```bash
# テスト用 Issue を作成
gh issue create \
  --title "[CC01] Test Migration Task" \
  --label "cc01" \
  --body "This is a test task to verify the new agent system.
  
Task: Create a simple test file at src/test-migration.txt with content 'Migration successful!'"

# エージェントの動作を監視
tail -f .agent/logs/*.log
```

#### 4.3 動作確認
```bash
# Issue のコメントを確認
gh issue view <issue-number>

# ファイルが作成されたか確認
ls -la src/test-migration.txt
```

### Phase 5: 全エージェントの展開

#### 5.1 複数エージェントの起動
```bash
# 各エージェントを別々のターミナルまたは screen/tmux で起動

# Terminal 1: Frontend エージェント
cd $WORKSPACE
./start-agent.sh CC01 cc01

# Terminal 2: Backend エージェント
cd $WORKSPACE
./start-agent.sh CC02 cc02

# Terminal 3: Infrastructure エージェント
cd $WORKSPACE
./start-agent.sh CC03 cc03
```

#### 5.2 systemd サービスとしての設定（オプション）
```bash
# サービスファイルを作成
sudo tee /etc/systemd/system/claude-agent-cc01.service << EOF
[Unit]
Description=Claude Code Agent CC01
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$WORKSPACE
Environment="ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
Environment="GITHUB_TOKEN=$GITHUB_TOKEN"
ExecStart=$WORKSPACE/start-agent.sh CC01 cc01
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# サービスを有効化・起動
sudo systemctl daemon-reload
sudo systemctl enable claude-agent-cc01
sudo systemctl start claude-agent-cc01
```

### Phase 6: 移行後の確認

#### 6.1 システム状態の確認
```bash
# エージェントプロセスの確認
ps aux | grep -E "(claude-code|agent-loop)"

# ログの確認
tail -f $WORKSPACE/.agent/logs/*.log

# GitHub Issues の処理状況
gh issue list --label "cc01,cc02,cc03" --state open
```

#### 6.2 監視スクリプトの作成
```bash
# monitor-agents.sh
cat > $WORKSPACE/monitor-agents.sh << 'EOF'
#!/bin/bash
echo "=== Agent Status ==="
echo "CC01: $(pgrep -f "start-agent.sh CC01" > /dev/null && echo "Running" || echo "Stopped")"
echo "CC02: $(pgrep -f "start-agent.sh CC02" > /dev/null && echo "Running" || echo "Stopped")"
echo "CC03: $(pgrep -f "start-agent.sh CC03" > /dev/null && echo "Running" || echo "Stopped")"
echo ""
echo "=== Recent Activity ==="
tail -n 5 $WORKSPACE/.agent/logs/agent-loop.log 2>/dev/null
echo ""
echo "=== Open Issues ==="
gh issue list --label "cc01,cc02,cc03" --state open --limit 5
EOF

chmod +x $WORKSPACE/monitor-agents.sh
```

## トラブルシューティング

### エージェントが起動しない
```bash
# 環境変数の確認
echo $ANTHROPIC_API_KEY
echo $GITHUB_TOKEN

# ログの確認
cat .agent/logs/agent-startup.log
```

### タスクが処理されない
```bash
# Hook の動作確認
CLAUDE_CODE_WORKSPACE=$WORKSPACE \
CLAUDE_CODE_AGENT_NAME=CC01 \
CLAUDE_CODE_ISSUE_LABEL=cc01 \
.claude-code/hooks/on-idle.sh

# Issue のラベル確認
gh issue list --label cc01
```

### エージェントの再起動
```bash
# 停止
./stop-agent.sh CC01

# 起動
./start-agent.sh CC01 cc01
```

## ロールバック手順

新システムに問題がある場合：

```bash
# 1. 新システムの停止
./stop-agent.sh CC01
./stop-agent.sh CC02
./stop-agent.sh CC03

# 2. エージェントファイルの退避
mv $WORKSPACE/.agent $WORKSPACE/.agent.backup
mv $WORKSPACE/scripts $WORKSPACE/scripts.backup

# 3. 旧システムの再起動
# （旧システムの起動コマンド）
```

## 移行完了チェックリスト

- [ ] 環境変数が正しく設定されている
- [ ] GitHub 認証が有効
- [ ] Claude Code が正常に動作
- [ ] エージェントスクリプトがコピーされている
- [ ] 必要なディレクトリが作成されている
- [ ] 少なくとも1つのエージェントが起動している
- [ ] テストタスクが正常に処理された
- [ ] ログが正しく出力されている
- [ ] GitHub Issue へのコメントが投稿されている
- [ ] 監視スクリプトが動作している

## 次のステップ

移行が完了したら、[OPERATION_GUIDE.md](./OPERATION_GUIDE.md) を参照して日常運用を開始してください。
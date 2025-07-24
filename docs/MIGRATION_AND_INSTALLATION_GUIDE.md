# Claude Code Cluster 導入・移行ガイド

## 目次

1. [はじめに](#はじめに)
2. [旧システムのアンインストール](#旧システムのアンインストール)
3. [新システムの導入](#新システムの導入)
4. [動作確認](#動作確認)
5. [トラブルシューティング](#トラブルシューティング)

## はじめに

このガイドでは、既存のClaude Code Clusterシステムから、GitHub通信ベースの新システムへの移行手順を説明します。

### 新旧システムの違い

| 項目 | 旧システム | 新システム |
|------|----------|----------|
| **通信方式** | HTTP Webhook（ローカル） | GitHub API（インターネット） |
| **ネットワーク** | 同一ネットワーク必須 | インターネット接続のみ |
| **ポート** | 8881-8883使用 | ポート不要 |
| **インストール** | 複雑（Router、Hook等） | シンプル（Pythonスクリプト） |

## 旧システムのアンインストール

### 1. 実行中のサービスの停止

```bash
# すべてのエージェントとルーターを停止
claude-cluster stop

# systemdサービスの停止（設定している場合）
systemctl --user stop claude-router
systemctl --user stop claude-cc01
systemctl --user stop claude-cc02
systemctl --user stop claude-cc03

# tmuxセッションの確認と終了
tmux ls
tmux kill-session -t cc01
tmux kill-session -t cc02
tmux kill-session -t cc03
tmux kill-session -t manager
```

### 2. systemdサービスの無効化

```bash
# サービスの無効化
systemctl --user disable claude-router
systemctl --user disable claude-cc01
systemctl --user disable claude-cc02
systemctl --user disable claude-cc03

# サービスファイルの削除
rm -f ~/.config/systemd/user/claude-*.service
systemctl --user daemon-reload
```

### 3. ポートの解放確認

```bash
# 使用中のポートを確認
sudo netstat -tlnp | grep -E '888[0-9]'

# プロセスが残っている場合は終了
sudo pkill -f "central-router"
sudo pkill -f "webhook-server"
```

### 4. 旧ファイルのバックアップと削除

```bash
# 作業データのバックアップ（必要に応じて）
cd /home/claude-cluster
tar -czf ~/claude-cluster-backup-$(date +%Y%m%d).tar.gz agents/*/workspace

# 設定ファイルのバックアップ
cp -r /home/claude-cluster/config ~/claude-cluster-config-backup

# 旧システムファイルの削除
sudo rm -rf /home/claude-cluster/scripts/management/central-router.py
sudo rm -rf /home/claude-cluster/hooks/
sudo rm -rf /home/claude-cluster/agents/*/hooks/

# グローバルコマンドの削除
sudo rm -f /usr/local/bin/claude-cluster
```

### 5. 環境変数のクリーンアップ

```bash
# .bashrcから旧設定を削除
nano ~/.bashrc

# 以下の行を削除またはコメントアウト
# export CLUSTER_HOME="/home/claude-cluster"
# export PATH="$CLUSTER_HOME/scripts/management:$PATH"

# 環境をリロード
source ~/.bashrc
```

## 新システムの導入

### 1. 前提条件の確認

```bash
# Pythonバージョン確認（3.8以上必要）
python3 --version

# pipの確認
pip3 --version

# Gitの確認
git --version

# 必要なパッケージのインストール
pip3 install --user PyGithub httpx
```

### 2. GitHubトークンの準備

1. GitHubにログイン
2. Settings → Developer settings → Personal access tokens → Tokens (classic)
3. "Generate new token"をクリック
4. 以下のスコープを選択:
   - `repo` (Full control of private repositories)
   - `workflow` (Update GitHub Action workflows) ※オプション
5. トークンを生成してコピー

### 3. リポジトリのクローン

```bash
# 作業ディレクトリの作成
mkdir -p ~/claude-workers
cd ~/claude-workers

# リポジトリのクローン
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster
```

### 4. 環境設定

```bash
# 環境変数の設定
cat >> ~/.bashrc << 'EOF'

# Claude Code Cluster (GitHub-based)
export GITHUB_TOKEN="ghp_your_token_here"  # ← あなたのトークンに置き換え
export GITHUB_REPO="ootakazuhiko/claude-code-cluster"
export CLAUDE_WORKERS_HOME="$HOME/claude-workers"

EOF

# 環境をリロード
source ~/.bashrc
```

### 5. ワーカー用ディレクトリの作成

```bash
# 各ワーカー用のディレクトリ作成
mkdir -p ~/claude-workers/{cc01,cc02,cc03,manager}/workspace
mkdir -p ~/.claude/state

# 実行権限の付与
chmod +x ~/claude-workers/claude-code-cluster/scripts/github-worker-optimized.py
chmod +x ~/claude-workers/claude-code-cluster/scripts/start-github-worker.sh
```

### 6. ワーカーの起動

#### 方法1: 個別に起動（推奨）

```bash
# 別々のターミナルで実行
# Terminal 1 - Frontend Worker
cd ~/claude-workers/cc01
WORKER_NAME=CC01 WORKER_LABEL=cc01 python3 ../claude-code-cluster/scripts/github-worker-optimized.py

# Terminal 2 - Backend Worker
cd ~/claude-workers/cc02
WORKER_NAME=CC02 WORKER_LABEL=cc02 python3 ../claude-code-cluster/scripts/github-worker-optimized.py

# Terminal 3 - Infrastructure Worker
cd ~/claude-workers/cc03
WORKER_NAME=CC03 WORKER_LABEL=cc03 python3 ../claude-code-cluster/scripts/github-worker-optimized.py
```

#### 方法2: tmuxを使用

```bash
# tmuxセッションで起動
tmux new-session -d -s cc01-github -c ~/claude-workers/cc01 \
  "WORKER_NAME=CC01 WORKER_LABEL=cc01 python3 ../claude-code-cluster/scripts/github-worker-optimized.py"

tmux new-session -d -s cc02-github -c ~/claude-workers/cc02 \
  "WORKER_NAME=CC02 WORKER_LABEL=cc02 python3 ../claude-code-cluster/scripts/github-worker-optimized.py"

tmux new-session -d -s cc03-github -c ~/claude-workers/cc03 \
  "WORKER_NAME=CC03 WORKER_LABEL=cc03 python3 ../claude-code-cluster/scripts/github-worker-optimized.py"

# セッション確認
tmux ls
```

#### 方法3: systemdサービスとして設定（オプション）

```bash
# サービスファイルの作成
cat > ~/.config/systemd/user/claude-worker-cc01.service << EOF
[Unit]
Description=Claude Worker CC01 (GitHub-based)
After=network.target

[Service]
Type=simple
WorkingDirectory=$HOME/claude-workers/cc01
Environment="GITHUB_TOKEN=$GITHUB_TOKEN"
Environment="GITHUB_REPO=$GITHUB_REPO"
Environment="WORKER_NAME=CC01"
Environment="WORKER_LABEL=cc01"
ExecStart=/usr/bin/python3 $HOME/claude-workers/claude-code-cluster/scripts/github-worker-optimized.py
Restart=on-failure
RestartSec=60

[Install]
WantedBy=default.target
EOF

# 同様にCC02、CC03用も作成...

# サービスの有効化と起動
systemctl --user daemon-reload
systemctl --user enable claude-worker-cc01
systemctl --user start claude-worker-cc01
```

## 動作確認

### 1. ワーカーの状態確認

```bash
# ログ確認（tmux使用時）
tmux attach-session -t cc01-github

# ログ確認（直接実行時）
# 各ワーカーのターミナルでログが表示される

# systemdサービスのログ
journalctl --user -u claude-worker-cc01 -f
```

### 2. テストIssueの作成

```bash
# GitHub CLIでテストIssue作成
gh issue create \
  --repo "$GITHUB_REPO" \
  --title "Test: Frontend task for CC01" \
  --body "This is a test task for the frontend worker" \
  --label "cc01"

# ブラウザで確認
open "https://github.com/$GITHUB_REPO/issues"
```

### 3. 動作確認項目

- [ ] ワーカーがIssueを検出
- [ ] ワーカーが自分自身をアサイン
- [ ] "in-progress"ラベルが追加される
- [ ] 進捗コメントが投稿される
- [ ] 完了時に"completed"ラベルが追加される

## トラブルシューティング

### 問題: ワーカーが起動しない

```bash
# Pythonパスの確認
which python3

# 依存関係の再インストール
pip3 install --user --upgrade PyGithub httpx

# 権限の確認
ls -la ~/claude-workers/claude-code-cluster/scripts/
```

### 問題: GitHubトークンエラー

```bash
# トークンの確認
echo $GITHUB_TOKEN

# トークンの権限確認（GitHub APIで）
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# 正しいトークンを設定
export GITHUB_TOKEN="ghp_correct_token_here"
```

### 問題: Issueが検出されない

```bash
# ラベルの確認
gh label list --repo "$GITHUB_REPO"

# 必要なラベルの作成
gh label create cc01 --description "Frontend tasks" --color "0e8a16"
gh label create cc02 --description "Backend tasks" --color "1d76db"
gh label create cc03 --description "Infrastructure tasks" --color "5319e7"
```

### 問題: レート制限エラー

```bash
# 現在のレート制限を確認
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/rate_limit

# ポーリング間隔の調整（環境変数）
export POLL_INTERVAL=600  # 10分に延長
```

## 移行完了チェックリスト

- [ ] 旧システムの完全停止
- [ ] ポート8881-8883が解放されている
- [ ] GitHubトークンの設定
- [ ] 新システムのワーカー起動
- [ ] テストIssueでの動作確認
- [ ] ログに異常がない

## 次のステップ

1. **マネージャーの設定**
   ```bash
   # マネージャー用のスクリプトも同様に実行可能
   cd ~/claude-workers/manager
   WORKER_NAME=MANAGER python3 ../claude-code-cluster/scripts/github-manager.py
   ```

2. **カスタマイズ**
   - ポーリング間隔の調整
   - カスタムラベルの追加
   - 処理ロジックのカスタマイズ

3. **監視設定**
   - ログローテーション
   - アラート設定
   - メトリクス収集

## サポート

問題が発生した場合:
1. [GitHub Issues](https://github.com/ootakazuhiko/claude-code-cluster/issues)で報告
2. ログファイルを添付
3. 環境情報（OS、Pythonバージョン等）を記載
# 別PCで単一ワーカー実行セットアップ

各PCで1つのワーカーだけを動作させるための手順です。

## 1. 個別ワーカースクリプトの作成

インストール後、以下を実行して個別起動スクリプトを作成します：

```bash
cd ~/claude-workers
curl -sSL https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/scripts/create-single-worker-scripts.sh | bash
```

または、ダウンロードして実行：
```bash
wget https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/scripts/create-single-worker-scripts.sh
chmod +x create-single-worker-scripts.sh
./create-single-worker-scripts.sh
```

## 2. 各PCでの使用方法

### PC1: CC01専用として使用する場合
```bash
cd ~/claude-workers

# CC01を起動
./start-cc01.sh

# 状態確認
./check-single-worker.sh cc01

# ログ確認（リアルタイム）
tmux attach -t cc01-github

# ログから抜ける: Ctrl+B を押してから D を押す

# CC01を停止
./stop-cc01.sh
```

### PC2: CC02専用として使用する場合
```bash
cd ~/claude-workers

# CC02を起動
./start-cc02.sh

# 状態確認
./check-single-worker.sh cc02

# ログ確認
tmux attach -t cc02-github

# CC02を停止
./stop-cc02.sh
```

### PC3: CC03専用として使用する場合
```bash
cd ~/claude-workers

# CC03を起動
./start-cc03.sh

# 状態確認
./check-single-worker.sh cc03

# ログ確認
tmux attach -t cc03-github

# CC03を停止
./stop-cc03.sh
```

## 3. 作成される個別スクリプト一覧

インストール後、`~/claude-workers/` に以下のスクリプトが作成されます：

### 起動スクリプト
- `start-cc01.sh` - CC01専用起動
- `start-cc02.sh` - CC02専用起動  
- `start-cc03.sh` - CC03専用起動

### 停止スクリプト
- `stop-cc01.sh` - CC01停止
- `stop-cc02.sh` - CC02停止
- `stop-cc03.sh` - CC03停止

### 状態確認スクリプト
- `check-single-worker.sh cc01` - CC01状態確認
- `check-single-worker.sh cc02` - CC02状態確認
- `check-single-worker.sh cc03` - CC03状態確認

### 既存の全体管理スクリプト
- `start-all-workers.sh` - 全ワーカー起動（1台のPCで全て実行する場合）
- `stop-all-workers.sh` - 全ワーカー停止
- `check-status.sh` - 全体状態確認

## 4. 運用のポイント

### 各PCでの推奨構成
- **PC1**: CC01のみ実行（バックエンド開発担当）
- **PC2**: CC02のみ実行（フロントエンド開発担当）
- **PC3**: CC03のみ実行（インフラ・DevOps担当）

### ログ監視
```bash
# ワーカーのログをリアルタイムで確認
tmux attach -t cc01-github  # CC01の場合

# ログから抜ける（ワーカーは動き続ける）
# Ctrl+B を押してから D を押す
```

### 自動起動設定（オプション）
各PCでワーカーを自動起動したい場合：

```bash
# crontabに追加（再起動時に自動起動）
crontab -e

# 以下の行を追加（CC01の場合）
@reboot cd $HOME/claude-workers && ./start-cc01.sh
```

## 5. GitHub Issues連携

各ワーカーは以下のGitHubラベルに応じてタスクを受け取ります：

- **CC01**: `cc01` ラベルの付いたIssue
- **CC02**: `cc02` ラベルの付いたIssue  
- **CC03**: `cc03` ラベルの付いたIssue

### テスト用Issueの作成
```bash
# CC01用テストIssue
./test-worker.sh cc01

# CC02用テストIssue
./test-worker.sh cc02

# CC03用テストIssue  
./test-worker.sh cc03
```

## 6. トラブルシューティング

### ワーカーが起動しない場合
```bash
# 仮想環境の確認
./uv-manage.sh list

# 依存関係の再インストール
cd claude-code-cluster
uv pip install PyGithub httpx

# 手動でワーカーを起動してエラー確認
./uv-manage.sh shell
cd ../cc01  # CC01の場合
WORKER_NAME=CC01 WORKER_LABEL=cc01 python3 ../claude-code-cluster/scripts/github-worker-optimized.py
```

### GitHub認証エラーの場合
```bash
# GitHub tokenの確認
echo $GITHUB_TOKEN

# 環境変数の再読み込み
source ~/.bashrc
```

この構成により、各PCで独立してワーカーを実行できます。
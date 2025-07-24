# Claude Code Cluster GitHub版 クイックスタート

## 🚀 5分でセットアップ

### 1. GitHubトークン作成
[GitHub Settings](https://github.com/settings/tokens) → Generate new token → `repo`スコープ選択

### 2. インストール実行
```bash
# インストーラーをダウンロードして実行
curl -sSL https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/scripts/install-github-system.sh | bash
```

### 3. 環境リロード
```bash
source ~/.bashrc
```

### 4. ワーカー起動
```bash
cd ~/claude-workers
./start-all-workers.sh
```

### 5. 動作確認
```bash
# ステータス確認
./check-status.sh

# テストIssue作成
./test-worker.sh cc01
```

## 📝 基本的な使い方

### タスクの作成（マネージャー側）
```bash
# Frontend タスク
gh issue create --label cc01 --title "Create login form"

# Backend タスク  
gh issue create --label cc02 --title "Add user API"

# Infrastructure タスク
gh issue create --label cc03 --title "Setup CI/CD"
```

### ワーカーの動作
1. 自動的にIssueを検出（1-3分）
2. タスクを取得して"in-progress"ラベル追加
3. 作業実行（シミュレーション）
4. 完了時に"completed"ラベル追加

### ログ確認
```bash
# tmuxセッションで確認
tmux attach -t cc01-github
# Ctrl+B, D で抜ける
```

## 🛑 停止方法
```bash
cd ~/claude-workers
./stop-all-workers.sh
```

## 🔧 旧システムからの移行

### 1. 旧システムのアンインストール
```bash
curl -sSL https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/scripts/uninstall-old-system.sh | bash
```

### 2. 新システムのインストール
上記の手順に従ってインストール

## ❓ トラブルシューティング

### GitHubトークンエラー
```bash
# トークン確認
echo $GITHUB_TOKEN

# 再設定
export GITHUB_TOKEN="ghp_your_new_token"
```

### ワーカーが起動しない
```bash
# Python確認
python3 --version  # 3.8以上必要

# 依存関係再インストール
pip3 install --user PyGithub httpx
```

### Issueが検出されない
```bash
# ラベル確認
gh label list

# 必要なラベル作成
gh label create cc01 --color "0e8a16"
gh label create cc02 --color "1d76db"
gh label create cc03 --color "5319e7"
```

## 📊 システム比較

| 項目 | 旧システム | 新システム |
|------|----------|----------|
| 通信 | HTTP (ローカル) | GitHub API |
| セットアップ | 複雑 | シンプル |
| ネットワーク | 同一必須 | インターネットのみ |
| スケーラビリティ | 制限あり | 無制限 |

---
詳細は[導入ガイド](docs/MIGRATION_AND_INSTALLATION_GUIDE.md)を参照
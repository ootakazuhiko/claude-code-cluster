# Command Logging System セットアップガイド

## 概要
claude-code-clusterのコマンドロギングシステムを新しいプロジェクトで使用するための完全なセットアップガイドです。

## 前提条件
- Python 3.8以上
- GitHub CLI (`gh`)がインストール済み
- GitHubアカウントとリポジトリへのアクセス権限

## セットアップ手順

### 1. claude-code-clusterのクローン

```bash
# 作業ディレクトリに移動
cd /tmp

# リポジトリをクローン
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster

# 最新のmainブランチを取得
git checkout main
git pull origin main
```

### 2. 必要なファイルの配置

```bash
# hooksディレクトリの確認
ls -la hooks/

# 以下のファイルが存在することを確認：
# - command_logger.py
# - view-command-logs.py
# - universal-agent-auto-loop-with-logging.py
# - hooks/COMMAND_LOGGING_README.md
```

### 3. 実行権限の付与

```bash
chmod +x hooks/command_logger.py
chmod +x hooks/view-command-logs.py
chmod +x hooks/universal-agent-auto-loop-with-logging.py
```

### 4. ログディレクトリの準備

```bash
# ログディレクトリを作成（自動的に作成されますが、事前作成も可能）
mkdir -p /tmp/claude-code-logs
```

## 使用例

### 例1: 既存のGitHubプロジェクトでの使用

```bash
# ITDO_ERP2プロジェクトでCC01エージェントを起動
cd /tmp/claude-code-cluster
python3 hooks/universal-agent-auto-loop-with-logging.py CC01 itdojp ITDO_ERP2

# 別のターミナルでログを監視
python3 hooks/view-command-logs.py --agent CC01-ITDO_ERP2 --follow
```

### 例2: 新しいテストプロジェクトでの使用

```bash
# テストプロジェクトでエージェントを起動
# 例: owner=myusername, repo=test-project
python3 hooks/universal-agent-auto-loop-with-logging.py TEST01 myusername test-project \
  --specialization "Test Specialist" \
  --labels test-task auto-test \
  --keywords test unit integration

# ログを表示
python3 hooks/view-command-logs.py --agent TEST01-test-project
```

### 例3: カスタムエージェントの設定

```bash
# DevOpsエージェントの例
python3 hooks/universal-agent-auto-loop-with-logging.py DEVOPS01 myorg myrepo \
  --specialization "DevOps Engineer" \
  --labels devops ci-cd deployment \
  --keywords docker kubernetes pipeline \
  --cooldown 120 \
  --max-iterations 10
```

## ログの確認方法

### リアルタイム監視
```bash
# 全てのログをリアルタイムで表示
python3 hooks/view-command-logs.py --follow

# 特定エージェントのログを監視
python3 hooks/view-command-logs.py --agent CC01-ITDO_ERP2 --follow
```

### 履歴の確認
```bash
# 最近20件のコマンドを表示
python3 hooks/view-command-logs.py --limit 20

# GitHub API呼び出しのみ表示
python3 hooks/view-command-logs.py --type GH_API --limit 50

# 詳細情報付きで表示
python3 hooks/view-command-logs.py --agent CC01-ITDO_ERP2 -v
```

### 統計情報
```bash
# コマンド実行統計を表示
python3 hooks/view-command-logs.py --stats

# 特定エージェントの統計
python3 hooks/view-command-logs.py --agent CC01-ITDO_ERP2 --stats
```

### ログのエクスポート
```bash
# JSON形式でエクスポート
python3 hooks/view-command-logs.py --export /tmp/my_logs.json

# エージェント別エクスポート
python3 hooks/view-command-logs.py --agent CC01-ITDO_ERP2 --export /tmp/cc01_logs.json
```

## テストプロジェクトのセットアップ例

### 1. GitHubに新しいリポジトリを作成

```bash
# GitHub CLIを使用してリポジトリを作成
gh repo create test-command-logging --public --description "Test project for command logging"

# リポジトリをクローン
git clone https://github.com/$(gh api user -q .login)/test-command-logging
cd test-command-logging
```

### 2. テスト用のイシューを作成

```bash
# ラベルを作成
gh label create claude-code-task --description "Tasks for Claude Code agents"
gh label create test --description "Test tasks"

# テストイシューを作成
gh issue create --title "Test: Implement hello world function" \
  --body "Create a simple hello world function for testing" \
  --label claude-code-task,test

gh issue create --title "Test: Add unit tests" \
  --body "Add unit tests for the hello world function" \
  --label claude-code-task,test

gh issue create --title "Test: Create documentation" \
  --body "Create README documentation" \
  --label claude-code-task,test
```

### 3. エージェントを起動

```bash
cd /tmp/claude-code-cluster

# テストエージェントを起動（5回のイテレーションで終了）
python3 hooks/universal-agent-auto-loop-with-logging.py TEST01 $(gh api user -q .login) test-command-logging \
  --max-iterations 5 \
  --cooldown 30
```

## トラブルシューティング

### 問題: Permission denied
```bash
# 解決方法: 実行権限を付与
chmod +x hooks/*.py
```

### 問題: Module not found
```bash
# 解決方法: PYTHONPATHを設定
export PYTHONPATH="/tmp/claude-code-cluster:$PYTHONPATH"
```

### 問題: GitHub API認証エラー
```bash
# 解決方法: GitHub CLIでログイン
gh auth login
```

### 問題: SQLiteデータベースエラー
```bash
# 解決方法: ログディレクトリの権限を確認
ls -la /tmp/claude-code-logs/
chmod 755 /tmp/claude-code-logs/
```

## ログディレクトリ構造

```
/tmp/claude-code-logs/
├── agent-TEST01-test-command-logging/
│   ├── command_history.db      # SQLiteデータベース
│   ├── commands_20250115_*.log # コマンドログ
│   └── issues_20250115_*.log   # イシュー処理ログ
└── agent-CC01-ITDO_ERP2/
    └── ...
```

## 注意事項

1. **エージェントID**: エージェントIDは一意である必要があります
2. **ログ保存期間**: ログは自動的に削除されないため、定期的なクリーンアップが必要
3. **同時実行**: 同じエージェントIDで複数のインスタンスを実行しないでください
4. **リソース使用**: 長時間実行するとログファイルが大きくなる可能性があります

## 次のステップ

1. エージェントの動作をカスタマイズ（優先キーワード、専門分野など）
2. 複数エージェントの協調動作を設定
3. ログ分析スクリプトの作成
4. アラート機能の実装

---

**Status**: ✅ Ready to Use
**Support**: https://github.com/ootakazuhiko/claude-code-cluster/issues

🤖 Command Logging System Setup Guide
# Claude Code Cluster PoC - クイックスタートガイド

## 🚀 5分で始める

最も簡単な方法でClaude Code Clusterを試してみましょう。

### 前提条件チェック

必要なものを確認してください：

- ✅ **GitHub アカウント** - [作成済み](https://github.com/signup)
- ✅ **GitHub Personal Access Token** - [作成方法](#github-token作成)
- ✅ **Claude API アカウント** - [登録済み](https://console.anthropic.com/)
- ✅ **Python 3.11+** - `python --version` で確認

## 📦 インストール

### 1. リポジトリクローン

```bash
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster/claude-code-cluster-poc
```

### 2. 環境セットアップ

```bash
# Python仮想環境作成
python -m venv .venv

# 仮想環境有効化
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate

# 依存関係インストール
pip install -e .
```

### 3. 設定ファイル作成

```bash
# 設定ファイルをコピー
cp .env.example .env

# エディタで開いて設定
# Windows:
notepad .env
# macOS:
open -a TextEdit .env
# Linux:
nano .env
```

**.env ファイルの設定:**
```bash
# 必須設定（置き換えてください）
GITHUB_TOKEN=ghp_your_actual_github_token_here
ANTHROPIC_API_KEY=sk-ant-your_actual_api_key_here

# Git設定（あなたの情報に変更）
GIT_USER_NAME=Your Real Name
GIT_USER_EMAIL=your.email@example.com

# その他はデフォルトのまま
LOG_LEVEL=INFO
DEFAULT_BRANCH=main
```

### 4. 初期セットアップ

```bash
claude-cluster setup
```

成功すると以下のような表示が出ます：
```
🚀 Setting up Claude Code Cluster
✅ Environment configured
✅ GitHub token configured: ghp_12345...
✅ Anthropic API key configured: sk-ant-abc...
✅ Setup completed!
```

## 🎯 初回実行

### テストリポジトリで試してみる

```bash
# 実際のGitHub Issueを使って実行
claude-cluster workflow --issue 1 --repo octocat/Hello-World

# または自分のリポジトリで実行
claude-cluster workflow --issue [issue番号] --repo [あなたのユーザー名]/[リポジトリ名]
```

### 例：バグ修正の自動化

もしあなたが以下のようなIssueを持っている場合：

**Issue #42: "ボタンが正しく動作しない"**

```bash
claude-cluster workflow --issue 42 --repo myusername/my-app
```

実行されるプロセス：
1. 🔍 Issue内容を分析
2. 🤖 最適な専門Agent（Frontend/Backend/Testing/DevOps）を選択
3. 💻 Claude AIでコード生成
4. 🔧 ファイル変更を適用
5. 📋 Pull Requestを自動作成

## 📊 結果の確認

### 1. 実行状況確認

```bash
# 全体的な状況
claude-cluster status

# 特定タスクの詳細
claude-cluster status --task-id task-20241208-001
```

### 2. 生成されたPull Requestを確認

コンソールに表示されるURLをブラウザで開いて確認してください：

```
✅ Task completed successfully!
📋 Pull request created: https://github.com/yourname/yourrepo/pull/123
```

### 3. 利用可能なAgentを確認

```bash
claude-cluster agents
```

出力例：
```
🤖 Available Specialized Agents

BackendAgent
├── Specialties: backend, api, database, server
├── Claude Model: claude-3-sonnet-20240229
└── File Patterns: 23 patterns

FrontendAgent  
├── Specialties: frontend, ui, react, javascript, typescript
├── Claude Model: claude-3-haiku-20240307
└── File Patterns: 19 patterns

TestingAgent
├── Specialties: testing, qa, pytest, jest, quality
├── Claude Model: claude-3-sonnet-20240229
└── File Patterns: 15 patterns

DevOpsAgent
├── Specialties: devops, infrastructure, deployment, ci, cd
├── Claude Model: claude-3-sonnet-20240229
└── File Patterns: 25 patterns
```

## 🔧 基本的な使い方

### ワンライナー実行（推奨）

```bash
# Issue番号とリポジトリ指定でワンライナー実行
claude-cluster workflow --issue 123 --repo owner/repository
```

### ステップ別実行

```bash
# 1. タスク作成
claude-cluster create-task --issue 123 --repo owner/repository
# → task-20241208-001

# 2. タスク実行  
claude-cluster run-task task-20241208-001

# 3. 結果確認
claude-cluster status --task-id task-20241208-001
```

## 🌐 分散処理を試す（上級）

### Docker Composeで分散クラスター体験

```bash
# 環境変数をexport
export GITHUB_TOKEN=ghp_your_token_here
export ANTHROPIC_API_KEY=sk-ant-your_key_here

# Docker Composeでクラスター起動
docker-compose up -d

# クラスター状態確認
curl http://localhost:8001/api/cluster/status

# 分散実行
claude-cluster-distributed workflow \
  --issue 123 \
  --repo owner/repo \
  --distributed
```

## 📝 GitHub Token作成

1. [GitHub Settings](https://github.com/settings/tokens) にアクセス
2. "Generate new token (classic)" をクリック
3. 以下の権限を選択：
   - ✅ `repo` (フルアクセス)
   - ✅ `read:user`
   - ✅ `user:email`
4. "Generate token" をクリック
5. 表示されたトークンをコピー（再表示されないので注意）
6. `.env` ファイルの `GITHUB_TOKEN` に設定

## 🔑 Claude API キー取得

1. [Anthropic Console](https://console.anthropic.com/) にアクセス
2. アカウント作成・ログイン
3. "API Keys" セクションに移動
4. "Create Key" をクリック
5. 生成されたキーをコピー
6. `.env` ファイルの `ANTHROPIC_API_KEY` に設定

## ⚡ よくある質問

### Q: 課金はどのくらいかかる？

**A:** Claude API は従量課金制です：
- **小規模テスト**: 月$1-5程度
- **日常的な使用**: 月$10-50程度
- **大量処理**: 月$100+

[Anthropic Pricing](https://www.anthropic.com/pricing) で詳細確認可能

### Q: どんなプログラミング言語に対応？

**A:** 現在のPoC版では以下に最適化：
- ✅ **Python** (FastAPI, Django, Flask)
- ✅ **JavaScript/TypeScript** (React, Node.js)
- ✅ **HTML/CSS** (フロントエンド)
- ⚠️ その他の言語も部分的に対応

### Q: プライベートリポジトリでも使える？

**A:** はい、GitHub Personal Access Tokenに適切な権限があれば使用可能です。

### Q: 生成されたコードの品質は？

**A:** 以下のような特徴があります：
- ✅ 構文的に正しいコードが生成される
- ✅ 基本的なベストプラクティスに従う
- ✅ テストコードも含まれる
- ⚠️ 複雑なビジネスロジックは要レビュー
- ⚠️ セキュリティ監査は別途必要

### Q: 間違ったコードが生成されたら？

**A:** Pull Requestとして提出されるので：
1. レビューで問題を発見
2. 必要に応じて修正
3. 通常のGitワークフローで管理

## 🆘 トラブルシューティング

### インストールエラー

```bash
# Python バージョン確認
python --version  # 3.11+ が必要

# 仮想環境の再作成
rm -rf .venv
python -m venv .venv
source .venv/bin/activate  # Linux/macOS
# または .venv\Scripts\activate  # Windows
pip install -e .
```

### 認証エラー

```bash
# GitHub token テスト
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Claude API テスト  
curl -H "Authorization: Bearer $ANTHROPIC_API_KEY" \
     -H "Content-Type: application/json" \
     https://api.anthropic.com/v1/messages
```

### 実行エラー

```bash
# デバッグモードで実行
export LOG_LEVEL=DEBUG
claude-cluster workflow --issue 123 --repo owner/repo

# ログファイル確認
tail -f logs/claude-cluster.log
```

## 🎯 次のステップ

クイックスタートが成功したら、以下のドキュメントを参照してください：

- 📖 [USAGE.md](USAGE.md) - 詳細な使用方法
- 🚀 [DEPLOYMENT.md](DEPLOYMENT.md) - 本格的なデプロイメント  
- 📝 [EXAMPLES.md](EXAMPLES.md) - 実行例とユースケース
- 📚 [README.md](README.md) - 全体的な概要

---

🎉 **おめでとうございます！** Claude Code Clusterの基本的な使い方をマスターしました。より複雑な機能を試すには、上記のドキュメントを参照してください。
# Claude Code Cluster PoC - 使い方ガイド

## 📋 目次

1. [前提条件](#前提条件)
2. [動作環境](#動作環境)
3. [セットアップ手順](#セットアップ手順)
4. [使用方法](#使用方法)
5. [実行例](#実行例)
6. [トラブルシューティング](#トラブルシューティング)
7. [制限事項](#制限事項)

## 🔧 前提条件

### 必要なアカウント・API キー

1. **GitHub アカウント**
   - Personal Access Token (PAT) が必要
   - 必要な権限: `repo`, `issues`, `pull_requests`
   - トークン作成: [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens)

2. **Anthropic Claude API**
   - Claude API キーが必要
   - アカウント作成: [Anthropic Console](https://console.anthropic.com/)
   - 料金: 従量課金制（PoCレベルなら月数ドル程度）

3. **Git 設定**
   - ローカルGit設定が完了していること
   - GitHub への SSH/HTTPS アクセスが設定済み

### システム要件

#### 最小構成（ローカル単体実行）
- **OS**: Windows 10/11, macOS 10.15+, Ubuntu 18.04+
- **Python**: 3.11 以上
- **メモリ**: 4GB RAM
- **ストレージ**: 1GB 空き容量
- **ネットワーク**: インターネット接続（GitHub/Claude API アクセス用）

#### 推奨構成（分散クラスター）
- **台数**: 2-5台のPC/サーバー
- **各ノード**: 8GB RAM, 2CPU cores
- **ネットワーク**: 同一LAN内または安定したWAN接続
- **OS**: Linux (Ubuntu 20.04+ 推奨) または Docker対応OS

## 🌐 動作環境

### サポート対象

#### 開発・テスト環境
- **ローカル開発**: Windows, macOS, Linux での単体テスト
- **Dockerコンテナ**: 一台のマシン上でクラスター模擬
- **WSL**: Windows Subsystem for Linux

#### 本格運用環境
- **オンプレミス**: 複数のLinuxサーバー
- **クラウド**: AWS EC2, Google Compute Engine, Azure VM
- **Kubernetes**: コンテナオーケストレーション環境

### ネットワーク要件

#### ポート使用
- **8000**: Webhook サーバー（GitHub からのWebhook受信）
- **8001**: クラスター調整サーバー
- **8002-8005**: Agent ノード（専門分野別）
- **22**: SSH（リモート管理用）

#### 外部接続
- **github.com**: HTTPS (443)
- **api.anthropic.com**: HTTPS (443)
- **クラスターノード間**: HTTP (8001-8005)

## 📦 セットアップ手順

### 1. リポジトリクローンと基本セットアップ

```bash
# リポジトリをクローン
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster/claude-code-cluster-poc

# Python 仮想環境作成（uvを使用）
curl -LsSf https://astral.sh/uv/install.sh | sh  # uvインストール
uv venv
source .venv/bin/activate  # Linux/macOS
# または .venv\Scripts\activate  # Windows

# 依存関係インストール
uv pip install -e .
```

### 2. 環境設定

```bash
# 環境変数ファイル作成
cp .env.example .env

# .env ファイルを編集（必須）
vim .env  # または任意のエディタ
```

**.env ファイル設定例:**
```bash
# GitHub設定（必須）
GITHUB_TOKEN=ghp_your_github_personal_access_token_here
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=your.email@example.com

# Claude API設定（必須）
ANTHROPIC_API_KEY=sk-ant-api03-your_claude_api_key_here

# 分散設定（オプション）
COORDINATOR_HOST=localhost
COORDINATOR_PORT=8001

# ログレベル（オプション）
LOG_LEVEL=INFO
```

### 3. 初期セットアップ確認

```bash
# 設定確認とセットアップ
claude-cluster setup

# 利用可能な専門Agentを確認
claude-cluster agents
```

## 🚀 使用方法

### A. ローカルモード（単一PC）

**最も簡単な使用方法 - 一台のPCで完結**

#### A-1. 基本的なワークフロー

```bash
# GitHub Issue から PR作成まで一括実行
claude-cluster workflow --issue 123 --repo owner/repository-name

# 例: 実際のリポジトリでの実行
claude-cluster workflow --issue 42 --repo ootakazuhiko/my-project
```

#### A-2. ステップ別実行

```bash
# 1. タスク作成
claude-cluster create-task --issue 123 --repo owner/repo
# → タスクID (例: task-20241208-001) が表示される

# 2. タスク実行
claude-cluster run-task task-20241208-001

# 3. 状態確認
claude-cluster status
claude-cluster status --task-id task-20241208-001
```

### B. 分散モード（複数PC）

**複数のPCでクラスターを構成して負荷分散**

#### B-1. 調整サーバー起動（1台目のPC）

```bash
# IPアドレス確認
ip addr show  # Linux
ifconfig     # macOS

# 調整サーバー起動（例: IP 192.168.1.100）
claude-cluster-distributed start-coordinator --host 0.0.0.0 --port 8001
```

#### B-2. Agent ノード起動（2台目以降のPC）

```bash
# Backend専門Agent（2台目PC）
claude-cluster-distributed start-node \
  --coordinator-host 192.168.1.100 \
  --coordinator-port 8001 \
  --agent-port 8002 \
  --specialties backend,api,database \
  --max-tasks 2 \
  --node-id backend-node-001

# Frontend専門Agent（3台目PC）
claude-cluster-distributed start-node \
  --coordinator-host 192.168.1.100 \
  --coordinator-port 8001 \
  --agent-port 8003 \
  --specialties frontend,react,ui \
  --max-tasks 2 \
  --node-id frontend-node-001

# Testing専門Agent（4台目PC）
claude-cluster-distributed start-node \
  --coordinator-host 192.168.1.100 \
  --coordinator-port 8001 \
  --agent-port 8004 \
  --specialties testing,qa,pytest \
  --max-tasks 3 \
  --node-id testing-node-001
```

#### B-3. 分散タスク実行

```bash
# クラスター状態確認
claude-cluster-distributed status --show-cluster

# 分散ワークフロー実行
claude-cluster-distributed workflow \
  --issue 123 \
  --repo owner/repo \
  --distributed \
  --coordinator-host 192.168.1.100 \
  --coordinator-port 8001
```

### C. Docker クラスター（開発・テスト用）

**一台のPCで分散クラスターを模擬**

#### C-1. Docker Compose でクラスター起動

```bash
# 環境変数設定
export GITHUB_TOKEN=ghp_your_token
export ANTHROPIC_API_KEY=sk-ant-your_key

# 全サービス起動
docker-compose up

# または、バックグラウンド実行
docker-compose up -d

# ログ確認
docker-compose logs -f coordinator
docker-compose logs -f agent-backend
```

#### C-2. API経由でタスク実行

```bash
# クラスター状態確認
curl http://localhost:8001/api/cluster/status

# タスク投入
curl -X POST http://localhost:8001/api/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "task_id": "api-task-001",
    "priority": "high",
    "requirements": ["backend"]
  }'

# タスク状態確認
curl http://localhost:8001/api/tasks/api-task-001
```

## 📝 実行例

### 例1: バックエンドAPI実装のIssue

```bash
# Issue例: "ユーザー認証APIエンドポイントの追加"
claude-cluster workflow --issue 156 --repo mycompany/api-server

# 期待される動作:
# 1. BackendAgent が自動選択される（高いスコア）
# 2. FastAPI/認証関連のコードが生成される
# 3. pytest テストコードも含まれる
# 4. Pull Request が自動作成される
```

### 例2: フロントエンド機能のIssue

```bash
# Issue例: "ダッシュボードの新しいUIコンポーネント"
claude-cluster workflow --issue 89 --repo mycompany/dashboard

# 期待される動作:
# 1. FrontendAgent が自動選択される
# 2. React/TypeScriptコンポーネントが生成される
# 3. CSS/スタイリングも含まれる
# 4. Jest テストコードも含まれる
```

### 例3: 分散環境でのテスト改善

```bash
# 複数のAgentで並行処理
claude-cluster-distributed workflow --issue 201 --repo mycompany/platform --distributed

# Issue例: "統合テストの追加とCI/CD改善"
# 期待される動作:
# 1. TestingAgent が主担当（テスト関連）
# 2. DevOpsAgent が副担当（CI/CD関連）
# 3. 複数ノードでの並行実行
# 4. 負荷分散による高速処理
```

## 🔍 監視とデバッグ

### ログ確認

```bash
# ローカル実行のログ
tail -f logs/claude-cluster.log

# Docker環境のログ
docker-compose logs -f

# 分散環境の各ノードログ
# 各PCで実行
journalctl -f -u claude-agent  # systemdの場合
```

### ヘルスチェック

```bash
# 調整サーバー
curl http://localhost:8001/health

# Agent ノード
curl http://localhost:8002/health  # backend
curl http://localhost:8003/health  # frontend
curl http://localhost:8004/health  # testing
curl http://localhost:8005/health  # devops
```

### デバッグモード

```bash
# 詳細ログ出力
export LOG_LEVEL=DEBUG
claude-cluster-distributed status --show-cluster

# Agent選択過程の確認
claude-cluster agents
```

## ⚠️ トラブルシューティング

### よくある問題と解決法

#### 1. GitHub認証エラー
```bash
Error: GitHub authentication failed
```
**解決法:**
- GitHub Personal Access Token の権限確認
- トークンの有効期限確認
- `.env` ファイルの `GITHUB_TOKEN` 設定確認

#### 2. Claude API制限
```bash
Error: Rate limit exceeded
```
**解決法:**
- Claude API の使用量確認
- より低頻度でのタスク実行
- API キーの有効性確認

#### 3. Agent ノード接続失敗
```bash
Warning: Node registration failed
```
**解決法:**
- ネットワーク接続確認
- ファイアウォール設定確認（ポート8001-8005）
- 調整サーバーの起動状態確認

#### 4. Docker起動失敗
```bash
Error: container failed to start
```
**解決法:**
- Docker Desktopの起動確認
- 環境変数の設定確認（GITHUB_TOKEN, ANTHROPIC_API_KEY）
- ポート競合の確認（8000-8005番ポート）

### ログファイル位置

- **ローカル**: `logs/claude-cluster.log`
- **Docker**: `docker-compose logs`
- **分散**: 各ノードの `/var/log/claude-agent.log`

## 🚫 制限事項

### 現在のPoC制限

1. **セキュリティ**
   - 本格的な認証・認可システムなし
   - API キーの平文保存
   - HTTPS通信の未実装（HTTP のみ）

2. **スケーラビリティ**
   - 同時処理数の制限（ノードあたり1-3タスク）
   - ファイルベースの状態管理（大規模運用不可）
   - 永続化ストレージの欠如

3. **エラーハンドリング**
   - 部分的なエラー回復機能
   - ネットワーク分断時の制限された処理
   - データ整合性保証の不足

4. **対応リポジトリ**
   - 主にPython/JavaScript プロジェクト
   - 複雑なビルドシステムは未対応
   - 巨大なリポジトリ（10GB+）は非推奨

### 推奨使用場面

✅ **適している用途:**
- 小〜中規模プロジェクトの自動化
- 開発プロセスの PoC/検証
- チーム内でのClaude活用実験
- 単純なバグ修正やfeature追加

❌ **適していない用途:**
- 本番システムでの運用
- 機密性の高いコードベース
- 大規模エンタープライズ環境
- リアルタイム性が重要なシステム

## 📞 サポート

### 問題報告
- **GitHub Issues**: [https://github.com/ootakazuhiko/claude-code-cluster/issues](https://github.com/ootakazuhiko/claude-code-cluster/issues)

### ドキュメント
- **README**: プロジェクト概要
- **USAGE**: このファイル（詳細な使用方法）
- **CLAUDE.md**: Claude Code向けの技術仕様

---

**注意**: このシステムはProof of Conceptです。本格運用には追加のセキュリティ対策と安定性向上が必要です。
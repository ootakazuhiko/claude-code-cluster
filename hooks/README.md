# Agent Auto-Loop Hook System

Claude Code hookシステムを活用したエージェントの自動ループ実行システム

## 概要

このシステムは、Claude Code hookの仕組みを使用して、エージェント（CC01、CC02、CC03）が自動的にタスクを取得し、実行し、完了後に次のタスクを探すループ実行を実現します。

## 主な機能

### 1. 自動タスク発見・実行
- GitHubからopen issuesを自動取得
- 優先度に基づくタスク選択
- 自動タスク実行と進捗監視
- 完了後の自動次タスク発見

### 2. Agent別特化処理
- **CC01**: Backend specialist - API、データベース、Python/FastAPI
- **CC02**: Database specialist - SQL、パフォーマンス、マイグレーション
- **CC03**: Frontend specialist - UI/UX、React、TypeScript

### 3. 包括的監視・ログ機能
- SQLiteベースのタスク履歴記録
- パフォーマンス指標の自動収集
- 詳細なログ出力
- リアルタイム監視

### 4. 自動エスカレーション
- 30分制限での自動エスカレーション
- 複雑な問題の自動検出
- Manager (Opus)への自動引き継ぎ

## システム構成

```
hooks/
├── agent-auto-loop.py          # メインの自動ループシステム
├── claude-code-settings.json   # Claude Code設定
├── start-agent-loop.sh         # エージェント起動スクリプト
└── README.md                   # 本文書
```

## 使用方法

### 基本的な使用

```bash
# 単一エージェント起動
./hooks/start-agent-loop.sh start CC01

# 全エージェント起動
./hooks/start-agent-loop.sh start all

# 制限付き起動（10回実行、30秒クールダウン）
./hooks/start-agent-loop.sh start CC01 10 30
```

### エージェント管理

```bash
# エージェント状態確認
./hooks/start-agent-loop.sh status all

# エージェント停止
./hooks/start-agent-loop.sh stop CC02

# エージェント再起動
./hooks/start-agent-loop.sh restart CC03

# ログ確認
./hooks/start-agent-loop.sh logs CC01
```

### メトリクス確認

```bash
# パフォーマンス指標表示
./hooks/start-agent-loop.sh metrics CC01

# 全エージェントメトリクス
./hooks/start-agent-loop.sh metrics all
```

## 自動ループフロー

```
1. GitHub issues取得
   ↓
2. 優先度判定・タスク選択
   ↓
3. エージェントに自動割り当て
   ↓
4. Claude Code セッション作成
   ↓
5. タスク実行・監視
   ↓
6. 完了/エスカレーション判定
   ↓
7. 次タスク発見 (ループ)
```

## 優先度判定ロジック

### 基本優先度
1. **Critical/Failure**: 失敗・緊急タスク (+20点)
2. **Specialization Match**: 専門分野キーワード (+10点)
3. **Unassigned**: 未割り当て (+5点)
4. **Recent Activity**: 24時間以内の活動 (+3点)

### エージェント別キーワード
- **CC01**: backend, api, database, python, fastapi
- **CC02**: database, sql, performance, migration, query
- **CC03**: frontend, ui, react, typescript, css

## 監視・ログ機能

### データベース記録
- **task_history**: タスク実行履歴
- **agent_metrics**: パフォーマンス指標

### 監視項目
- タスク完了率
- 平均実行時間
- エスカレーション頻度
- 自律動作率

### ログファイル
- `/tmp/agent-logs/agent-{ID}.log`: 実行ログ
- `/tmp/agent-{ID}-loop.db`: メトリクスDB

## エスカレーション機能

### 自動エスカレーション条件
1. **時間制限**: 30分以上の実行
2. **キーワード検出**: "escalate", "complex", "blocked"
3. **複雑度判定**: アーキテクチャ変更が必要

### エスカレーション処理
- Manager (Opus)への自動引き継ぎ
- 問題コンテキストの自動収集
- 解決策の自動適用

## 設定カスタマイズ

### claude-code-settings.json
```json
{
  "hooks": {
    "agent-auto-loop": {
      "enabled": true,
      "parameters": {
        "max_iterations": null,
        "cooldown_time": 60,
        "escalation_threshold": 1800
      }
    }
  }
}
```

### エージェント設定
```json
{
  "agent_configurations": {
    "CC01": {
      "specialization": "Backend Specialist",
      "labels": ["claude-code-task", "cc01"],
      "max_task_duration": 1800,
      "cooldown_time": 60
    }
  }
}
```

## トラブルシューティング

### 一般的な問題

#### エージェントが起動しない
```bash
# 前提条件確認
./hooks/start-agent-loop.sh help

# GitHub認証確認
gh auth status

# Python依存関係確認
python3 -c "import sqlite3, json, subprocess"
```

#### タスクが実行されない
```bash
# Issue確認
gh issue list --repo itdojp/ITDO_ERP2 --state open --label "claude-code-task"

# エージェント状態確認
./hooks/start-agent-loop.sh status all

# ログ確認
./hooks/start-agent-loop.sh logs CC01
```

#### パフォーマンス問題
```bash
# メトリクス確認
./hooks/start-agent-loop.sh metrics all

# データベース直接確認
sqlite3 /tmp/agent-CC01-loop.db "SELECT * FROM task_history ORDER BY start_time DESC LIMIT 10;"
```

### クリーンアップ
```bash
# 全データクリーンアップ
./hooks/start-agent-loop.sh cleanup

# 手動クリーンアップ
rm -f /tmp/agent-*.pid
rm -rf /tmp/agent-logs
rm -f /tmp/agent-*-loop.db
```

## 成功指標

### 目標値
- **自律動作率**: >90%
- **タスク完了率**: >85%
- **平均実行時間**: <30分
- **エスカレーション率**: <10%

### 品質指標
- **テストカバレッジ**: >80%
- **コード品質**: 全品質ゲート通過
- **セキュリティ**: 脆弱性ゼロ

## 実装の特徴

### Claude Code Hook統合
- hookシステムの完全活用
- 設定ファイルベースの管理
- 拡張可能なアーキテクチャ

### Agent Sonnet System統合
- claude-code-cluster活用
- コスト最適化（70%削減）
- 自動Sonnet model使用

### 堅牢性
- 例外処理とエラー回復
- 自動リトライ機能
- グレースフルシャットダウン

---

**Status**: ✅ Production Ready
**Integration**: Claude Code Hook System
**Optimization**: Agent Sonnet System

🤖 Complete Hook-Based Autonomous Agent System
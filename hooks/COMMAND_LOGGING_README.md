# Command Logging System for Claude Code Hooks

## 概要

Claude Code Hook Systemに包括的なコマンドロギング機能を実装しました。全てのコマンド実行、API呼び出し、イシュー処理イベントを記録・分析できます。

## 実装内容

### 1. command_logger.py
包括的なロギング機能を提供するコアモジュール：

- **SQLiteデータベース記録**: 構造化されたコマンド履歴の保存
- **ファイルベースロギング**: テキストファイルへの同時記録
- **コンテキストマネージャー**: 安全な実行時間トラッキング
- **統計情報**: コマンド実行統計の自動集計

### 2. universal-agent-auto-loop-with-logging.py
ロギング機能を統合したエージェント自動ループシステム：

- **全コマンドの記録**: GitHub API、シェルコマンド、ファイル操作
- **イシュー処理追跡**: タスクの開始、完了、エラーの記録
- **セッション管理**: エージェントセッション全体の追跡
- **自動エクスポート**: セッション終了時のログエクスポート

### 3. view-command-logs.py
ログの表示・分析用ユーティリティ：

- **リアルタイム追跡**: tail -f スタイルのログフォロー
- **フィルタリング**: エージェント、コマンドタイプでの絞り込み
- **統計表示**: 成功率、実行時間の統計
- **JSONエクスポート**: 外部分析用のデータエクスポート

## データベーススキーマ

### command_history テーブル
```sql
CREATE TABLE command_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    command_type TEXT NOT NULL,
    command TEXT NOT NULL,
    parameters TEXT,        -- JSON形式のパラメータ
    result TEXT,           -- 実行結果
    status TEXT NOT NULL,  -- IN_PROGRESS, SUCCESS, ERROR
    duration_ms INTEGER,   -- 実行時間（ミリ秒）
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### issue_processing_log テーブル
```sql
CREATE TABLE issue_processing_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    issue_number TEXT NOT NULL,
    issue_title TEXT,
    action_type TEXT NOT NULL,    -- TASK_EXECUTION, ESCALATION, etc
    details TEXT,                  -- JSON形式の詳細情報
    status TEXT NOT NULL,         -- IN_PROGRESS, SUCCESS, ERROR
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 使用方法

### 基本的な使用

#### エージェントの起動（ロギング付き）
```bash
# CC01エージェントをロギング付きで起動
python3 hooks/universal-agent-auto-loop-with-logging.py CC01 owner repo

# 制限付き実行
python3 hooks/universal-agent-auto-loop-with-logging.py CC01 owner repo --max-iterations 5
```

#### ログの表示
```bash
# 最近のコマンドを表示
python3 hooks/view-command-logs.py

# 特定エージェントのログを表示
python3 hooks/view-command-logs.py --agent CC01

# 詳細情報付きで表示
python3 hooks/view-command-logs.py --agent CC01 -v

# APIコマンドのみ表示
python3 hooks/view-command-logs.py --type GH_API --limit 50
```

#### リアルタイム監視
```bash
# ログをリアルタイムで追跡
python3 hooks/view-command-logs.py --follow

# 特定エージェントのログを追跡
python3 hooks/view-command-logs.py --agent CC01 --follow
```

#### 統計情報の表示
```bash
# コマンド実行統計を表示
python3 hooks/view-command-logs.py --stats

# エージェント別統計
python3 hooks/view-command-logs.py --agent CC01 --stats
```

#### ログのエクスポート
```bash
# JSON形式でエクスポート
python3 hooks/view-command-logs.py --export /tmp/command_logs.json

# エージェント別エクスポート
python3 hooks/view-command-logs.py --agent CC01 --export /tmp/cc01_logs.json
```

## ログディレクトリ構造

```
/tmp/claude-code-logs/
├── agent-CC01/
│   ├── command_history.db      # SQLiteデータベース
│   ├── commands_*.log          # コマンドログファイル
│   └── issues_*.log            # イシュー処理ログファイル
├── agent-CC02/
│   └── ...
└── agent-CC03/
    └── ...
```

## ロギング対象

### コマンドタイプ
- **SHELL**: シェルコマンド実行
- **GH_API**: GitHub CLI API呼び出し
- **API**: 一般的なAPI呼び出し
- **FILE_WRITE**: ファイル書き込み操作
- **API_RESULT**: API結果の記録

### イシューアクション
- **TASK_EXECUTION**: タスク実行の開始/完了
- **ESCALATION**: エスカレーションイベント
- **TASK_TIMEOUT**: タイムアウトイベント
- **SESSION_START/END**: セッション開始/終了

## プログラマティック使用

```python
from hooks.command_logger import CommandLogger

# ロガーの初期化
logger = CommandLogger("/tmp/my-logs")

# コマンドの記録
with logger.log_command("SHELL", "ls -la", {"cwd": "/tmp"}):
    # コマンド実行
    result = subprocess.run(["ls", "-la"], capture_output=True)

# イシュー処理の記録
logger.log_issue_processing_start("123", "Fix bug", "ANALYZE")
# ... 処理 ...
logger.log_issue_processing_complete("123", "ANALYZE", {"fixed": True})

# 統計の取得
stats = logger.get_command_stats()
print(stats)
```

## 出力例

### コマンド履歴表示
```
========================================================================================================================
Timestamp            Type       Command                                  Status     Duration  
------------------------------------------------------------------------------------------------------------------------
2025-01-15 10:30:45  GH_API     gh issue list --repo itdojp/ITDO_ERP2  SUCCESS    245ms     
2025-01-15 10:30:46  FILE_WRITE /tmp/agent-CC01-session-123.md         SUCCESS    12ms      
2025-01-15 10:31:00  SHELL      make test                               ERROR      15.2s     
========================================================================================================================
```

### 統計表示
```
================================================================================
Command Execution Statistics
--------------------------------------------------------------------------------
Command Type         Count      Success %    Avg Time     Max Time    
--------------------------------------------------------------------------------
GH_API               125        96.0         312ms        2.1s        
SHELL                89         87.6         5.4s         45.2s       
FILE_WRITE           156        100.0        8ms          125ms       
================================================================================
```

## 利点

### 1. 完全な実行履歴
- 全てのコマンド実行を記録
- 成功/失敗の追跡
- 実行時間の測定

### 2. デバッグ支援
- エラーメッセージの記録
- パラメータの保存
- タイムスタンプ付き履歴

### 3. パフォーマンス分析
- 実行時間統計
- 成功率の計算
- ボトルネックの特定

### 4. 監査証跡
- 完全な操作履歴
- イシュー処理の追跡
- セッション管理

## 今後の拡張可能性

1. **リモートログ収集**: 中央ログサーバーへの送信
2. **アラート機能**: エラー率上昇時の通知
3. **可視化ダッシュボード**: Webベースの分析UI
4. **機械学習統合**: パターン認識とアノマリー検出

---

**Status**: ✅ Production Ready
**Location**: ITDO_ERP2/hooks/
**Based on**: https://github.com/ootakazuhiko/claude-code-cluster/blob/main/docs/tmp/claude-code-hook-system-doc.md

🤖 Command Logging System for Claude Code Hooks
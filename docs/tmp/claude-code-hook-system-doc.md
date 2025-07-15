# Claude Code Hook システム - GitHub Issue自動処理とコマンドログ記録

## 概要

Claude Codeのhook機能を使用して、GitHubのissueを継続的に監視・処理し、実行したすべてのコマンドをログとして記録・可視化するシステムの実装ガイドです。

## システム要件

- Python 3.7以上
- Claude Code（研究プレビュー版）
- GitHub Personal Access Token
- 必要なPythonパッケージ：requests, flask, flask-cors

## 基本的なhook処理の実装

### 1. シンプルなGitHub Issue処理システム

```python
import time
import requests
from datetime import datetime
from typing import List, Dict, Optional
import os

class GitHubIssueTaskProcessor:
    def __init__(self, repo_owner: str, repo_name: str, github_token: str):
        self.repo_owner = repo_owner
        self.repo_name = repo_name
        self.headers = {
            "Authorization": f"token {github_token}",
            "Accept": "application/vnd.github.v3+json"
        }
        self.processed_issues = set()
        
    def fetch_issues(self, labels: List[str] = None, state: str = "open") -> List[Dict]:
        """条件を満たすGitHub issueを取得"""
        url = f"https://api.github.com/repos/{self.repo_owner}/{self.repo_name}/issues"
        params = {
            "state": state,
            "sort": "created",
            "direction": "asc"
        }
        
        if labels:
            params["labels"] = ",".join(labels)
            
        try:
            response = requests.get(url, headers=self.headers, params=params)
            response.raise_for_status()
            issues = response.json()
            
            # 未処理のissueのみを返す
            return [issue for issue in issues if issue["id"] not in self.processed_issues]
        except Exception as e:
            print(f"Error fetching issues: {e}")
            return []
    
    def process_issue(self, issue: Dict) -> bool:
        """issueを処理する"""
        try:
            print(f"\n処理開始: Issue #{issue['number']} - {issue['title']}")
            
            # ここに実際の処理ロジックを実装
            # 例: issueの内容を解析、自動応答、ラベル付け等
            
            # 処理済みとしてマーク
            self.processed_issues.add(issue["id"])
            
            # コメントを追加（例）
            self.add_comment(issue["number"], "タスクを処理しました。")
            
            print(f"処理完了: Issue #{issue['number']}")
            return True
            
        except Exception as e:
            print(f"Error processing issue #{issue['number']}: {e}")
            return False
    
    def add_comment(self, issue_number: int, comment_body: str):
        """issueにコメントを追加"""
        url = f"https://api.github.com/repos/{self.repo_owner}/{self.repo_name}/issues/{issue_number}/comments"
        data = {"body": comment_body}
        
        try:
            response = requests.post(url, headers=self.headers, json=data)
            response.raise_for_status()
        except Exception as e:
            print(f"Error adding comment: {e}")
    
    def run_hook(self, labels: List[str] = None, wait_time: int = 60):
        """hookを使った繰り返し処理"""
        print(f"タスク処理を開始します...")
        print(f"監視対象: {self.repo_owner}/{self.repo_name}")
        if labels:
            print(f"フィルタラベル: {labels}")
        
        while True:
            try:
                # 新しいタスク（issue）を取得
                issues = self.fetch_issues(labels=labels)
                
                if issues:
                    print(f"\n{len(issues)}件の新しいタスクが見つかりました")
                    
                    # 各issueを処理
                    for issue in issues:
                        self.process_issue(issue)
                        time.sleep(2)  # API制限を考慮
                else:
                    print(f"\n新しいタスクがありません。{wait_time}秒待機します...")
                    time.sleep(wait_time)
                    
            except KeyboardInterrupt:
                print("\n処理を中断しました")
                break
            except Exception as e:
                print(f"\nエラーが発生しました: {e}")
                print(f"{wait_time}秒後に再試行します...")
                time.sleep(wait_time)


# Claude Code用のhook関数
def claude_code_hook():
    """Claude Codeから呼び出されるhook関数"""
    # 環境変数から設定を読み込み
    github_token = os.environ.get("GITHUB_TOKEN")
    repo_owner = os.environ.get("REPO_OWNER", "your-username")
    repo_name = os.environ.get("REPO_NAME", "your-repo")
    
    if not github_token:
        print("Error: GITHUB_TOKEN環境変数が設定されていません")
        return
    
    # プロセッサーを初期化
    processor = GitHubIssueTaskProcessor(repo_owner, repo_name, github_token)
    
    # 特定のラベルを持つissueのみを処理（オプション）
    target_labels = ["auto-process", "bot-task"]
    
    # hookを実行
    processor.run_hook(labels=target_labels, wait_time=30)
```

## コマンドログ記録機能の追加

### 2. ログ記録機能付きシステム

```python
import time
import requests
import json
import sqlite3
import subprocess
import os
from datetime import datetime
from typing import List, Dict, Optional, Any
from contextlib import contextmanager
import logging

class CommandLogger:
    """コマンド実行を記録するクラス"""
    
    def __init__(self, db_path: str = "command_history.db"):
        self.db_path = db_path
        self.init_database()
        
    def init_database(self):
        """データベースの初期化"""
        with self.get_db() as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS command_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    command_type TEXT NOT NULL,
                    command TEXT NOT NULL,
                    parameters TEXT,
                    result TEXT,
                    status TEXT NOT NULL,
                    duration_ms INTEGER,
                    error_message TEXT
                )
            """)
            
            conn.execute("""
                CREATE TABLE IF NOT EXISTS issue_processing_log (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    issue_number INTEGER NOT NULL,
                    issue_title TEXT,
                    action_type TEXT NOT NULL,
                    details TEXT,
                    status TEXT NOT NULL
                )
            """)
    
    @contextmanager
    def get_db(self):
        """データベース接続のコンテキストマネージャー"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
            conn.commit()
        finally:
            conn.close()
    
    def log_command(self, command_type: str, command: str, 
                   parameters: Dict = None, result: Any = None, 
                   status: str = "success", duration_ms: int = None, 
                   error_message: str = None):
        """コマンドの実行をログに記録"""
        with self.get_db() as conn:
            conn.execute("""
                INSERT INTO command_history 
                (timestamp, command_type, command, parameters, result, status, duration_ms, error_message)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                datetime.now().isoformat(),
                command_type,
                command,
                json.dumps(parameters) if parameters else None,
                json.dumps(result) if result else None,
                status,
                duration_ms,
                error_message
            ))
    
    def log_issue_processing(self, issue_number: int, issue_title: str, 
                           action_type: str, details: str = None, 
                           status: str = "success"):
        """Issue処理のログを記録"""
        with self.get_db() as conn:
            conn.execute("""
                INSERT INTO issue_processing_log 
                (timestamp, issue_number, issue_title, action_type, details, status)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (
                datetime.now().isoformat(),
                issue_number,
                issue_title,
                action_type,
                details,
                status
            ))


class LoggingGitHubIssueTaskProcessor:
    """コマンドログ機能付きのGitHub Issue処理クラス"""
    
    def __init__(self, repo_owner: str, repo_name: str, github_token: str):
        self.repo_owner = repo_owner
        self.repo_name = repo_name
        self.headers = {
            "Authorization": f"token {github_token}",
            "Accept": "application/vnd.github.v3+json"
        }
        self.processed_issues = set()
        self.logger = CommandLogger()
        
        # ファイルログも設定
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('github_processor.log'),
                logging.StreamHandler()
            ]
        )
        self.file_logger = logging.getLogger(__name__)
    
    def execute_command(self, command_type: str, command: str, 
                       parameters: Dict = None) -> Dict:
        """コマンドを実行し、ログに記録"""
        start_time = time.time()
        result = None
        status = "success"
        error_message = None
        
        try:
            if command_type == "shell":
                # シェルコマンドの実行
                process = subprocess.run(
                    command, 
                    shell=True, 
                    capture_output=True, 
                    text=True
                )
                result = {
                    "stdout": process.stdout,
                    "stderr": process.stderr,
                    "returncode": process.returncode
                }
                if process.returncode != 0:
                    status = "error"
                    error_message = process.stderr
                    
            elif command_type == "api":
                # API呼び出し
                if command == "fetch_issues":
                    result = self._fetch_issues_with_logging(parameters)
                elif command == "add_comment":
                    result = self._add_comment_with_logging(
                        parameters["issue_number"], 
                        parameters["comment"]
                    )
                elif command == "update_labels":
                    result = self._update_labels_with_logging(
                        parameters["issue_number"], 
                        parameters["labels"]
                    )
                    
        except Exception as e:
            status = "error"
            error_message = str(e)
            self.file_logger.error(f"Command execution failed: {e}")
        
        duration_ms = int((time.time() - start_time) * 1000)
        
        # コマンドをログに記録
        self.logger.log_command(
            command_type=command_type,
            command=command,
            parameters=parameters,
            result=result,
            status=status,
            duration_ms=duration_ms,
            error_message=error_message
        )
        
        return {
            "status": status,
            "result": result,
            "error": error_message
        }
    
    def process_issue(self, issue: Dict) -> bool:
        """Issueを処理（すべてのアクションをログに記録）"""
        try:
            self.file_logger.info(f"Processing issue #{issue['number']}: {issue['title']}")
            
            # Issue処理開始をログに記録
            self.logger.log_issue_processing(
                issue_number=issue["number"],
                issue_title=issue["title"],
                action_type="process_start"
            )
            
            # カスタムスクリプトの実行（例）
            script_result = self.execute_command(
                command_type="shell",
                command=f"echo 'Processing issue {issue['number']}'",
                parameters={"issue_id": issue["id"]}
            )
            
            # コメントを追加
            comment_result = self.execute_command(
                command_type="api",
                command="add_comment",
                parameters={
                    "issue_number": issue["number"],
                    "comment": f"自動処理を開始しました。\n処理ID: {datetime.now().timestamp()}"
                }
            )
            
            # ラベルを更新
            label_result = self.execute_command(
                command_type="api",
                command="update_labels",
                parameters={
                    "issue_number": issue["number"],
                    "labels": ["processing", "automated"]
                }
            )
            
            # 処理済みとしてマーク
            self.processed_issues.add(issue["id"])
            
            # Issue処理完了をログに記録
            self.logger.log_issue_processing(
                issue_number=issue["number"],
                issue_title=issue["title"],
                action_type="process_complete",
                status="success"
            )
            
            return True
            
        except Exception as e:
            self.file_logger.error(f"Error processing issue #{issue['number']}: {e}")
            
            # エラーをログに記録
            self.logger.log_issue_processing(
                issue_number=issue["number"],
                issue_title=issue["title"],
                action_type="process_error",
                details=str(e),
                status="error"
            )
            
            return False
```

## 高度なカスタマイズ例

### 3. Issue内容に基づく処理の分岐

```python
class AdvancedGitHubTaskProcessor(LoggingGitHubIssueTaskProcessor):
    def process_issue(self, issue: Dict) -> bool:
        """issueの内容に基づいて異なる処理を実行"""
        try:
            print(f"\n処理開始: Issue #{issue['number']} - {issue['title']}")
            
            # issueのラベルに基づいて処理を分岐
            labels = [label["name"] for label in issue.get("labels", [])]
            
            if "bug" in labels:
                self.handle_bug_report(issue)
            elif "feature-request" in labels:
                self.handle_feature_request(issue)
            elif "documentation" in labels:
                self.handle_documentation_task(issue)
            else:
                self.handle_general_issue(issue)
            
            # 処理済みとしてマーク
            self.processed_issues.add(issue["id"])
            
            # ステータスラベルを更新
            self.update_labels(issue["number"], ["processed"])
            
            return True
            
        except Exception as e:
            print(f"Error processing issue #{issue['number']}: {e}")
            return False
    
    def handle_bug_report(self, issue: Dict):
        """バグレポートの処理"""
        print(f"バグレポートを処理中: {issue['title']}")
        
        # バグの重要度を解析
        if "critical" in issue["title"].lower():
            self.add_comment(issue["number"], 
                "🚨 クリティカルなバグとして認識しました。優先的に対応します。")
            self.update_labels(issue["number"], ["priority-high"])
        else:
            self.add_comment(issue["number"], 
                "バグレポートありがとうございます。確認後、対応いたします。")
```

## ログの可視化

### 4. Webダッシュボード

ログを可視化するHTMLダッシュボードでは、以下の情報を表示します：

- 総コマンド実行数
- 成功率
- 処理済みIssue数
- 平均処理時間
- コマンドタイプ別実行数（円グラフ）
- 時間別実行トレンド（折れ線グラフ）
- 最近のコマンド履歴（テーブル）

### 5. Web APIサーバー

Flask製のAPIサーバーで以下のエンドポイントを提供：

- `GET /api/logs/summary` - ログサマリーを取得
- `GET /api/logs/commands` - コマンド履歴を取得
- `GET /api/logs/timeline` - タイムラインデータを取得
- `GET /api/logs/errors` - エラーログを取得
- `GET /api/logs/search?q=keyword` - ログを検索
- `GET /api/logs/export` - ログをエクスポート

## 使用方法

### 環境設定

```bash
# 必要なパッケージのインストール
pip install requests flask flask-cors

# 環境変数の設定
export GITHUB_TOKEN="your-github-personal-access-token"
export REPO_OWNER="your-github-username"
export REPO_NAME="your-repository-name"
```

### Claude Codeでの実行

```bash
# 基本的な実行
claude-code --hook claude_code_hook github_task_processor.py

# ログ記録機能付きで実行
claude-code --hook claude_code_hook_with_logging github_task_processor.py

# カスタムラベルでフィルタリング
claude-code "ラベル'urgent'と'bug'のissueを処理して" github_task_processor.py
```

### 直接実行

```python
# プロセッサーの初期化
processor = LoggingGitHubIssueTaskProcessor(
    repo_owner="your-org",
    repo_name="your-repo",
    github_token="your-token"
)

# 特定のラベルでフィルタリング
processor.run_hook(labels=["auto-process", "bot-task"], wait_time=60)
```

### ログの可視化

```bash
# APIサーバーを起動
python log_api_server.py

# ブラウザでダッシュボードを開く
open dashboard.html
```

## ログデータベースの構造

### command_historyテーブル

| カラム名 | 型 | 説明 |
|---------|-----|------|
| id | INTEGER | 主キー |
| timestamp | TEXT | 実行時刻 (ISO8601形式) |
| command_type | TEXT | コマンドタイプ (api/shell) |
| command | TEXT | 実行したコマンド |
| parameters | TEXT | パラメータ (JSON) |
| result | TEXT | 実行結果 (JSON) |
| status | TEXT | ステータス (success/error) |
| duration_ms | INTEGER | 実行時間（ミリ秒） |
| error_message | TEXT | エラーメッセージ |

### issue_processing_logテーブル

| カラム名 | 型 | 説明 |
|---------|-----|------|
| id | INTEGER | 主キー |
| timestamp | TEXT | 処理時刻 |
| issue_number | INTEGER | Issue番号 |
| issue_title | TEXT | Issueタイトル |
| action_type | TEXT | アクションタイプ |
| details | TEXT | 詳細情報 |
| status | TEXT | ステータス |

## セキュリティとベストプラクティス

### セキュリティ考慮事項

1. **認証情報の管理**
   - GitHub Tokenは環境変数で管理
   - ログにセンシティブ情報を含めない
   - APIサーバーは本番環境では認証を実装

2. **SQLインジェクション対策**
   - パラメータバインディングを使用
   - ユーザー入力を直接SQLに含めない

3. **API制限の考慮**
   - GitHub API: 認証済み5,000リクエスト/時
   - 適切な待機時間を設定

### パフォーマンス最適化

1. **バッチ処理**
   - 複数のissueをまとめて取得
   - API呼び出しを最小限に

2. **データベース最適化**
   - インデックスの追加
   - 定期的な古いログの削除

3. **非同期処理**
   - 大量のタスクは非同期で処理
   - 並列実行で効率化

## トラブルシューティング

### よくある問題と解決策

1. **GitHub API レート制限エラー**
   ```python
   # 解決策：適切な待機時間を設定
   time.sleep(2)  # API呼び出し間隔を調整
   ```

2. **データベースロックエラー**
   ```sql
   -- WALモードを有効化
   PRAGMA journal_mode=WAL;
   ```

3. **メモリ使用量の増加**
   ```python
   # 定期的にprocessed_issuesをリセット
   if len(self.processed_issues) > 1000:
       self.processed_issues.clear()
   ```

## 拡張アイデア

1. **通知機能**
   - Slack/Discord webhookで通知
   - 重要なイベントをメール送信

2. **AI統合**
   - Claude APIでissueを自動分類
   - 自動返信の生成

3. **高度な可視化**
   - Grafana連携
   - リアルタイムダッシュボード

4. **マルチリポジトリ対応**
   - 複数のリポジトリを並列監視
   - 組織全体のissueを統合管理

## まとめ

このシステムにより、以下が実現できます：

- ✅ Claude Codeのhookを使った継続的なタスク処理
- ✅ GitHubのissueを自動的に検出・処理
- ✅ すべてのコマンド実行をログとして記録
- ✅ Webダッシュボードでリアルタイム監視
- ✅ 柔軟なカスタマイズと拡張性

Claude Codeは研究プレビュー版のため、最新情報は[Anthropicのブログ](https://www.anthropic.com)で確認してください。
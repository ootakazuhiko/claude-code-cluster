# Claude Code Agent実装仕様

各PC上で動作するClaude Code Agentの詳細実装

## 🏗️ Agent アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                Claude Code Agent                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Task      │  │ Workspace   │  │   Claude    │          │
│  │ Executor    │  │  Manager    │  │ API Client  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   GitHub    │  │    Git      │  │   Testing   │          │
│  │Integration  │  │  Handler    │  │   System    │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Local     │  │   Config    │  │ Monitoring  │          │
│  │ Database    │  │ Manager     │  │   Client    │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

## 📁 プロジェクト構造

```
agent/
├── src/
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py
│   │   ├── logging.py
│   │   └── exceptions.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── task_executor.py
│   │   ├── workspace_manager.py
│   │   ├── claude_client.py
│   │   ├── github_client.py
│   │   ├── git_handler.py
│   │   └── testing_system.py
│   ├── models/
│   │   ├── __init__.py
│   │   ├── task.py
│   │   ├── workspace.py
│   │   └── result.py
│   ├── api/
│   │   ├── __init__.py
│   │   ├── routes.py
│   │   └── middleware.py
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── file_utils.py
│   │   ├── security.py
│   │   └── metrics.py
│   └── specialties/
│       ├── __init__.py
│       ├── backend.py
│       ├── frontend.py
│       ├── testing.py
│       └── devops.py
├── workspace/
├── config/
├── logs/
├── tests/
├── docker/
├── main.py
├── requirements.txt
└── README.md
```

## 🔧 コア実装

### 1. メインアプリケーション

```python
# main.py
import asyncio
import signal
import uvicorn
from fastapi import FastAPI
from contextlib import asynccontextmanager

from src.core.config import get_settings
from src.core.logging import setup_logging
from src.services.task_executor import TaskExecutor
from src.services.workspace_manager import WorkspaceManager
from src.api.routes import router
from src.utils.metrics import setup_metrics

settings = get_settings()

class ClaudeCodeAgent:
    """Claude Code Agent メインクラス"""
    
    def __init__(self):
        self.task_executor = TaskExecutor()
        self.workspace_manager = WorkspaceManager()
        self.running = False
        
    async def start(self):
        """Agent開始"""
        self.running = True
        
        # ワークスペース初期化
        await self.workspace_manager.initialize()
        
        # Coordinatorに登録
        await self.register_with_coordinator()
        
        # ハートビート開始
        heartbeat_task = asyncio.create_task(self.heartbeat_loop())
        
        return heartbeat_task
    
    async def stop(self):
        """Agent停止"""
        self.running = False
        await self.task_executor.cancel_all_tasks()
        await self.workspace_manager.cleanup()
    
    async def register_with_coordinator(self):
        """Coordinatorへの登録"""
        import httpx
        
        registration_data = {
            "id": settings.AGENT_ID,
            "name": settings.AGENT_NAME,
            "hostname": settings.HOSTNAME,
            "ip_address": settings.IP_ADDRESS,
            "port": settings.PORT,
            "specialties": settings.SPECIALTIES,
            "capabilities": settings.CAPABILITIES,
            "max_concurrent_tasks": settings.MAX_CONCURRENT_TASKS,
            "cpu_cores": settings.CPU_CORES,
            "memory_gb": settings.MEMORY_GB,
            "disk_gb": settings.DISK_GB,
            "workspace_path": str(settings.WORKSPACE_PATH),
            "version": settings.VERSION
        }
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{settings.COORDINATOR_URL}/api/v1/agents",
                    json=registration_data,
                    headers={"Authorization": f"Bearer {settings.REGISTRATION_TOKEN}"},
                    timeout=30.0
                )
                
                if response.status_code == 200:
                    print(f"Successfully registered with coordinator: {settings.AGENT_ID}")
                else:
                    print(f"Failed to register with coordinator: {response.status_code}")
                    
            except Exception as e:
                print(f"Error registering with coordinator: {e}")
    
    async def heartbeat_loop(self):
        """ハートビートループ"""
        import httpx
        
        while self.running:
            try:
                status_data = {
                    "agent_id": settings.AGENT_ID,
                    "status": self.task_executor.get_status(),
                    "current_load": self.task_executor.get_load(),
                    "active_task_count": self.task_executor.get_active_task_count(),
                    "uptime": self.get_uptime(),
                    "last_task_completed_at": self.task_executor.get_last_completion_time()
                }
                
                async with httpx.AsyncClient() as client:
                    await client.put(
                        f"{settings.COORDINATOR_URL}/api/v1/agents/{settings.AGENT_ID}",
                        json=status_data,
                        headers={"Authorization": f"Bearer {settings.REGISTRATION_TOKEN}"},
                        timeout=10.0
                    )
                
                await asyncio.sleep(30)  # 30秒間隔
                
            except Exception as e:
                print(f"Heartbeat error: {e}")
                await asyncio.sleep(60)
    
    def get_uptime(self) -> float:
        """稼働時間を取得"""
        # 実装省略
        return 0.0

# FastAPI アプリケーション設定
agent_instance = ClaudeCodeAgent()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """アプリケーションライフサイクル"""
    
    # 起動時
    setup_logging()
    setup_metrics()
    heartbeat_task = await agent_instance.start()
    
    app.state.agent = agent_instance
    
    yield
    
    # 終了時
    await agent_instance.stop()
    heartbeat_task.cancel()

def create_app() -> FastAPI:
    """FastAPIアプリケーション作成"""
    
    app = FastAPI(
        title=f"Claude Code Agent - {settings.AGENT_ID}",
        description=f"Claude Code Agent specialized in {', '.join(settings.SPECIALTIES)}",
        version=settings.VERSION,
        lifespan=lifespan
    )
    
    app.include_router(router)
    
    return app

app = create_app()

def signal_handler(signum, frame):
    """シグナルハンドラ"""
    print(f"Received signal {signum}, shutting down...")
    asyncio.create_task(agent_instance.stop())

if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level=settings.LOG_LEVEL.lower()
    )
```

### 2. 設定管理

```python
# src/core/config.py
import os
import socket
from pathlib import Path
from typing import List, Optional
from pydantic_settings import BaseSettings
from pydantic import Field, validator

class AgentSettings(BaseSettings):
    """Agent設定"""
    
    # Agent基本情報
    AGENT_ID: str = Field(..., env="AGENT_ID")
    AGENT_NAME: str = Field(..., env="AGENT_NAME")
    VERSION: str = "1.0.0"
    
    # ネットワーク設定
    HOST: str = "0.0.0.0"
    PORT: int = 8081
    HOSTNAME: str = Field(default_factory=socket.gethostname)
    IP_ADDRESS: str = Field(..., env="IP_ADDRESS")
    
    # Coordinator設定
    COORDINATOR_URL: str = Field(..., env="COORDINATOR_URL")
    REGISTRATION_TOKEN: str = Field(..., env="REGISTRATION_TOKEN")
    
    # 専門性設定
    SPECIALTIES: List[str] = Field(..., env="SPECIALTIES")
    CAPABILITIES: List[str] = Field(..., env="CAPABILITIES") 
    
    # リソース設定
    MAX_CONCURRENT_TASKS: int = 3
    CPU_CORES: int = Field(..., env="CPU_CORES")
    MEMORY_GB: int = Field(..., env="MEMORY_GB")
    DISK_GB: int = Field(..., env="DISK_GB")
    
    # ワークスペース設定
    WORKSPACE_PATH: Path = Field(..., env="WORKSPACE_PATH")
    WORKSPACE_CLEANUP_DAYS: int = 7
    WORKSPACE_MAX_SIZE_GB: int = 100
    
    # 外部API設定
    ANTHROPIC_API_KEY: str = Field(..., env="ANTHROPIC_API_KEY")
    GITHUB_TOKEN: str = Field(..., env="GITHUB_TOKEN")
    
    # Git設定
    GIT_USER_NAME: str = Field(..., env="GIT_USER_NAME")
    GIT_USER_EMAIL: str = Field(..., env="GIT_USER_EMAIL")
    
    # タスク実行設定
    TASK_TIMEOUT_MINUTES: int = 60
    MAX_RETRY_ATTEMPTS: int = 3
    
    # ログ・監視設定
    LOG_LEVEL: str = "INFO"
    LOG_FILE: Optional[Path] = None
    DEBUG: bool = False
    METRICS_PORT: int = 9091
    
    @validator("SPECIALTIES", pre=True)
    def parse_specialties(cls, v):
        if isinstance(v, str):
            return [s.strip() for s in v.split(",")]
        return v
    
    @validator("CAPABILITIES", pre=True)
    def parse_capabilities(cls, v):
        if isinstance(v, str):
            return [c.strip() for c in v.split(",")]
        return v
    
    @validator("WORKSPACE_PATH", pre=True)
    def create_workspace_path(cls, v):
        path = Path(v)
        path.mkdir(parents=True, exist_ok=True)
        return path
    
    class Config:
        env_file = ".env"
        case_sensitive = True

def get_settings() -> AgentSettings:
    """設定インスタンス取得"""
    return AgentSettings()
```

### 3. Task Executor

```python
# src/services/task_executor.py
import asyncio
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from pathlib import Path

from src.core.config import get_settings
from src.models.task import Task, TaskResult, TaskStatus
from src.services.workspace_manager import WorkspaceManager
from src.services.claude_client import ClaudeClient
from src.services.github_client import GitHubClient
from src.services.git_handler import GitHandler
from src.services.testing_system import TestingSystem
from src.specialties import get_specialty_handler
from src.utils.metrics import task_metrics

logger = logging.getLogger(__name__)
settings = get_settings()

class TaskExecutor:
    """タスク実行システム"""
    
    def __init__(self):
        self.workspace_manager = WorkspaceManager()
        self.claude_client = ClaudeClient()
        self.github_client = GitHubClient()
        self.git_handler = GitHandler()
        self.testing_system = TestingSystem()
        
        self.active_tasks: Dict[str, asyncio.Task] = {}
        self.task_results: Dict[str, TaskResult] = {}
        
    async def execute_task(self, task_data: Dict[str, Any]) -> TaskResult:
        """メインタスク実行エントリーポイント"""
        
        task = Task.from_dict(task_data)
        task_id = task.id
        
        logger.info(f"Starting task execution: {task_id}")
        
        # 並行実行数チェック
        if len(self.active_tasks) >= settings.MAX_CONCURRENT_TASKS:
            raise Exception("Maximum concurrent tasks reached")
        
        # タスク実行を非同期で開始
        task_coroutine = self._execute_task_internal(task)
        async_task = asyncio.create_task(task_coroutine)
        self.active_tasks[task_id] = async_task
        
        try:
            # タイムアウト設定
            timeout_seconds = settings.TASK_TIMEOUT_MINUTES * 60
            result = await asyncio.wait_for(async_task, timeout=timeout_seconds)
            
            self.task_results[task_id] = result
            logger.info(f"Task {task_id} completed successfully")
            task_metrics.tasks_completed.inc()
            
            return result
            
        except asyncio.TimeoutError:
            logger.error(f"Task {task_id} timed out")
            async_task.cancel()
            result = TaskResult(
                task_id=task_id,
                status=TaskStatus.FAILED,
                error="Task execution timed out"
            )
            self.task_results[task_id] = result
            task_metrics.tasks_failed.inc()
            return result
            
        except Exception as e:
            logger.error(f"Task {task_id} failed: {e}")
            result = TaskResult(
                task_id=task_id,
                status=TaskStatus.FAILED,
                error=str(e)
            )
            self.task_results[task_id] = result
            task_metrics.tasks_failed.inc()
            return result
            
        finally:
            self.active_tasks.pop(task_id, None)
    
    async def _execute_task_internal(self, task: Task) -> TaskResult:
        """内部タスク実行ロジック"""
        
        start_time = datetime.now()
        
        try:
            # 1. ワークスペース準備
            workspace = await self.workspace_manager.prepare_workspace(task)
            logger.info(f"Workspace prepared: {workspace.path}")
            
            # 2. リポジトリクローン
            repo_path = await self.git_handler.clone_repository(
                workspace.path, task.github_repository
            )
            logger.info(f"Repository cloned: {repo_path}")
            
            # 3. コードベース分析
            codebase_analysis = await self._analyze_codebase(repo_path, task)
            logger.info(f"Codebase analyzed: {len(codebase_analysis.get('files', []))} files")
            
            # 4. 専門性ハンドラーによる事前処理
            specialty_handler = get_specialty_handler(settings.SPECIALTIES[0])
            if specialty_handler:
                await specialty_handler.pre_process(workspace, task)
            
            # 5. Claude APIで実装生成
            implementation = await self.claude_client.generate_implementation(
                task, codebase_analysis, workspace
            )
            logger.info(f"Implementation generated: {len(implementation.changes)} changes")
            
            # 6. コード変更適用
            applied_changes = await self._apply_code_changes(
                repo_path, implementation.changes
            )
            logger.info(f"Applied {len(applied_changes)} code changes")
            
            # 7. テスト実行
            test_results = await self.testing_system.run_tests(repo_path, task)
            logger.info(f"Tests completed: {test_results.summary}")
            
            # 8. 専門性ハンドラーによる後処理
            if specialty_handler:
                await specialty_handler.post_process(workspace, task, test_results)
            
            # 9. Git操作（ブランチ作成・コミット）
            branch_name = f"claude-{settings.AGENT_ID}-task-{task.id}"
            await self.git_handler.create_branch_and_commit(
                repo_path, branch_name, applied_changes, task
            )
            logger.info(f"Changes committed to branch: {branch_name}")
            
            # 10. Pull Request作成
            pr_url = await self.github_client.create_pull_request(
                task.github_repository, branch_name, task, implementation, test_results
            )
            logger.info(f"Pull Request created: {pr_url}")
            
            # 11. 実行時間計算
            execution_time = (datetime.now() - start_time).total_seconds()
            
            return TaskResult(
                task_id=task.id,
                status=TaskStatus.COMPLETED,
                pr_url=pr_url,
                branch_name=branch_name,
                changes_applied=applied_changes,
                test_results=test_results,
                execution_time=execution_time,
                agent_id=settings.AGENT_ID
            )
            
        except Exception as e:
            logger.error(f"Task execution failed: {e}", exc_info=True)
            raise
            
        finally:
            # ワークスペースクリーンアップ（設定による）
            if not settings.DEBUG:
                await self.workspace_manager.cleanup_workspace(task.id)
    
    async def _analyze_codebase(self, repo_path: Path, task: Task) -> Dict[str, Any]:
        """コードベース分析"""
        
        analysis = {
            "repository_path": str(repo_path),
            "files": [],
            "structure": {},
            "dependencies": {},
            "test_structure": {},
            "relevant_files": []
        }
        
        # ファイル構造分析
        for file_path in repo_path.rglob("*"):
            if file_path.is_file() and not self._should_ignore_file(file_path):
                relative_path = file_path.relative_to(repo_path)
                analysis["files"].append(str(relative_path))
        
        # タスクに関連するファイルを特定
        analysis["relevant_files"] = await self._identify_relevant_files(
            repo_path, task, analysis["files"]
        )
        
        # 依存関係分析
        analysis["dependencies"] = await self._analyze_dependencies(repo_path)
        
        # テスト構造分析
        analysis["test_structure"] = await self._analyze_test_structure(repo_path)
        
        return analysis
    
    def _should_ignore_file(self, file_path: Path) -> bool:
        """無視すべきファイルかチェック"""
        ignore_patterns = [
            ".*",  # 隠しファイル
            "__pycache__",
            "node_modules",
            ".git",
            "*.pyc",
            "*.log",
            "*.tmp"
        ]
        
        for pattern in ignore_patterns:
            if file_path.match(pattern) or any(part.startswith('.') for part in file_path.parts):
                return True
        return False
    
    async def _identify_relevant_files(self, repo_path: Path, task: Task, all_files: List[str]) -> List[str]:
        """タスクに関連するファイルを特定"""
        
        relevant_files = []
        
        # Issue番号に基づくファイル検索
        if task.github_issue_number:
            # 最近のコミットでIssue番号を含むファイルを検索
            # 実装省略
            pass
        
        # タスクタイトル/説明に基づくファイル検索
        keywords = self._extract_keywords_from_task(task)
        for file_path in all_files:
            if any(keyword.lower() in file_path.lower() for keyword in keywords):
                relevant_files.append(file_path)
        
        # 専門性に基づくファイル優先順位付け
        specialty_files = self._filter_files_by_specialty(all_files, settings.SPECIALTIES)
        relevant_files.extend(specialty_files)
        
        return list(set(relevant_files))  # 重複除去
    
    def _extract_keywords_from_task(self, task: Task) -> List[str]:
        """タスクからキーワードを抽出"""
        import re
        
        text = f"{task.title} {task.description}"
        
        # ファイル名、クラス名、関数名のパターンを抽出
        patterns = [
            r'\b\w+\.py\b',  # Python ファイル
            r'\b\w+\.ts\b',  # TypeScript ファイル
            r'\b\w+\.tsx\b', # TypeScript React ファイル
            r'\bclass\s+(\w+)',  # クラス名
            r'\bfunction\s+(\w+)',  # 関数名
            r'\bdef\s+(\w+)',  # Python 関数名
        ]
        
        keywords = []
        for pattern in patterns:
            matches = re.findall(pattern, text, re.IGNORECASE)
            keywords.extend(matches)
        
        return keywords
    
    def _filter_files_by_specialty(self, files: List[str], specialties: List[str]) -> List[str]:
        """専門性に基づくファイルフィルタリング"""
        
        specialty_patterns = {
            "backend": [r".*\.py$", r".*/api/.*", r".*/services/.*", r".*/models/.*"],
            "frontend": [r".*\.tsx?$", r".*\.jsx?$", r".*/components/.*", r".*/pages/.*"],
            "testing": [r".*test.*\.py$", r".*\.test\.ts$", r".*\.spec\.ts$"],
            "devops": [r".*\.yml$", r".*\.yaml$", r"Dockerfile", r"docker-compose.*"],
        }
        
        relevant_files = []
        for specialty in specialties:
            if specialty in specialty_patterns:
                patterns = specialty_patterns[specialty]
                for file_path in files:
                    if any(re.match(pattern, file_path) for pattern in patterns):
                        relevant_files.append(file_path)
        
        return relevant_files
    
    async def _apply_code_changes(self, repo_path: Path, changes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """コード変更の適用"""
        
        applied_changes = []
        
        for change in changes:
            try:
                file_path = repo_path / change["file_path"]
                
                if change["action"] == "create":
                    # 新規ファイル作成
                    file_path.parent.mkdir(parents=True, exist_ok=True)
                    file_path.write_text(change["content"], encoding="utf-8")
                    applied_changes.append(change)
                    
                elif change["action"] == "modify":
                    # ファイル修正
                    if file_path.exists():
                        file_path.write_text(change["content"], encoding="utf-8")
                        applied_changes.append(change)
                    else:
                        logger.warning(f"File to modify does not exist: {file_path}")
                        
                elif change["action"] == "delete":
                    # ファイル削除
                    if file_path.exists():
                        file_path.unlink()
                        applied_changes.append(change)
                    else:
                        logger.warning(f"File to delete does not exist: {file_path}")
                
            except Exception as e:
                logger.error(f"Failed to apply change to {change['file_path']}: {e}")
        
        return applied_changes
    
    async def cancel_task(self, task_id: str) -> bool:
        """タスクをキャンセル"""
        if task_id in self.active_tasks:
            task = self.active_tasks[task_id]
            task.cancel()
            
            try:
                await task
            except asyncio.CancelledError:
                pass
            
            self.active_tasks.pop(task_id, None)
            logger.info(f"Task {task_id} cancelled")
            return True
        
        return False
    
    async def cancel_all_tasks(self):
        """全タスクをキャンセル"""
        for task_id in list(self.active_tasks.keys()):
            await self.cancel_task(task_id)
    
    def get_status(self) -> str:
        """Agent状態を取得"""
        if len(self.active_tasks) == 0:
            return "idle"
        elif len(self.active_tasks) < settings.MAX_CONCURRENT_TASKS:
            return "busy"
        else:
            return "overloaded"
    
    def get_load(self) -> float:
        """負荷率を取得"""
        return len(self.active_tasks) / settings.MAX_CONCURRENT_TASKS
    
    def get_active_task_count(self) -> int:
        """アクティブタスク数を取得"""
        return len(self.active_tasks)
    
    def get_last_completion_time(self) -> Optional[datetime]:
        """最後のタスク完了時刻を取得"""
        # 実装省略
        return None
```

### 4. Workspace Manager

```python
# src/services/workspace_manager.py
import shutil
import asyncio
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

from src.core.config import get_settings
from src.models.workspace import TaskWorkspace
from src.models.task import Task

settings = get_settings()

class WorkspaceManager:
    """ワークスペース管理システム"""
    
    def __init__(self):
        self.base_path = settings.WORKSPACE_PATH
        self.base_path.mkdir(parents=True, exist_ok=True)
    
    async def initialize(self):
        """ワークスペース初期化"""
        
        # 基本ディレクトリ作成
        (self.base_path / "tasks").mkdir(exist_ok=True)
        (self.base_path / "shared").mkdir(exist_ok=True)
        (self.base_path / "logs").mkdir(exist_ok=True)
        (self.base_path / "cache").mkdir(exist_ok=True)
        (self.base_path / "templates").mkdir(exist_ok=True)
        
        # 古いワークスペースをクリーンアップ
        await self.cleanup_old_workspaces()
    
    async def prepare_workspace(self, task: Task) -> TaskWorkspace:
        """タスク専用ワークスペースを準備"""
        
        # タスクディレクトリ作成
        task_path = self.base_path / "tasks" / f"task-{task.id}"
        task_path.mkdir(parents=True, exist_ok=True)
        
        # サブディレクトリ作成
        (task_path / "repository").mkdir(exist_ok=True)
        (task_path / "implementation").mkdir(exist_ok=True)
        (task_path / "tests").mkdir(exist_ok=True)
        (task_path / "logs").mkdir(exist_ok=True)
        
        # メタデータファイル作成
        metadata_file = task_path / "metadata.json"
        metadata = {
            "task_id": task.id,
            "title": task.title,
            "created_at": datetime.now().isoformat(),
            "agent_id": settings.AGENT_ID,
            "specialties": settings.SPECIALTIES
        }
        
        import json
        metadata_file.write_text(json.dumps(metadata, indent=2))
        
        return TaskWorkspace(
            task_id=task.id,
            path=task_path,
            repository_path=task_path / "repository",
            implementation_path=task_path / "implementation",
            tests_path=task_path / "tests",
            logs_path=task_path / "logs"
        )
    
    async def cleanup_workspace(self, task_id: str):
        """特定タスクのワークスペースをクリーンアップ"""
        
        task_path = self.base_path / "tasks" / f"task-{task_id}"
        
        if task_path.exists():
            try:
                shutil.rmtree(task_path)
                print(f"Cleaned up workspace for task {task_id}")
            except Exception as e:
                print(f"Failed to cleanup workspace for task {task_id}: {e}")
    
    async def cleanup_old_workspaces(self):
        """古いワークスペースのクリーンアップ"""
        
        cutoff_date = datetime.now() - timedelta(days=settings.WORKSPACE_CLEANUP_DAYS)
        tasks_dir = self.base_path / "tasks"
        
        if not tasks_dir.exists():
            return
        
        for task_dir in tasks_dir.iterdir():
            if task_dir.is_dir():
                # メタデータから作成日時を確認
                metadata_file = task_dir / "metadata.json"
                
                if metadata_file.exists():
                    try:
                        import json
                        metadata = json.loads(metadata_file.read_text())
                        created_at = datetime.fromisoformat(metadata["created_at"])
                        
                        if created_at < cutoff_date:
                            shutil.rmtree(task_dir)
                            print(f"Cleaned up old workspace: {task_dir.name}")
                            
                    except Exception as e:
                        print(f"Error processing workspace {task_dir.name}: {e}")
                else:
                    # メタデータがない場合はファイル更新時刻で判断
                    if task_dir.stat().st_mtime < cutoff_date.timestamp():
                        shutil.rmtree(task_dir)
                        print(f"Cleaned up old workspace: {task_dir.name}")
    
    async def get_workspace_usage(self) -> dict:
        """ワークスペース使用量を取得"""
        
        def get_dir_size(path: Path) -> int:
            """ディレクトリサイズを取得"""
            total = 0
            try:
                for item in path.rglob("*"):
                    if item.is_file():
                        total += item.stat().st_size
            except (OSError, PermissionError):
                pass
            return total
        
        usage = {
            "total_size_bytes": get_dir_size(self.base_path),
            "total_size_gb": get_dir_size(self.base_path) / (1024**3),
            "task_count": len(list((self.base_path / "tasks").iterdir())) if (self.base_path / "tasks").exists() else 0,
            "max_size_gb": settings.WORKSPACE_MAX_SIZE_GB,
            "usage_percentage": 0.0
        }
        
        if settings.WORKSPACE_MAX_SIZE_GB > 0:
            usage["usage_percentage"] = usage["total_size_gb"] / settings.WORKSPACE_MAX_SIZE_GB * 100
        
        return usage
    
    async def ensure_disk_space(self, required_gb: float = 10.0) -> bool:
        """必要ディスク容量を確保"""
        
        usage = await self.get_workspace_usage()
        available_gb = settings.WORKSPACE_MAX_SIZE_GB - usage["total_size_gb"]
        
        if available_gb >= required_gb:
            return True
        
        # 古いワークスペースを積極的にクリーンアップ
        print(f"Disk space low ({available_gb:.1f}GB available), cleaning up...")
        
        # より短い期間での強制クリーンアップ
        cutoff_date = datetime.now() - timedelta(days=3)
        tasks_dir = self.base_path / "tasks"
        
        cleaned_space = 0.0
        for task_dir in tasks_dir.iterdir():
            if task_dir.is_dir():
                size_before = self.get_dir_size(task_dir) / (1024**3)
                
                metadata_file = task_dir / "metadata.json"
                if metadata_file.exists():
                    try:
                        import json
                        metadata = json.loads(metadata_file.read_text())
                        created_at = datetime.fromisoformat(metadata["created_at"])
                        
                        if created_at < cutoff_date:
                            shutil.rmtree(task_dir)
                            cleaned_space += size_before
                            print(f"Emergency cleanup: {task_dir.name} ({size_before:.1f}GB)")
                            
                            if cleaned_space >= required_gb:
                                break
                                
                    except Exception:
                        pass
        
        # 再チェック
        usage = await self.get_workspace_usage()
        available_gb = settings.WORKSPACE_MAX_SIZE_GB - usage["total_size_gb"]
        
        return available_gb >= required_gb
```

### 5. Claude Client

```python
# src/services/claude_client.py
import logging
from typing import Dict, Any, List
from anthropic import Anthropic

from src.core.config import get_settings
from src.models.task import Task
from src.models.workspace import TaskWorkspace

logger = logging.getLogger(__name__)
settings = get_settings()

class ClaudeClient:
    """Claude API クライアント"""
    
    def __init__(self):
        self.client = Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        self.model = "claude-3-sonnet-20240229"
    
    async def generate_implementation(
        self, 
        task: Task, 
        codebase_analysis: Dict[str, Any],
        workspace: TaskWorkspace
    ) -> 'ImplementationResult':
        """実装コードを生成"""
        
        # プロンプト構築
        system_prompt = self._build_system_prompt()
        user_prompt = self._build_user_prompt(task, codebase_analysis)
        
        try:
            # Claude API呼び出し
            message = self.client.messages.create(
                model=self.model,
                max_tokens=4000,
                system=system_prompt,
                messages=[{
                    "role": "user",
                    "content": user_prompt
                }]
            )
            
            response_text = message.content[0].text
            logger.info(f"Claude API response length: {len(response_text)} characters")
            
            # レスポンス解析
            implementation = self._parse_implementation_response(response_text)
            
            return implementation
            
        except Exception as e:
            logger.error(f"Claude API error: {e}")
            raise
    
    def _build_system_prompt(self) -> str:
        """システムプロンプト構築"""
        
        return f"""あなたは専門的なソフトウェア開発者です。

# Agent情報
- Agent ID: {settings.AGENT_ID}
- 専門分野: {', '.join(settings.SPECIALTIES)}
- 能力: {', '.join(settings.CAPABILITIES)}

# 開発方針
1. Test-Driven Development (TDD) に従って実装
2. 型安全性を重視（TypeScript/Python型ヒント）
3. 既存のコードスタイルに合わせる
4. セキュリティベストプラクティスに従う
5. パフォーマンスを考慮した実装

# 出力形式
実装結果をJSON形式で出力してください：

```json
{{
  "summary": "実装の概要説明",
  "approach": "採用したアプローチの説明",
  "changes": [
    {{
      "action": "create|modify|delete",
      "file_path": "相対ファイルパス",
      "content": "ファイルの全内容",
      "description": "変更の説明"
    }}
  ],
  "test_strategy": "テスト戦略の説明",
  "dependencies": ["新しく必要な依存関係"],
  "notes": "実装に関する注意事項"
}}
```

コードは必ず動作するものを生成し、構文エラーがないことを確認してください。"""
    
    def _build_user_prompt(self, task: Task, codebase_analysis: Dict[str, Any]) -> str:
        """ユーザープロンプト構築"""
        
        relevant_files_content = self._get_relevant_files_content(codebase_analysis)
        
        return f"""# タスク詳細

## Issue情報
- Issue番号: #{task.github_issue_number}
- タイトル: {task.title}
- 説明: {task.description}
- 優先度: {task.priority}
- 要件: {', '.join(task.requirements or [])}

## リポジトリ情報
- リポジトリ: {task.github_repository}
- 総ファイル数: {len(codebase_analysis.get('files', []))}
- 関連ファイル数: {len(codebase_analysis.get('relevant_files', []))}

## 現在のコードベース構造
```
{self._format_codebase_structure(codebase_analysis)}
```

## 関連ファイルの内容
{relevant_files_content}

## 依存関係情報
{self._format_dependencies(codebase_analysis.get('dependencies', {}))}

## テスト構造
{self._format_test_structure(codebase_analysis.get('test_structure', {}))}

# 実装要求

上記の情報を基に、Issue #{task.github_issue_number} の要求を満たす実装を生成してください。

特に以下の点に注意してください：
1. 既存のコードスタイルとパターンに従う
2. 適切なテストケースを含める
3. 型安全性を保つ
4. セキュリティを考慮する
5. パフォーマンスに配慮する

専門分野（{', '.join(settings.SPECIALTIES)}）の観点から最適な実装を提供してください。"""
    
    def _get_relevant_files_content(self, codebase_analysis: Dict[str, Any]) -> str:
        """関連ファイルの内容を取得"""
        
        # 実装省略 - 実際には関連ファイルの内容を読み込んで整形
        relevant_files = codebase_analysis.get('relevant_files', [])
        
        if not relevant_files:
            return "関連ファイルが特定されませんでした。"
        
        content = ""
        for file_path in relevant_files[:10]:  # 最大10ファイル
            content += f"\n## {file_path}\n```\n[ファイル内容]\n```\n"
        
        return content
    
    def _format_codebase_structure(self, codebase_analysis: Dict[str, Any]) -> str:
        """コードベース構造をフォーマット"""
        
        files = codebase_analysis.get('files', [])
        
        # ディレクトリ構造を構築
        structure = {}
        for file_path in files[:50]:  # 最大50ファイル表示
            parts = file_path.split('/')
            current = structure
            for part in parts[:-1]:
                if part not in current:
                    current[part] = {}
                current = current[part]
            current[parts[-1]] = None
        
        return self._dict_to_tree_string(structure)
    
    def _dict_to_tree_string(self, d: dict, prefix: str = "") -> str:
        """辞書をツリー構造の文字列に変換"""
        
        result = ""
        items = list(d.items())
        
        for i, (key, value) in enumerate(items):
            is_last = i == len(items) - 1
            current_prefix = "└── " if is_last else "├── "
            result += f"{prefix}{current_prefix}{key}\n"
            
            if isinstance(value, dict):
                next_prefix = prefix + ("    " if is_last else "│   ")
                result += self._dict_to_tree_string(value, next_prefix)
        
        return result
    
    def _format_dependencies(self, dependencies: Dict[str, Any]) -> str:
        """依存関係情報をフォーマット"""
        
        if not dependencies:
            return "依存関係情報がありません。"
        
        result = ""
        for key, value in dependencies.items():
            result += f"- {key}: {value}\n"
        
        return result
    
    def _format_test_structure(self, test_structure: Dict[str, Any]) -> str:
        """テスト構造をフォーマット"""
        
        if not test_structure:
            return "テスト構造情報がありません。"
        
        # 実装省略
        return "テスト構造: [フォーマット済み]"
    
    def _parse_implementation_response(self, response: str) -> 'ImplementationResult':
        """Claude APIレスポンスを解析"""
        
        import json
        import re
        
        # JSON部分を抽出
        json_match = re.search(r'```json\s*(\{.*?\})\s*```', response, re.DOTALL)
        
        if json_match:
            try:
                data = json.loads(json_match.group(1))
                
                from src.models.result import ImplementationResult
                return ImplementationResult(
                    summary=data.get('summary', ''),
                    approach=data.get('approach', ''),
                    changes=data.get('changes', []),
                    test_strategy=data.get('test_strategy', ''),
                    dependencies=data.get('dependencies', []),
                    notes=data.get('notes', '')
                )
                
            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse JSON response: {e}")
                raise
        
        else:
            logger.error("No JSON found in Claude response")
            raise ValueError("Invalid response format from Claude API")
```

この実装により、各Claude Code AgentはCoordinatorから受け取ったタスクを専門性を活かして効率的に実行できます。次はGitHub統合やDeployment関連のドキュメントを作成しますか？
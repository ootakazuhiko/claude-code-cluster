# Central Coordinator実装仕様

Claude Code Clusterの中央調整システムの詳細実装

## 🏗️ 全体アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                Central Coordinator                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │    API      │  │    Task     │  │   Agent     │          │
│  │  Gateway    │  │ Scheduler   │  │  Manager    │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   GitHub    │  │ WebSocket   │  │ Monitoring  │          │
│  │Integration  │  │  Handler    │  │   System    │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │PostgreSQL   │  │    Redis    │  │ Prometheus  │          │
│  │ Database    │  │   Cache     │  │ Metrics     │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

## 📁 プロジェクト構造

```
coordinator/
├── src/
│   ├── api/
│   │   ├── __init__.py
│   │   ├── routes/
│   │   │   ├── tasks.py
│   │   │   ├── agents.py
│   │   │   ├── webhook.py
│   │   │   └── health.py
│   │   ├── middleware/
│   │   │   ├── auth.py
│   │   │   ├── cors.py
│   │   │   └── logging.py
│   │   └── dependencies.py
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py
│   │   ├── database.py
│   │   ├── redis.py
│   │   └── exceptions.py
│   ├── models/
│   │   ├── __init__.py
│   │   ├── task.py
│   │   ├── agent.py
│   │   ├── user.py
│   │   └── workflow.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── task_scheduler.py
│   │   ├── agent_manager.py
│   │   ├── github_integration.py
│   │   ├── claude_coordinator.py
│   │   └── monitoring.py
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── task.py
│   │   ├── agent.py
│   │   └── response.py
│   └── utils/
│       ├── __init__.py
│       ├── security.py
│       ├── metrics.py
│       └── helpers.py
├── tests/
├── docker/
├── migrations/
├── config/
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
└── main.py
```

## 🔧 コア実装

### 1. メインアプリケーション

```python
# main.py
import asyncio
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from src.core.config import get_settings
from src.core.database import init_database
from src.core.redis import init_redis
from src.api.routes import tasks, agents, webhook, health
from src.api.middleware.auth import AuthMiddleware
from src.api.middleware.logging import LoggingMiddleware
from src.services.agent_manager import AgentManager
from src.services.task_scheduler import TaskScheduler
from src.services.github_integration import GitHubIntegration
from src.utils.metrics import setup_metrics

settings = get_settings()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """アプリケーションライフサイクル管理"""
    
    # 起動時初期化
    await init_database()
    await init_redis()
    setup_metrics()
    
    # バックグラウンドサービス開始
    agent_manager = AgentManager()
    task_scheduler = TaskScheduler()
    github_integration = GitHubIntegration()
    
    background_tasks = [
        asyncio.create_task(agent_manager.monitor_agents()),
        asyncio.create_task(task_scheduler.process_task_queue()),
        asyncio.create_task(github_integration.poll_github_events())
    ]
    
    app.state.agent_manager = agent_manager
    app.state.task_scheduler = task_scheduler
    app.state.github_integration = github_integration
    
    yield
    
    # 終了時クリーンアップ
    for task in background_tasks:
        task.cancel()
    
    await asyncio.gather(*background_tasks, return_exceptions=True)

def create_app() -> FastAPI:
    """FastAPIアプリケーション作成"""
    
    app = FastAPI(
        title="Claude Code Cluster Coordinator",
        description="Central coordination system for Claude Code agents",
        version="1.0.0",
        lifespan=lifespan
    )
    
    # ミドルウェア設定
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(AuthMiddleware)
    app.add_middleware(LoggingMiddleware)
    
    # ルート設定
    app.include_router(health.router, prefix="/health", tags=["health"])
    app.include_router(tasks.router, prefix="/api/v1/tasks", tags=["tasks"])
    app.include_router(agents.router, prefix="/api/v1/agents", tags=["agents"])
    app.include_router(webhook.router, prefix="/webhook", tags=["webhook"])
    
    return app

app = create_app()

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        workers=settings.WORKERS if not settings.DEBUG else 1
    )
```

### 2. 設定管理

```python
# src/core/config.py
import os
from typing import List, Optional
from pydantic_settings import BaseSettings
from pydantic import Field, validator

class Settings(BaseSettings):
    """アプリケーション設定"""
    
    # 基本設定
    APP_NAME: str = "Claude Code Coordinator"
    DEBUG: bool = False
    HOST: str = "0.0.0.0"
    PORT: int = 8080
    WORKERS: int = 4
    
    # データベース設定
    DATABASE_URL: str = Field(..., env="DATABASE_URL")
    DATABASE_POOL_SIZE: int = 20
    DATABASE_MAX_OVERFLOW: int = 0
    
    # Redis設定
    REDIS_URL: str = Field(..., env="REDIS_URL")
    REDIS_MAX_CONNECTIONS: int = 100
    
    # セキュリティ設定
    SECRET_KEY: str = Field(..., env="SECRET_KEY")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000"]
    
    # 外部API設定
    GITHUB_TOKEN: str = Field(..., env="GITHUB_TOKEN")
    GITHUB_WEBHOOK_SECRET: str = Field(..., env="GITHUB_WEBHOOK_SECRET")
    ANTHROPIC_API_KEY: str = Field(..., env="ANTHROPIC_API_KEY")
    
    # Agent管理設定
    MAX_AGENTS: int = 10
    AGENT_HEARTBEAT_TIMEOUT: int = 300  # 5分
    AGENT_REGISTRATION_TOKEN: str = Field(..., env="AGENT_REGISTRATION_TOKEN")
    
    # タスク設定
    MAX_CONCURRENT_TASKS: int = 50
    TASK_TIMEOUT: int = 3600  # 1時間
    TASK_RETRY_ATTEMPTS: int = 3
    
    # 監視設定
    METRICS_PORT: int = 9090
    LOG_LEVEL: str = "INFO"
    
    @validator("ALLOWED_ORIGINS", pre=True)
    def assemble_cors_origins(cls, v: str | List[str]) -> List[str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)
    
    class Config:
        env_file = ".env"
        case_sensitive = True

def get_settings() -> Settings:
    """設定インスタンス取得（キャッシュ機能付き）"""
    return Settings()
```

### 3. データベースモデル

```python
# src/models/task.py
from datetime import datetime
from enum import Enum
from typing import Optional, List, Dict, Any
from sqlalchemy import Column, Integer, String, DateTime, JSON, ForeignKey, Boolean, Text
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class TaskStatus(str, Enum):
    PENDING = "pending"
    ANALYZING = "analyzing"
    QUEUED = "queued"
    ASSIGNED = "assigned"
    IN_PROGRESS = "in_progress"
    TESTING = "testing"
    REVIEW = "review"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"

class TaskPriority(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    URGENT = "urgent"

class Task(Base):
    """タスクモデル"""
    __tablename__ = "tasks"
    
    id = Column(Integer, primary_key=True, index=True)
    
    # 基本情報
    title = Column(String(255), nullable=False)
    description = Column(Text)
    status = Column(String(50), default=TaskStatus.PENDING, index=True)
    priority = Column(String(20), default=TaskPriority.MEDIUM, index=True)
    
    # GitHub関連
    github_issue_number = Column(Integer, index=True)
    github_repository = Column(String(255))
    github_branch = Column(String(255))
    github_pr_number = Column(Integer, nullable=True)
    
    # タスク要件
    requirements = Column(JSON)  # List[str]
    estimated_complexity = Column(String(20))
    estimated_duration_minutes = Column(Integer)
    
    # Agent割り当て
    assigned_agent_id = Column(String(255), ForeignKey("agents.id"), nullable=True, index=True)
    assigned_at = Column(DateTime, nullable=True)
    
    # 実行情報
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    failed_at = Column(DateTime, nullable=True)
    
    # 結果情報
    result_data = Column(JSON, nullable=True)  # TaskResult
    error_message = Column(Text, nullable=True)
    retry_count = Column(Integer, default=0)
    
    # メタデータ
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_by = Column(String(255))
    
    # リレーション
    agent = relationship("Agent", back_populates="tasks")
    execution_logs = relationship("TaskExecutionLog", back_populates="task")

class TaskExecutionLog(Base):
    """タスク実行ログ"""
    __tablename__ = "task_execution_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id"), nullable=False, index=True)
    
    # ログ情報
    level = Column(String(20))  # INFO, WARNING, ERROR
    message = Column(Text)
    details = Column(JSON, nullable=True)
    
    # タイムスタンプ
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    
    # リレーション
    task = relationship("Task", back_populates="execution_logs")
```

```python
# src/models/agent.py
from datetime import datetime
from enum import Enum
from typing import Optional, List, Dict, Any
from sqlalchemy import Column, Integer, String, DateTime, JSON, Boolean, Float, Text
from sqlalchemy.orm import relationship

class AgentStatus(str, Enum):
    OFFLINE = "offline"
    IDLE = "idle"
    BUSY = "busy"
    OVERLOADED = "overloaded"
    MAINTENANCE = "maintenance"
    ERROR = "error"

class Agent(Base):
    """Agentモデル"""
    __tablename__ = "agents"
    
    id = Column(String(255), primary_key=True, index=True)  # agent_id
    
    # 基本情報
    name = Column(String(255), nullable=False)
    hostname = Column(String(255))
    ip_address = Column(String(45))  # IPv6対応
    port = Column(Integer, default=8081)
    
    # 能力情報
    specialties = Column(JSON)  # List[str]
    capabilities = Column(JSON)  # List[str] 
    max_concurrent_tasks = Column(Integer, default=3)
    
    # 状態情報
    status = Column(String(50), default=AgentStatus.OFFLINE, index=True)
    current_load = Column(Float, default=0.0)
    active_task_count = Column(Integer, default=0)
    
    # ハードウェア情報
    cpu_cores = Column(Integer)
    memory_gb = Column(Integer)
    disk_gb = Column(Integer)
    
    # 稼働統計
    total_tasks_completed = Column(Integer, default=0)
    total_tasks_failed = Column(Integer, default=0)
    average_task_duration = Column(Float, default=0.0)
    uptime_percentage = Column(Float, default=0.0)
    
    # タイムスタンプ
    last_heartbeat = Column(DateTime, nullable=True, index=True)
    registered_at = Column(DateTime, default=datetime.utcnow)
    last_task_completed_at = Column(DateTime, nullable=True)
    
    # 設定
    workspace_path = Column(String(512))
    configuration = Column(JSON, nullable=True)
    
    # メタデータ
    version = Column(String(50))
    metadata = Column(JSON, nullable=True)
    
    # リレーション
    tasks = relationship("Task", back_populates="agent")
    
    def can_accept_task(self, task: 'Task') -> bool:
        """タスクを受け入れ可能かチェック"""
        return (
            self.status == AgentStatus.IDLE and
            self.active_task_count < self.max_concurrent_tasks and
            any(cap in task.requirements for cap in self.capabilities or [])
        )
    
    def update_load(self):
        """負荷率を更新"""
        if self.max_concurrent_tasks > 0:
            self.current_load = self.active_task_count / self.max_concurrent_tasks
        else:
            self.current_load = 0.0
```

### 4. Task Scheduler

```python
# src/services/task_scheduler.py
import asyncio
import logging
from datetime import datetime, timedelta
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_

from src.core.database import get_db
from src.core.redis import get_redis
from src.models.task import Task, TaskStatus, TaskPriority
from src.models.agent import Agent, AgentStatus
from src.services.agent_manager import AgentManager
from src.utils.metrics import task_metrics

logger = logging.getLogger(__name__)

class TaskScheduler:
    """タスクスケジューリングシステム"""
    
    def __init__(self):
        self.agent_manager = AgentManager()
        self.running = False
        
    async def process_task_queue(self):
        """タスクキューの処理メインループ"""
        self.running = True
        logger.info("Task scheduler started")
        
        while self.running:
            try:
                await self._process_pending_tasks()
                await self._check_timeout_tasks()
                await self._retry_failed_tasks()
                await asyncio.sleep(10)  # 10秒間隔
                
            except Exception as e:
                logger.error(f"Error in task scheduler: {e}")
                await asyncio.sleep(30)  # エラー時は長めに待機
    
    async def _process_pending_tasks(self):
        """待機中のタスクを処理"""
        async with get_db() as db:
            # 優先度順で待機中タスクを取得
            pending_tasks = (
                db.query(Task)
                .filter(Task.status.in_([TaskStatus.PENDING, TaskStatus.QUEUED]))
                .order_by(
                    # 優先度順序
                    Task.priority == TaskPriority.URGENT,
                    Task.priority == TaskPriority.HIGH,
                    Task.priority == TaskPriority.MEDIUM,
                    Task.priority == TaskPriority.LOW,
                    Task.created_at.asc()
                )
                .limit(20)
                .all()
            )
            
            for task in pending_tasks:
                if task.status == TaskStatus.PENDING:
                    # タスク分析
                    await self._analyze_task(db, task)
                
                elif task.status == TaskStatus.QUEUED:
                    # Agent割り当て
                    assigned = await self._assign_task_to_agent(db, task)
                    if assigned:
                        task_metrics.tasks_assigned.inc()
    
    async def _analyze_task(self, db: Session, task: Task):
        """タスクを分析して要件を決定"""
        try:
            task.status = TaskStatus.ANALYZING
            
            # GitHub Issueから要件を分析
            analysis = await self._analyze_github_issue(task)
            
            task.requirements = analysis.requirements
            task.estimated_complexity = analysis.complexity
            task.estimated_duration_minutes = analysis.duration_minutes
            task.status = TaskStatus.QUEUED
            
            db.commit()
            logger.info(f"Task {task.id} analyzed: {analysis}")
            
        except Exception as e:
            task.status = TaskStatus.FAILED
            task.error_message = f"Analysis failed: {str(e)}"
            db.commit()
            logger.error(f"Failed to analyze task {task.id}: {e}")
    
    async def _assign_task_to_agent(self, db: Session, task: Task) -> bool:
        """タスクを最適なAgentに割り当て"""
        
        # 利用可能なAgentを取得
        available_agents = await self.agent_manager.get_available_agents(task.requirements)
        
        if not available_agents:
            logger.debug(f"No available agents for task {task.id}")
            return False
        
        # 最適なAgentを選択（負荷分散）
        selected_agent = self._select_best_agent(available_agents, task)
        
        # タスクを割り当て
        task.assigned_agent_id = selected_agent.id
        task.assigned_at = datetime.utcnow()
        task.status = TaskStatus.ASSIGNED
        
        # Agentの状態更新
        selected_agent.active_task_count += 1
        selected_agent.update_load()
        if selected_agent.status == AgentStatus.IDLE:
            selected_agent.status = AgentStatus.BUSY
        
        db.commit()
        
        # Agentにタスク送信
        success = await self.agent_manager.send_task_to_agent(selected_agent, task)
        
        if success:
            task.status = TaskStatus.IN_PROGRESS
            task.started_at = datetime.utcnow()
            db.commit()
            logger.info(f"Task {task.id} assigned to agent {selected_agent.id}")
            return True
        else:
            # 送信失敗時はロールバック
            task.assigned_agent_id = None
            task.assigned_at = None
            task.status = TaskStatus.QUEUED
            selected_agent.active_task_count -= 1
            selected_agent.update_load()
            db.commit()
            logger.error(f"Failed to send task {task.id} to agent {selected_agent.id}")
            return False
    
    def _select_best_agent(self, agents: List[Agent], task: Task) -> Agent:
        """最適なAgentを選択"""
        
        # スコアリング関数
        def calculate_score(agent: Agent) -> float:
            score = 0.0
            
            # 1. 専門性マッチング（重要度: 高）
            specialty_match = sum(
                1 for req in task.requirements
                if req in (agent.specialties or [])
            )
            score += specialty_match * 10
            
            # 2. 負荷状況（重要度: 中）
            load_penalty = agent.current_load * 5
            score -= load_penalty
            
            # 3. 過去の性能（重要度: 低）
            if agent.total_tasks_completed > 0:
                success_rate = agent.total_tasks_completed / (
                    agent.total_tasks_completed + agent.total_tasks_failed
                )
                score += success_rate * 2
            
            # 4. 推定作業時間との適合性
            if agent.average_task_duration > 0 and task.estimated_duration_minutes:
                duration_diff = abs(agent.average_task_duration - task.estimated_duration_minutes)
                duration_penalty = duration_diff / 60  # 時間単位でペナルティ
                score -= duration_penalty
            
            return score
        
        # 最高スコアのAgentを選択
        return max(agents, key=calculate_score)
    
    async def _check_timeout_tasks(self):
        """タイムアウトしたタスクをチェック"""
        timeout_threshold = datetime.utcnow() - timedelta(hours=1)
        
        async with get_db() as db:
            timeout_tasks = (
                db.query(Task)
                .filter(
                    and_(
                        Task.status == TaskStatus.IN_PROGRESS,
                        Task.started_at < timeout_threshold
                    )
                )
                .all()
            )
            
            for task in timeout_tasks:
                logger.warning(f"Task {task.id} timed out")
                await self._handle_task_timeout(db, task)
    
    async def _handle_task_timeout(self, db: Session, task: Task):
        """タスクタイムアウトの処理"""
        
        # Agentからタスクをキャンセル
        if task.assigned_agent_id:
            agent = db.query(Agent).filter(Agent.id == task.assigned_agent_id).first()
            if agent:
                await self.agent_manager.cancel_task_on_agent(agent, task.id)
                agent.active_task_count = max(0, agent.active_task_count - 1)
                agent.update_load()
        
        # タスクを再キューイング
        task.status = TaskStatus.QUEUED
        task.assigned_agent_id = None
        task.assigned_at = None
        task.started_at = None
        task.retry_count += 1
        
        db.commit()
        
    async def _retry_failed_tasks(self):
        """失敗したタスクのリトライ処理"""
        retry_threshold = datetime.utcnow() - timedelta(minutes=30)
        
        async with get_db() as db:
            retry_tasks = (
                db.query(Task)
                .filter(
                    and_(
                        Task.status == TaskStatus.FAILED,
                        Task.retry_count < 3,
                        Task.failed_at < retry_threshold
                    )
                )
                .all()
            )
            
            for task in retry_tasks:
                logger.info(f"Retrying task {task.id} (attempt {task.retry_count + 1})")
                task.status = TaskStatus.QUEUED
                task.error_message = None
                task.failed_at = None
                db.commit()

    async def stop(self):
        """スケジューラー停止"""
        self.running = False
        logger.info("Task scheduler stopped")
```

### 5. Agent Manager

```python
# src/services/agent_manager.py
import asyncio
import httpx
import logging
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import and_

from src.core.database import get_db
from src.models.agent import Agent, AgentStatus
from src.models.task import Task
from src.utils.metrics import agent_metrics

logger = logging.getLogger(__name__)

class AgentManager:
    """Agent管理システム"""
    
    def __init__(self):
        self.client = httpx.AsyncClient(timeout=30.0)
        self.running = False
    
    async def monitor_agents(self):
        """Agent監視メインループ"""
        self.running = True
        logger.info("Agent monitor started")
        
        while self.running:
            try:
                await self._check_agent_health()
                await self._update_agent_metrics()
                await asyncio.sleep(30)  # 30秒間隔
                
            except Exception as e:
                logger.error(f"Error in agent monitor: {e}")
                await asyncio.sleep(60)
    
    async def _check_agent_health(self):
        """全Agentのヘルスチェック"""
        timeout_threshold = datetime.utcnow() - timedelta(minutes=5)
        
        async with get_db() as db:
            agents = db.query(Agent).all()
            
            for agent in agents:
                if (agent.last_heartbeat and 
                    agent.last_heartbeat < timeout_threshold and 
                    agent.status != AgentStatus.OFFLINE):
                    
                    logger.warning(f"Agent {agent.id} appears to be offline")
                    await self._mark_agent_offline(db, agent)
                
                elif agent.status == AgentStatus.OFFLINE:
                    # オフラインAgentの復旧チェック
                    if await self._ping_agent(agent):
                        logger.info(f"Agent {agent.id} is back online")
                        agent.status = AgentStatus.IDLE
                        db.commit()
    
    async def _ping_agent(self, agent: Agent) -> bool:
        """個別Agentの疎通確認"""
        try:
            response = await self.client.get(
                f"http://{agent.ip_address}:{agent.port}/health",
                timeout=10.0
            )
            return response.status_code == 200
        except Exception:
            return False
    
    async def _mark_agent_offline(self, db: Session, agent: Agent):
        """Agentをオフライン状態にする"""
        agent.status = AgentStatus.OFFLINE
        
        # 実行中のタスクを再キューイング
        active_tasks = (
            db.query(Task)
            .filter(
                and_(
                    Task.assigned_agent_id == agent.id,
                    Task.status.in_(['assigned', 'in_progress'])
                )
            )
            .all()
        )
        
        for task in active_tasks:
            task.status = 'queued'
            task.assigned_agent_id = None
            task.assigned_at = None
            task.started_at = None
            logger.info(f"Re-queued task {task.id} due to agent {agent.id} offline")
        
        agent.active_task_count = 0
        agent.current_load = 0.0
        
        db.commit()
        agent_metrics.agent_offline.inc()
    
    async def register_agent(self, agent_data: Dict[str, Any]) -> Agent:
        """新しいAgentを登録"""
        async with get_db() as db:
            # 既存Agentの確認
            existing_agent = db.query(Agent).filter(Agent.id == agent_data["id"]).first()
            
            if existing_agent:
                # 既存Agentの更新
                for key, value in agent_data.items():
                    setattr(existing_agent, key, value)
                existing_agent.last_heartbeat = datetime.utcnow()
                existing_agent.status = AgentStatus.IDLE
                db.commit()
                logger.info(f"Updated existing agent: {existing_agent.id}")
                return existing_agent
            else:
                # 新規Agent作成
                agent = Agent(
                    id=agent_data["id"],
                    name=agent_data["name"],
                    hostname=agent_data.get("hostname"),
                    ip_address=agent_data["ip_address"],
                    port=agent_data.get("port", 8081),
                    specialties=agent_data.get("specialties", []),
                    capabilities=agent_data.get("capabilities", []),
                    max_concurrent_tasks=agent_data.get("max_concurrent_tasks", 3),
                    cpu_cores=agent_data.get("cpu_cores"),
                    memory_gb=agent_data.get("memory_gb"),
                    disk_gb=agent_data.get("disk_gb"),
                    workspace_path=agent_data.get("workspace_path"),
                    configuration=agent_data.get("configuration"),
                    version=agent_data.get("version"),
                    metadata=agent_data.get("metadata"),
                    last_heartbeat=datetime.utcnow(),
                    status=AgentStatus.IDLE
                )
                
                db.add(agent)
                db.commit()
                db.refresh(agent)
                
                logger.info(f"Registered new agent: {agent.id}")
                agent_metrics.agents_registered.inc()
                return agent
    
    async def get_available_agents(self, requirements: List[str]) -> List[Agent]:
        """要件に合致する利用可能なAgentを取得"""
        async with get_db() as db:
            agents = (
                db.query(Agent)
                .filter(
                    and_(
                        Agent.status.in_([AgentStatus.IDLE, AgentStatus.BUSY]),
                        Agent.active_task_count < Agent.max_concurrent_tasks
                    )
                )
                .all()
            )
            
            # 要件に合致するAgentをフィルタリング
            suitable_agents = []
            for agent in agents:
                if self._agent_matches_requirements(agent, requirements):
                    suitable_agents.append(agent)
            
            return suitable_agents
    
    def _agent_matches_requirements(self, agent: Agent, requirements: List[str]) -> bool:
        """Agentが要件に適合するかチェック"""
        if not requirements:
            return True
        
        agent_capabilities = set(agent.capabilities or [])
        agent_specialties = set(agent.specialties or [])
        
        # 要件のいずれかに合致すればOK
        return any(
            req in agent_capabilities or req in agent_specialties
            for req in requirements
        )
    
    async def send_task_to_agent(self, agent: Agent, task: Task) -> bool:
        """AgentにタスクをPOST送信"""
        try:
            task_data = {
                "task_id": str(task.id),
                "title": task.title,
                "description": task.description,
                "requirements": task.requirements,
                "github_issue_number": task.github_issue_number,
                "github_repository": task.github_repository,
                "priority": task.priority,
                "estimated_duration_minutes": task.estimated_duration_minutes
            }
            
            response = await self.client.post(
                f"http://{agent.ip_address}:{agent.port}/execute_task",
                json=task_data,
                timeout=30.0
            )
            
            if response.status_code == 200:
                logger.info(f"Successfully sent task {task.id} to agent {agent.id}")
                return True
            else:
                logger.error(f"Failed to send task {task.id} to agent {agent.id}: {response.status_code}")
                return False
                
        except Exception as e:
            logger.error(f"Error sending task {task.id} to agent {agent.id}: {e}")
            return False
    
    async def cancel_task_on_agent(self, agent: Agent, task_id: str) -> bool:
        """Agent上のタスクをキャンセル"""
        try:
            response = await self.client.post(
                f"http://{agent.ip_address}:{agent.port}/cancel_task/{task_id}",
                timeout=30.0
            )
            return response.status_code == 200
        except Exception as e:
            logger.error(f"Error cancelling task {task_id} on agent {agent.id}: {e}")
            return False
    
    async def _update_agent_metrics(self):
        """Agentメトリクスの更新"""
        async with get_db() as db:
            agents = db.query(Agent).all()
            
            # ステータス別のカウント
            status_counts = {}
            for agent in agents:
                status = agent.status
                status_counts[status] = status_counts.get(status, 0) + 1
            
            # Prometheusメトリクス更新
            for status, count in status_counts.items():
                agent_metrics.agents_by_status.labels(status=status).set(count)
            
            # 総Agent数
            agent_metrics.agents_total.set(len(agents))
            
            # 負荷情報
            if agents:
                total_load = sum(agent.current_load for agent in agents)
                average_load = total_load / len(agents)
                agent_metrics.cluster_average_load.set(average_load)

    async def stop(self):
        """Agent manager停止"""
        self.running = False
        await self.client.aclose()
        logger.info("Agent manager stopped")
```

この実装により、Central Coordinatorは効率的にタスクを分散し、Agentを管理できます。次は個別AgentやGitHub統合の実装を続けますか？
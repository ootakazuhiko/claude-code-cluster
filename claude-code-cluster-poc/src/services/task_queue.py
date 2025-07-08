"""Task queue system for async processing"""

import asyncio
import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, List, Optional, Callable
from dataclasses import dataclass, asdict
from enum import Enum

from src.core.config import get_settings
from src.utils.logging import get_logger


logger = get_logger(__name__)


class TaskPriority(Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    URGENT = "urgent"


@dataclass
class QueuedTask:
    """Queued task representation"""
    task_id: str
    priority: TaskPriority
    created_at: datetime
    attempts: int = 0
    max_attempts: int = 3
    next_retry: Optional[datetime] = None
    error: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        return {
            "task_id": self.task_id,
            "priority": self.priority.value,
            "created_at": self.created_at.isoformat(),
            "attempts": self.attempts,
            "max_attempts": self.max_attempts,
            "next_retry": self.next_retry.isoformat() if self.next_retry else None,
            "error": self.error
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'QueuedTask':
        """Create from dictionary"""
        return cls(
            task_id=data["task_id"],
            priority=TaskPriority(data["priority"]),
            created_at=datetime.fromisoformat(data["created_at"]),
            attempts=data["attempts"],
            max_attempts=data["max_attempts"],
            next_retry=datetime.fromisoformat(data["next_retry"]) if data["next_retry"] else None,
            error=data.get("error")
        )


class TaskQueue:
    """Asynchronous task queue"""
    
    def __init__(self):
        self.settings = get_settings()
        self.queue_file = self.settings.data_path / "task_queue.json"
        self.queue: List[QueuedTask] = []
        self.workers: List[asyncio.Task] = []
        self.running = False
        self.worker_count = 3
        self.processing_tasks: Dict[str, asyncio.Task] = {}
        
        # Load existing queue
        self._load_queue()
    
    def _load_queue(self):
        """Load queue from file"""
        if self.queue_file.exists():
            try:
                with open(self.queue_file, 'r') as f:
                    data = json.load(f)
                    self.queue = [QueuedTask.from_dict(item) for item in data.get("queue", [])]
                logger.info(f"Loaded {len(self.queue)} tasks from queue file")
            except Exception as e:
                logger.error(f"Failed to load queue: {e}")
                self.queue = []
    
    def _save_queue(self):
        """Save queue to file"""
        try:
            data = {
                "queue": [task.to_dict() for task in self.queue],
                "updated_at": datetime.now().isoformat()
            }
            with open(self.queue_file, 'w') as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            logger.error(f"Failed to save queue: {e}")
    
    async def add_task(self, task_id: str, priority: str = "medium") -> None:
        """Add task to queue"""
        try:
            priority_enum = TaskPriority(priority)
        except ValueError:
            priority_enum = TaskPriority.MEDIUM
        
        # Check if task already exists
        if any(task.task_id == task_id for task in self.queue):
            logger.warning(f"Task {task_id} already in queue")
            return
        
        queued_task = QueuedTask(
            task_id=task_id,
            priority=priority_enum,
            created_at=datetime.now()
        )
        
        self.queue.append(queued_task)
        self._sort_queue()
        self._save_queue()
        
        logger.info(f"Added task {task_id} to queue with priority {priority}")
    
    def _sort_queue(self):
        """Sort queue by priority and creation time"""
        priority_order = {
            TaskPriority.URGENT: 0,
            TaskPriority.HIGH: 1,
            TaskPriority.MEDIUM: 2,
            TaskPriority.LOW: 3
        }
        
        self.queue.sort(key=lambda x: (priority_order[x.priority], x.created_at))
    
    async def get_next_task(self) -> Optional[QueuedTask]:
        """Get next task from queue"""
        now = datetime.now()
        
        for i, task in enumerate(self.queue):
            # Skip if task is being processed
            if task.task_id in self.processing_tasks:
                continue
            
            # Skip if task is in retry cooldown
            if task.next_retry and now < task.next_retry:
                continue
            
            # Skip if task has exceeded max attempts
            if task.attempts >= task.max_attempts:
                continue
            
            # Remove from queue and return
            return self.queue.pop(i)
        
        return None
    
    async def mark_task_completed(self, task_id: str) -> None:
        """Mark task as completed"""
        if task_id in self.processing_tasks:
            self.processing_tasks[task_id].cancel()
            del self.processing_tasks[task_id]
        
        self._save_queue()
        logger.info(f"Task {task_id} completed")
    
    async def mark_task_failed(self, task_id: str, error: str) -> None:
        """Mark task as failed and handle retry"""
        if task_id in self.processing_tasks:
            del self.processing_tasks[task_id]
        
        # Create failed task for retry
        failed_task = QueuedTask(
            task_id=task_id,
            priority=TaskPriority.MEDIUM,
            created_at=datetime.now(),
            attempts=1,
            error=error,
            next_retry=datetime.now().replace(minute=datetime.now().minute + 5)  # Retry in 5 minutes
        )
        
        self.queue.append(failed_task)
        self._sort_queue()
        self._save_queue()
        
        logger.warning(f"Task {task_id} failed: {error}")
    
    async def start(self) -> None:
        """Start task queue processing"""
        if self.running:
            return
        
        self.running = True
        
        # Start worker tasks
        for i in range(self.worker_count):
            worker = asyncio.create_task(self._worker(f"worker-{i}"))
            self.workers.append(worker)
        
        logger.info(f"Started task queue with {self.worker_count} workers")
    
    async def stop(self) -> None:
        """Stop task queue processing"""
        self.running = False
        
        # Cancel all workers
        for worker in self.workers:
            worker.cancel()
        
        # Wait for workers to finish
        await asyncio.gather(*self.workers, return_exceptions=True)
        
        # Cancel processing tasks
        for task in self.processing_tasks.values():
            task.cancel()
        
        self.workers.clear()
        self.processing_tasks.clear()
        
        logger.info("Task queue stopped")
    
    async def _worker(self, worker_id: str) -> None:
        """Worker coroutine"""
        logger.info(f"Worker {worker_id} started")
        
        while self.running:
            try:
                # Get next task
                task = await self.get_next_task()
                
                if task is None:
                    # No tasks available, wait a bit
                    await asyncio.sleep(5)
                    continue
                
                # Process task
                logger.info(f"Worker {worker_id} processing task {task.task_id}")
                
                # Mark as processing
                process_task = asyncio.create_task(self._process_task(task))
                self.processing_tasks[task.task_id] = process_task
                
                try:
                    await process_task
                    await self.mark_task_completed(task.task_id)
                except Exception as e:
                    await self.mark_task_failed(task.task_id, str(e))
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Worker {worker_id} error: {e}")
                await asyncio.sleep(10)
        
        logger.info(f"Worker {worker_id} stopped")
    
    async def _process_task(self, task: QueuedTask) -> None:
        """Process a single task"""
        from src.services.agent import ClaudeAgent
        
        try:
            # Create agent instance
            agent = ClaudeAgent()
            
            # Update task attempts
            task.attempts += 1
            
            # Run the task
            result = agent.run_task(task.task_id)
            
            logger.info(f"Task {task.task_id} processed successfully")
            
        except Exception as e:
            logger.error(f"Task {task.task_id} processing failed: {e}")
            raise
    
    async def get_status(self) -> Dict[str, Any]:
        """Get queue status"""
        now = datetime.now()
        
        # Count tasks by status
        pending_tasks = len([t for t in self.queue if t.task_id not in self.processing_tasks])
        processing_tasks = len(self.processing_tasks)
        retry_tasks = len([t for t in self.queue if t.next_retry and t.next_retry > now])
        failed_tasks = len([t for t in self.queue if t.attempts >= t.max_attempts])
        
        return {
            "running": self.running,
            "workers": len(self.workers),
            "tasks": {
                "pending": pending_tasks,
                "processing": processing_tasks,
                "retry": retry_tasks,
                "failed": failed_tasks,
                "total": len(self.queue)
            },
            "queue_size": len(self.queue)
        }
    
    async def clear_failed_tasks(self) -> int:
        """Clear failed tasks from queue"""
        original_count = len(self.queue)
        self.queue = [task for task in self.queue if task.attempts < task.max_attempts]
        cleared_count = original_count - len(self.queue)
        
        if cleared_count > 0:
            self._save_queue()
            logger.info(f"Cleared {cleared_count} failed tasks")
        
        return cleared_count
    
    async def retry_failed_tasks(self) -> int:
        """Retry all failed tasks"""
        now = datetime.now()
        retried_count = 0
        
        for task in self.queue:
            if task.attempts >= task.max_attempts:
                task.attempts = 0
                task.next_retry = None
                task.error = None
                retried_count += 1
        
        if retried_count > 0:
            self._sort_queue()
            self._save_queue()
            logger.info(f"Retried {retried_count} failed tasks")
        
        return retried_count
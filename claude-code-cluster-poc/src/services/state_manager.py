"""State management using JSON files"""

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, List, Optional

from src.core.config import get_settings
from src.core.exceptions import TaskNotFoundError, InvalidTaskStateError
from src.utils.helpers import generate_task_id, current_timestamp, save_json, load_json


logger = logging.getLogger(__name__)


class StateManager:
    """JSON-based state management for tasks"""
    
    def __init__(self):
        self.settings = get_settings()
        self.tasks_file = self.settings.data_path / "tasks.json"
        self.config_file = self.settings.data_path / "config.json"
        
        # Ensure data directory exists
        self.settings.data_path.mkdir(exist_ok=True, parents=True)
        
        # Initialize files if they don't exist
        self._init_files()
    
    def _init_files(self) -> None:
        """Initialize JSON files if they don't exist"""
        if not self.tasks_file.exists():
            save_json({"tasks": {}, "metadata": {"created_at": current_timestamp()}}, self.tasks_file)
        
        if not self.config_file.exists():
            save_json({"version": "0.1.0", "created_at": current_timestamp()}, self.config_file)
    
    def create_task(self, issue_data: Dict[str, Any], analysis: Dict[str, Any]) -> str:
        """Create a new task from issue data"""
        
        task_id = generate_task_id()
        
        task = {
            "id": task_id,
            "status": "created",
            "created_at": current_timestamp(),
            "updated_at": current_timestamp(),
            
            # Issue information
            "issue": {
                "number": issue_data["number"],
                "title": issue_data["title"],
                "body": issue_data["body"],
                "labels": issue_data["labels"],
                "repository": issue_data["repository"]["full_name"],
                "html_url": issue_data["html_url"]
            },
            
            # Analysis results
            "analysis": analysis,
            
            # Execution data
            "execution": {
                "started_at": None,
                "completed_at": None,
                "duration_seconds": None,
                "error": None
            },
            
            # Results
            "results": {
                "implementation": None,
                "review": None,
                "git_branch": None,
                "pr_url": None,
                "pr_number": None
            }
        }
        
        # Save task
        self._save_task(task)
        
        logger.info(f"Created task {task_id} for issue #{issue_data['number']}")
        return task_id
    
    def get_task(self, task_id: str) -> Dict[str, Any]:
        """Get task by ID"""
        tasks_data = load_json(self.tasks_file)
        
        if not tasks_data or task_id not in tasks_data.get("tasks", {}):
            raise TaskNotFoundError(f"Task {task_id} not found")
        
        return tasks_data["tasks"][task_id]
    
    def update_task(self, task_id: str, updates: Dict[str, Any]) -> None:
        """Update task data"""
        tasks_data = load_json(self.tasks_file)
        
        if not tasks_data or task_id not in tasks_data.get("tasks", {}):
            raise TaskNotFoundError(f"Task {task_id} not found")
        
        task = tasks_data["tasks"][task_id]
        
        # Update fields
        for key, value in updates.items():
            if key in task:
                task[key] = value
            else:
                # Handle nested updates
                if "." in key:
                    parts = key.split(".", 1)
                    if parts[0] in task:
                        if isinstance(task[parts[0]], dict):
                            task[parts[0]][parts[1]] = value
        
        # Always update timestamp
        task["updated_at"] = current_timestamp()
        
        # Save updated data
        save_json(tasks_data, self.tasks_file)
        
        logger.info(f"Updated task {task_id}")
    
    def update_task_status(self, task_id: str, status: str, error: Optional[str] = None) -> None:
        """Update task status"""
        valid_statuses = ["created", "running", "completed", "failed", "cancelled"]
        
        if status not in valid_statuses:
            raise InvalidTaskStateError(f"Invalid status: {status}")
        
        updates = {"status": status}
        
        if status == "running":
            updates["execution.started_at"] = current_timestamp()
        elif status == "completed":
            updates["execution.completed_at"] = current_timestamp()
            # Calculate duration if started_at exists
            task = self.get_task(task_id)
            if task["execution"]["started_at"]:
                started = datetime.fromisoformat(task["execution"]["started_at"])
                completed = datetime.fromisoformat(current_timestamp())
                duration = (completed - started).total_seconds()
                updates["execution.duration_seconds"] = duration
        elif status == "failed":
            updates["execution.error"] = error or "Unknown error"
        
        self.update_task(task_id, updates)
    
    def save_task_implementation(self, task_id: str, implementation: Dict[str, Any]) -> None:
        """Save implementation results"""
        updates = {
            "results.implementation": implementation
        }
        self.update_task(task_id, updates)
    
    def save_task_review(self, task_id: str, review: Dict[str, Any]) -> None:
        """Save review results"""
        updates = {
            "results.review": review
        }
        self.update_task(task_id, updates)
    
    def save_task_git_info(self, task_id: str, branch: str, pr_url: Optional[str] = None, pr_number: Optional[int] = None) -> None:
        """Save git and PR information"""
        updates = {
            "results.git_branch": branch
        }
        
        if pr_url:
            updates["results.pr_url"] = pr_url
        if pr_number:
            updates["results.pr_number"] = pr_number
        
        self.update_task(task_id, updates)
    
    def list_tasks(self, status: Optional[str] = None) -> List[Dict[str, Any]]:
        """List all tasks, optionally filtered by status"""
        tasks_data = load_json(self.tasks_file)
        
        if not tasks_data:
            return []
        
        tasks = list(tasks_data.get("tasks", {}).values())
        
        if status:
            tasks = [task for task in tasks if task.get("status") == status]
        
        # Sort by created_at (newest first)
        tasks.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        
        return tasks
    
    def get_task_summary(self) -> Dict[str, Any]:
        """Get summary of all tasks"""
        tasks = self.list_tasks()
        
        status_counts = {}
        for task in tasks:
            status = task.get("status", "unknown")
            status_counts[status] = status_counts.get(status, 0) + 1
        
        return {
            "total_tasks": len(tasks),
            "status_counts": status_counts,
            "recent_tasks": tasks[:5]  # Last 5 tasks
        }
    
    def _save_task(self, task: Dict[str, Any]) -> None:
        """Save a single task to the JSON file"""
        tasks_data = load_json(self.tasks_file)
        
        if not tasks_data:
            tasks_data = {"tasks": {}, "metadata": {"created_at": current_timestamp()}}
        
        tasks_data["tasks"][task["id"]] = task
        tasks_data["metadata"]["updated_at"] = current_timestamp()
        
        save_json(tasks_data, self.tasks_file)
    
    def cleanup_old_tasks(self, days: int = 30) -> int:
        """Clean up old completed tasks"""
        from datetime import datetime, timedelta
        
        cutoff_date = datetime.now() - timedelta(days=days)
        tasks_data = load_json(self.tasks_file)
        
        if not tasks_data:
            return 0
        
        tasks = tasks_data.get("tasks", {})
        original_count = len(tasks)
        
        # Remove old completed tasks
        to_remove = []
        for task_id, task in tasks.items():
            if task.get("status") == "completed":
                created_at = datetime.fromisoformat(task.get("created_at", ""))
                if created_at < cutoff_date:
                    to_remove.append(task_id)
        
        for task_id in to_remove:
            del tasks[task_id]
        
        # Save updated data
        save_json(tasks_data, self.tasks_file)
        
        removed_count = len(to_remove)
        if removed_count > 0:
            logger.info(f"Cleaned up {removed_count} old tasks")
        
        return removed_count
    
    def export_tasks(self, output_file: Path) -> None:
        """Export tasks to a file"""
        tasks_data = load_json(self.tasks_file)
        
        if tasks_data:
            save_json(tasks_data, output_file)
            logger.info(f"Exported tasks to {output_file}")
        else:
            logger.warning("No tasks to export")
    
    def get_config(self) -> Dict[str, Any]:
        """Get configuration data"""
        return load_json(self.config_file) or {}
    
    def update_config(self, updates: Dict[str, Any]) -> None:
        """Update configuration"""
        config = self.get_config()
        config.update(updates)
        config["updated_at"] = current_timestamp()
        
        save_json(config, self.config_file)
        logger.info("Updated configuration")
"""Cluster coordination service for distributed processing"""

import asyncio
import logging
import json
import time
from typing import Dict, Any, List, Optional, Set
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict
from enum import Enum
import aiohttp
from pathlib import Path

from src.core.config import get_settings
from src.utils.logging import get_logger


logger = get_logger(__name__)


class NodeStatus(Enum):
    """Node status enumeration"""
    ONLINE = "online"
    OFFLINE = "offline"
    BUSY = "busy"
    MAINTENANCE = "maintenance"


class TaskStatus(Enum):
    """Task status enumeration"""
    PENDING = "pending"
    ASSIGNED = "assigned"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class AgentNode:
    """Agent node information"""
    node_id: str
    host: str
    port: int
    status: NodeStatus
    specialties: List[str]
    current_tasks: List[str]
    max_concurrent_tasks: int
    last_heartbeat: datetime
    capabilities: Dict[str, Any]
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        data = asdict(self)
        data["status"] = self.status.value
        data["last_heartbeat"] = self.last_heartbeat.isoformat()
        return data
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "AgentNode":
        """Create from dictionary"""
        data["status"] = NodeStatus(data["status"])
        data["last_heartbeat"] = datetime.fromisoformat(data["last_heartbeat"])
        return cls(**data)


@dataclass
class DistributedTask:
    """Distributed task information"""
    task_id: str
    priority: str
    requirements: List[str]
    assigned_node: Optional[str]
    status: TaskStatus
    created_at: datetime
    assigned_at: Optional[datetime]
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
    retry_count: int
    max_retries: int
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        data = asdict(self)
        data["status"] = self.status.value
        data["created_at"] = self.created_at.isoformat()
        if self.assigned_at:
            data["assigned_at"] = self.assigned_at.isoformat()
        if self.started_at:
            data["started_at"] = self.started_at.isoformat()
        if self.completed_at:
            data["completed_at"] = self.completed_at.isoformat()
        return data
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "DistributedTask":
        """Create from dictionary"""
        data["status"] = TaskStatus(data["status"])
        data["created_at"] = datetime.fromisoformat(data["created_at"])
        if data.get("assigned_at"):
            data["assigned_at"] = datetime.fromisoformat(data["assigned_at"])
        if data.get("started_at"):
            data["started_at"] = datetime.fromisoformat(data["started_at"])
        if data.get("completed_at"):
            data["completed_at"] = datetime.fromisoformat(data["completed_at"])
        return cls(**data)


class ClusterCoordinator:
    """Coordinates distributed task processing across multiple agent nodes"""
    
    def __init__(self, coordinator_port: int = 8001):
        self.settings = get_settings()
        self.coordinator_port = coordinator_port
        self.nodes: Dict[str, AgentNode] = {}
        self.tasks: Dict[str, DistributedTask] = {}
        self.heartbeat_interval = 30  # seconds
        self.heartbeat_timeout = 120  # seconds
        self.state_file = Path("cluster_state.json")
        
        # Load existing state
        self._load_state()
        
        logger.info(f"Cluster coordinator initialized on port {coordinator_port}")
    
    def _load_state(self) -> None:
        """Load cluster state from file"""
        if not self.state_file.exists():
            return
        
        try:
            with open(self.state_file, 'r') as f:
                state = json.load(f)
            
            # Load nodes
            for node_data in state.get("nodes", []):
                node = AgentNode.from_dict(node_data)
                self.nodes[node.node_id] = node
            
            # Load tasks
            for task_data in state.get("tasks", []):
                task = DistributedTask.from_dict(task_data)
                self.tasks[task.task_id] = task
            
            logger.info(f"Loaded cluster state: {len(self.nodes)} nodes, {len(self.tasks)} tasks")
        
        except Exception as e:
            logger.error(f"Failed to load cluster state: {e}")
    
    def _save_state(self) -> None:
        """Save cluster state to file"""
        try:
            state = {
                "nodes": [node.to_dict() for node in self.nodes.values()],
                "tasks": [task.to_dict() for task in self.tasks.values()],
                "updated_at": datetime.now().isoformat()
            }
            
            with open(self.state_file, 'w') as f:
                json.dump(state, f, indent=2)
        
        except Exception as e:
            logger.error(f"Failed to save cluster state: {e}")
    
    async def register_node(self, node: AgentNode) -> bool:
        """Register a new agent node"""
        try:
            # Check if node is reachable
            if await self._ping_node(node):
                self.nodes[node.node_id] = node
                self._save_state()
                logger.info(f"Registered node {node.node_id} at {node.host}:{node.port}")
                return True
            else:
                logger.warning(f"Failed to ping node {node.node_id} during registration")
                return False
        
        except Exception as e:
            logger.error(f"Failed to register node {node.node_id}: {e}")
            return False
    
    async def unregister_node(self, node_id: str) -> bool:
        """Unregister an agent node"""
        if node_id in self.nodes:
            # Reassign tasks from this node
            await self._reassign_node_tasks(node_id)
            
            del self.nodes[node_id]
            self._save_state()
            logger.info(f"Unregistered node {node_id}")
            return True
        
        return False
    
    async def _ping_node(self, node: AgentNode) -> bool:
        """Ping a node to check if it's alive"""
        try:
            timeout = aiohttp.ClientTimeout(total=5)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                url = f"http://{node.host}:{node.port}/health"
                async with session.get(url) as response:
                    return response.status == 200
        
        except Exception as e:
            logger.debug(f"Ping failed for node {node.node_id}: {e}")
            return False
    
    async def submit_task(self, task_id: str, priority: str = "medium", 
                         requirements: List[str] = None) -> bool:
        """Submit a task for distributed processing"""
        if task_id in self.tasks:
            logger.warning(f"Task {task_id} already exists")
            return False
        
        task = DistributedTask(
            task_id=task_id,
            priority=priority,
            requirements=requirements or [],
            assigned_node=None,
            status=TaskStatus.PENDING,
            created_at=datetime.now(),
            assigned_at=None,
            started_at=None,
            completed_at=None,
            retry_count=0,
            max_retries=3
        )
        
        self.tasks[task_id] = task
        self._save_state()
        
        # Try to assign immediately
        await self._assign_task(task_id)
        
        logger.info(f"Submitted task {task_id} with priority {priority}")
        return True
    
    async def _assign_task(self, task_id: str) -> bool:
        """Assign a task to the best available node"""
        task = self.tasks.get(task_id)
        if not task or task.status != TaskStatus.PENDING:
            return False
        
        # Find the best node for this task
        best_node = await self._find_best_node(task)
        if not best_node:
            logger.debug(f"No available node for task {task_id}")
            return False
        
        # Assign task to node
        try:
            if await self._send_task_to_node(task, best_node):
                task.assigned_node = best_node.node_id
                task.status = TaskStatus.ASSIGNED
                task.assigned_at = datetime.now()
                
                # Add task to node's current tasks
                best_node.current_tasks.append(task_id)
                
                self._save_state()
                logger.info(f"Assigned task {task_id} to node {best_node.node_id}")
                return True
        
        except Exception as e:
            logger.error(f"Failed to assign task {task_id} to node {best_node.node_id}: {e}")
        
        return False
    
    async def _find_best_node(self, task: DistributedTask) -> Optional[AgentNode]:
        """Find the best node for a task based on specialties and load"""
        available_nodes = []
        
        for node in self.nodes.values():
            if (node.status == NodeStatus.ONLINE and 
                len(node.current_tasks) < node.max_concurrent_tasks):
                available_nodes.append(node)
        
        if not available_nodes:
            return None
        
        # Score nodes based on specialty match and load
        node_scores = []
        for node in available_nodes:
            score = 0.0
            
            # Specialty matching score (0.0 to 1.0)
            if task.requirements:
                matching_specialties = set(task.requirements) & set(node.specialties)
                specialty_score = len(matching_specialties) / len(task.requirements)
                score += specialty_score * 0.7
            else:
                score += 0.5  # No specific requirements
            
            # Load score (less loaded = higher score)
            load_ratio = len(node.current_tasks) / node.max_concurrent_tasks
            load_score = 1.0 - load_ratio
            score += load_score * 0.3
            
            node_scores.append((node, score))
        
        # Sort by score (highest first)
        node_scores.sort(key=lambda x: x[1], reverse=True)
        
        return node_scores[0][0] if node_scores else None
    
    async def _send_task_to_node(self, task: DistributedTask, node: AgentNode) -> bool:
        """Send task assignment to a node"""
        try:
            timeout = aiohttp.ClientTimeout(total=10)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                url = f"http://{node.host}:{node.port}/api/tasks/{task.task_id}/assign"
                data = {
                    "task_id": task.task_id,
                    "priority": task.priority,
                    "requirements": task.requirements
                }
                
                async with session.post(url, json=data) as response:
                    return response.status == 200
        
        except Exception as e:
            logger.error(f"Failed to send task {task.task_id} to node {node.node_id}: {e}")
            return False
    
    async def update_task_status(self, task_id: str, status: str, 
                                node_id: str = None) -> bool:
        """Update task status from a node"""
        task = self.tasks.get(task_id)
        if not task:
            return False
        
        old_status = task.status
        task.status = TaskStatus(status)
        
        now = datetime.now()
        if status == "in_progress" and not task.started_at:
            task.started_at = now
        elif status in ["completed", "failed", "cancelled"] and not task.completed_at:
            task.completed_at = now
            
            # Remove from node's current tasks
            if task.assigned_node and task.assigned_node in self.nodes:
                node = self.nodes[task.assigned_node]
                if task_id in node.current_tasks:
                    node.current_tasks.remove(task_id)
        
        self._save_state()
        
        logger.info(f"Task {task_id} status updated: {old_status.value} -> {status}")
        
        # Handle retries for failed tasks
        if status == "failed" and task.retry_count < task.max_retries:
            await self._retry_task(task_id)
        
        return True
    
    async def _retry_task(self, task_id: str) -> None:
        """Retry a failed task"""
        task = self.tasks.get(task_id)
        if not task:
            return
        
        task.retry_count += 1
        task.status = TaskStatus.PENDING
        task.assigned_node = None
        task.assigned_at = None
        task.started_at = None
        task.completed_at = None
        
        logger.info(f"Retrying task {task_id} (attempt {task.retry_count}/{task.max_retries})")
        
        # Try to reassign
        await self._assign_task(task_id)
    
    async def _reassign_node_tasks(self, node_id: str) -> None:
        """Reassign tasks from a failed/removed node"""
        node = self.nodes.get(node_id)
        if not node:
            return
        
        for task_id in node.current_tasks.copy():
            task = self.tasks.get(task_id)
            if task and task.status in [TaskStatus.ASSIGNED, TaskStatus.IN_PROGRESS]:
                task.status = TaskStatus.PENDING
                task.assigned_node = None
                task.assigned_at = None
                task.started_at = None
                
                logger.info(f"Reassigning task {task_id} from failed node {node_id}")
                await self._assign_task(task_id)
        
        node.current_tasks.clear()
    
    async def heartbeat_monitor(self) -> None:
        """Monitor node heartbeats and handle failed nodes"""
        while True:
            try:
                current_time = datetime.now()
                failed_nodes = []
                
                for node_id, node in self.nodes.items():
                    if node.status == NodeStatus.ONLINE:
                        # Check if heartbeat is overdue
                        time_since_heartbeat = current_time - node.last_heartbeat
                        if time_since_heartbeat.total_seconds() > self.heartbeat_timeout:
                            logger.warning(f"Node {node_id} heartbeat timeout")
                            node.status = NodeStatus.OFFLINE
                            failed_nodes.append(node_id)
                        
                        # Try to ping the node
                        elif not await self._ping_node(node):
                            logger.warning(f"Node {node_id} ping failed")
                            node.status = NodeStatus.OFFLINE
                            failed_nodes.append(node_id)
                
                # Reassign tasks from failed nodes
                for node_id in failed_nodes:
                    await self._reassign_node_tasks(node_id)
                
                if failed_nodes:
                    self._save_state()
                
                # Try to reassign pending tasks
                pending_tasks = [
                    task_id for task_id, task in self.tasks.items()
                    if task.status == TaskStatus.PENDING
                ]
                
                for task_id in pending_tasks:
                    await self._assign_task(task_id)
                
                await asyncio.sleep(self.heartbeat_interval)
            
            except Exception as e:
                logger.error(f"Error in heartbeat monitor: {e}")
                await asyncio.sleep(self.heartbeat_interval)
    
    async def update_node_heartbeat(self, node_id: str) -> bool:
        """Update node heartbeat"""
        if node_id in self.nodes:
            self.nodes[node_id].last_heartbeat = datetime.now()
            if self.nodes[node_id].status == NodeStatus.OFFLINE:
                self.nodes[node_id].status = NodeStatus.ONLINE
            return True
        return False
    
    def get_cluster_status(self) -> Dict[str, Any]:
        """Get cluster status"""
        online_nodes = sum(1 for node in self.nodes.values() if node.status == NodeStatus.ONLINE)
        total_tasks = len(self.tasks)
        pending_tasks = sum(1 for task in self.tasks.values() if task.status == TaskStatus.PENDING)
        active_tasks = sum(1 for task in self.tasks.values() if task.status == TaskStatus.IN_PROGRESS)
        completed_tasks = sum(1 for task in self.tasks.values() if task.status == TaskStatus.COMPLETED)
        
        return {
            "nodes": {
                "total": len(self.nodes),
                "online": online_nodes,
                "offline": len(self.nodes) - online_nodes
            },
            "tasks": {
                "total": total_tasks,
                "pending": pending_tasks,
                "active": active_tasks,
                "completed": completed_tasks
            },
            "node_details": [node.to_dict() for node in self.nodes.values()],
            "task_details": [task.to_dict() for task in self.tasks.values()]
        }
    
    def get_node_status(self, node_id: str) -> Optional[Dict[str, Any]]:
        """Get specific node status"""
        node = self.nodes.get(node_id)
        return node.to_dict() if node else None
    
    def get_task_status(self, task_id: str) -> Optional[Dict[str, Any]]:
        """Get specific task status"""
        task = self.tasks.get(task_id)
        return task.to_dict() if task else None
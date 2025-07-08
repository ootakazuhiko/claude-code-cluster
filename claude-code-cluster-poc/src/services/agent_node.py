"""Agent node implementation for distributed processing"""

import asyncio
import logging
import json
import time
from typing import Dict, Any, List, Optional
from datetime import datetime
from pathlib import Path
import socket
import platform
import aiohttp
from fastapi import FastAPI, HTTPException, BackgroundTasks
from contextlib import asynccontextmanager

from src.core.config import get_settings
from src.services.agent import Agent
from src.services.cluster_coordinator import AgentNode, NodeStatus
from src.utils.logging import get_logger


logger = get_logger(__name__)


class DistributedAgentNode:
    """Agent node for distributed processing"""
    
    def __init__(self, node_id: str = None, coordinator_host: str = "localhost", 
                 coordinator_port: int = 8001, agent_port: int = 8002,
                 specialties: List[str] = None, max_concurrent_tasks: int = 3):
        self.settings = get_settings()
        
        # Node configuration
        self.node_id = node_id or self._generate_node_id()
        self.coordinator_host = coordinator_host
        self.coordinator_port = coordinator_port
        self.agent_port = agent_port
        self.host = self._get_local_ip()
        
        # Node capabilities
        self.specialties = specialties or ["general"]
        self.max_concurrent_tasks = max_concurrent_tasks
        self.current_tasks: List[str] = []
        
        # Node state
        self.status = NodeStatus.OFFLINE
        self.registered = False
        self.heartbeat_interval = 30  # seconds
        
        # Services
        self.agent = Agent()
        self.app = self._create_fastapi_app()
        
        logger.info(f"Initialized agent node {self.node_id} on {self.host}:{self.agent_port}")
    
    def _generate_node_id(self) -> str:
        """Generate unique node ID"""
        hostname = platform.node()
        timestamp = int(time.time())
        return f"agent-{hostname}-{timestamp}"
    
    def _get_local_ip(self) -> str:
        """Get local IP address"""
        try:
            # Connect to a remote server to get local IP
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.connect(("8.8.8.8", 80))
                return s.getsockname()[0]
        except Exception:
            return "127.0.0.1"
    
    def _create_fastapi_app(self) -> FastAPI:
        """Create FastAPI application for the agent node"""
        
        @asynccontextmanager
        async def lifespan(app: FastAPI):
            # Startup
            await self.startup()
            yield
            # Shutdown
            await self.shutdown()
        
        app = FastAPI(
            title="Claude Code Cluster Agent Node",
            description="Distributed agent node for task processing",
            version="0.1.0",
            lifespan=lifespan
        )
        
        # Health check endpoint
        @app.get("/health")
        async def health_check():
            return {
                "status": "healthy",
                "node_id": self.node_id,
                "current_tasks": len(self.current_tasks),
                "max_tasks": self.max_concurrent_tasks,
                "specialties": self.specialties
            }
        
        # Node info endpoint
        @app.get("/api/node/info")
        async def get_node_info():
            return {
                "node_id": self.node_id,
                "host": self.host,
                "port": self.agent_port,
                "status": self.status.value,
                "specialties": self.specialties,
                "current_tasks": self.current_tasks,
                "max_concurrent_tasks": self.max_concurrent_tasks,
                "system_info": {
                    "platform": platform.platform(),
                    "python_version": platform.python_version(),
                    "cpu_count": os.cpu_count() if 'os' in globals() else None
                }
            }
        
        # Task assignment endpoint
        @app.post("/api/tasks/{task_id}/assign")
        async def assign_task(task_id: str, task_data: Dict[str, Any], 
                             background_tasks: BackgroundTasks):
            if len(self.current_tasks) >= self.max_concurrent_tasks:
                raise HTTPException(status_code=503, detail="Node at capacity")
            
            if task_id in self.current_tasks:
                raise HTTPException(status_code=409, detail="Task already assigned")
            
            # Add task to current tasks
            self.current_tasks.append(task_id)
            
            # Process task in background
            background_tasks.add_task(self._process_task, task_id, task_data)
            
            return {"status": "accepted", "task_id": task_id}
        
        # Task status endpoint
        @app.get("/api/tasks/{task_id}/status")
        async def get_task_status(task_id: str):
            # Get task status from agent
            status = self.agent.get_task_status(task_id)
            if not status:
                raise HTTPException(status_code=404, detail="Task not found")
            return status
        
        # Stop task endpoint
        @app.post("/api/tasks/{task_id}/stop")
        async def stop_task(task_id: str):
            if task_id not in self.current_tasks:
                raise HTTPException(status_code=404, detail="Task not found")
            
            # Remove from current tasks
            if task_id in self.current_tasks:
                self.current_tasks.remove(task_id)
            
            # Notify coordinator
            await self._notify_coordinator_task_status(task_id, "cancelled")
            
            return {"status": "cancelled", "task_id": task_id}
        
        return app
    
    async def startup(self) -> None:
        """Startup procedures"""
        logger.info(f"Starting agent node {self.node_id}")
        
        # Register with coordinator
        await self._register_with_coordinator()
        
        # Start heartbeat task
        asyncio.create_task(self._heartbeat_loop())
        
        self.status = NodeStatus.ONLINE
        logger.info(f"Agent node {self.node_id} started successfully")
    
    async def shutdown(self) -> None:
        """Shutdown procedures"""
        logger.info(f"Shutting down agent node {self.node_id}")
        
        self.status = NodeStatus.OFFLINE
        
        # Unregister from coordinator
        await self._unregister_from_coordinator()
        
        logger.info(f"Agent node {self.node_id} shut down")
    
    async def _register_with_coordinator(self) -> bool:
        """Register this node with the cluster coordinator"""
        try:
            node_info = AgentNode(
                node_id=self.node_id,
                host=self.host,
                port=self.agent_port,
                status=NodeStatus.ONLINE,
                specialties=self.specialties,
                current_tasks=self.current_tasks,
                max_concurrent_tasks=self.max_concurrent_tasks,
                last_heartbeat=datetime.now(),
                capabilities={
                    "platform": platform.platform(),
                    "python_version": platform.python_version()
                }
            )
            
            timeout = aiohttp.ClientTimeout(total=10)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                url = f"http://{self.coordinator_host}:{self.coordinator_port}/api/nodes/register"
                data = node_info.to_dict()
                
                async with session.post(url, json=data) as response:
                    if response.status == 200:
                        self.registered = True
                        logger.info(f"Successfully registered with coordinator")
                        return True
                    else:
                        logger.error(f"Failed to register: HTTP {response.status}")
                        return False
        
        except Exception as e:
            logger.error(f"Failed to register with coordinator: {e}")
            return False
    
    async def _unregister_from_coordinator(self) -> bool:
        """Unregister this node from the cluster coordinator"""
        if not self.registered:
            return True
        
        try:
            timeout = aiohttp.ClientTimeout(total=5)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                url = f"http://{self.coordinator_host}:{self.coordinator_port}/api/nodes/{self.node_id}/unregister"
                
                async with session.delete(url) as response:
                    if response.status in [200, 404]:
                        self.registered = False
                        logger.info(f"Successfully unregistered from coordinator")
                        return True
                    else:
                        logger.error(f"Failed to unregister: HTTP {response.status}")
                        return False
        
        except Exception as e:
            logger.error(f"Failed to unregister from coordinator: {e}")
            return False
    
    async def _heartbeat_loop(self) -> None:
        """Send periodic heartbeats to coordinator"""
        while self.status == NodeStatus.ONLINE:
            try:
                await self._send_heartbeat()
                await asyncio.sleep(self.heartbeat_interval)
            except Exception as e:
                logger.error(f"Error in heartbeat loop: {e}")
                await asyncio.sleep(self.heartbeat_interval)
    
    async def _send_heartbeat(self) -> bool:
        """Send heartbeat to coordinator"""
        if not self.registered:
            return False
        
        try:
            timeout = aiohttp.ClientTimeout(total=5)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                url = f"http://{self.coordinator_host}:{self.coordinator_port}/api/nodes/{self.node_id}/heartbeat"
                data = {
                    "current_tasks": self.current_tasks,
                    "status": self.status.value,
                    "timestamp": datetime.now().isoformat()
                }
                
                async with session.post(url, json=data) as response:
                    return response.status == 200
        
        except Exception as e:
            logger.debug(f"Heartbeat failed: {e}")
            return False
    
    async def _process_task(self, task_id: str, task_data: Dict[str, Any]) -> None:
        """Process an assigned task"""
        try:
            logger.info(f"Starting task {task_id}")
            
            # Notify coordinator that task is starting
            await self._notify_coordinator_task_status(task_id, "in_progress")
            
            # Execute the task using the agent
            result = await self._execute_task(task_id, task_data)
            
            if result["success"]:
                await self._notify_coordinator_task_status(task_id, "completed")
                logger.info(f"Task {task_id} completed successfully")
            else:
                await self._notify_coordinator_task_status(task_id, "failed")
                logger.error(f"Task {task_id} failed: {result.get('error')}")
        
        except Exception as e:
            logger.error(f"Error processing task {task_id}: {e}")
            await self._notify_coordinator_task_status(task_id, "failed")
        
        finally:
            # Remove from current tasks
            if task_id in self.current_tasks:
                self.current_tasks.remove(task_id)
    
    async def _execute_task(self, task_id: str, task_data: Dict[str, Any]) -> Dict[str, Any]:
        """Execute the actual task"""
        try:
            # Run the task using the agent
            result = self.agent.run_task(task_id)
            return {"success": True, "result": result}
        
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def _notify_coordinator_task_status(self, task_id: str, status: str) -> bool:
        """Notify coordinator of task status change"""
        try:
            timeout = aiohttp.ClientTimeout(total=10)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                url = f"http://{self.coordinator_host}:{self.coordinator_port}/api/tasks/{task_id}/status"
                data = {
                    "status": status,
                    "node_id": self.node_id,
                    "timestamp": datetime.now().isoformat()
                }
                
                async with session.put(url, json=data) as response:
                    return response.status == 200
        
        except Exception as e:
            logger.error(f"Failed to notify coordinator of task status: {e}")
            return False
    
    def get_node_status(self) -> Dict[str, Any]:
        """Get current node status"""
        return {
            "node_id": self.node_id,
            "host": self.host,
            "port": self.agent_port,
            "status": self.status.value,
            "specialties": self.specialties,
            "current_tasks": self.current_tasks,
            "max_concurrent_tasks": self.max_concurrent_tasks,
            "registered": self.registered,
            "coordinator": f"{self.coordinator_host}:{self.coordinator_port}"
        }


# Import os here to avoid issues with globals check
import os
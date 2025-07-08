"""API server for cluster coordinator"""

import asyncio
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime
from fastapi import FastAPI, HTTPException, BackgroundTasks
from contextlib import asynccontextmanager
import uvicorn

from src.services.cluster_coordinator import ClusterCoordinator, AgentNode, NodeStatus
from src.utils.logging import get_logger


logger = get_logger(__name__)


class CoordinatorAPI:
    """API server for the cluster coordinator"""
    
    def __init__(self, coordinator_port: int = 8001):
        self.coordinator_port = coordinator_port
        self.coordinator = ClusterCoordinator(coordinator_port)
        self.app = self._create_fastapi_app()
        self.heartbeat_task = None
    
    def _create_fastapi_app(self) -> FastAPI:
        """Create FastAPI application for the coordinator"""
        
        @asynccontextmanager
        async def lifespan(app: FastAPI):
            # Startup
            await self.startup()
            yield
            # Shutdown
            await self.shutdown()
        
        app = FastAPI(
            title="Claude Code Cluster Coordinator",
            description="Distributed task coordination service",
            version="0.1.0",
            lifespan=lifespan
        )
        
        # Health check
        @app.get("/health")
        async def health_check():
            return {"status": "healthy", "coordinator": "online"}
        
        # Cluster status
        @app.get("/api/cluster/status")
        async def get_cluster_status():
            return self.coordinator.get_cluster_status()
        
        # Node registration
        @app.post("/api/nodes/register")
        async def register_node(node_data: Dict[str, Any]):
            try:
                node = AgentNode.from_dict(node_data)
                success = await self.coordinator.register_node(node)
                if success:
                    return {"status": "registered", "node_id": node.node_id}
                else:
                    raise HTTPException(status_code=400, detail="Failed to register node")
            except Exception as e:
                logger.error(f"Error registering node: {e}")
                raise HTTPException(status_code=400, detail=str(e))
        
        # Node unregistration
        @app.delete("/api/nodes/{node_id}/unregister")
        async def unregister_node(node_id: str):
            success = await self.coordinator.unregister_node(node_id)
            if success:
                return {"status": "unregistered", "node_id": node_id}
            else:
                raise HTTPException(status_code=404, detail="Node not found")
        
        # Node heartbeat
        @app.post("/api/nodes/{node_id}/heartbeat")
        async def node_heartbeat(node_id: str, heartbeat_data: Dict[str, Any]):
            success = await self.coordinator.update_node_heartbeat(node_id)
            if success:
                # Update node status if provided
                if "current_tasks" in heartbeat_data:
                    if node_id in self.coordinator.nodes:
                        self.coordinator.nodes[node_id].current_tasks = heartbeat_data["current_tasks"]
                
                return {"status": "acknowledged"}
            else:
                raise HTTPException(status_code=404, detail="Node not found")
        
        # Get node status
        @app.get("/api/nodes/{node_id}")
        async def get_node_status(node_id: str):
            status = self.coordinator.get_node_status(node_id)
            if status:
                return status
            else:
                raise HTTPException(status_code=404, detail="Node not found")
        
        # List all nodes
        @app.get("/api/nodes")
        async def list_nodes():
            return {
                "nodes": [node.to_dict() for node in self.coordinator.nodes.values()]
            }
        
        # Task submission
        @app.post("/api/tasks")
        async def submit_task(task_data: Dict[str, Any]):
            task_id = task_data.get("task_id")
            priority = task_data.get("priority", "medium")
            requirements = task_data.get("requirements", [])
            
            if not task_id:
                raise HTTPException(status_code=400, detail="task_id is required")
            
            success = await self.coordinator.submit_task(task_id, priority, requirements)
            if success:
                return {"status": "submitted", "task_id": task_id}
            else:
                raise HTTPException(status_code=409, detail="Task already exists")
        
        # Task status update
        @app.put("/api/tasks/{task_id}/status")
        async def update_task_status(task_id: str, status_data: Dict[str, Any]):
            status = status_data.get("status")
            node_id = status_data.get("node_id")
            
            if not status:
                raise HTTPException(status_code=400, detail="status is required")
            
            success = await self.coordinator.update_task_status(task_id, status, node_id)
            if success:
                return {"status": "updated", "task_id": task_id}
            else:
                raise HTTPException(status_code=404, detail="Task not found")
        
        # Get task status
        @app.get("/api/tasks/{task_id}")
        async def get_task_status(task_id: str):
            status = self.coordinator.get_task_status(task_id)
            if status:
                return status
            else:
                raise HTTPException(status_code=404, detail="Task not found")
        
        # List all tasks
        @app.get("/api/tasks")
        async def list_tasks(status: Optional[str] = None):
            tasks = list(self.coordinator.tasks.values())
            
            if status:
                tasks = [task for task in tasks if task.status.value == status]
            
            return {
                "tasks": [task.to_dict() for task in tasks]
            }
        
        # Cancel task
        @app.delete("/api/tasks/{task_id}")
        async def cancel_task(task_id: str):
            success = await self.coordinator.update_task_status(task_id, "cancelled")
            if success:
                return {"status": "cancelled", "task_id": task_id}
            else:
                raise HTTPException(status_code=404, detail="Task not found")
        
        # Queue status
        @app.get("/api/queue/status")
        async def get_queue_status():
            cluster_status = self.coordinator.get_cluster_status()
            return {
                "pending_tasks": cluster_status["tasks"]["pending"],
                "active_tasks": cluster_status["tasks"]["active"],
                "completed_tasks": cluster_status["tasks"]["completed"],
                "available_nodes": cluster_status["nodes"]["online"],
                "total_capacity": sum(
                    node.max_concurrent_tasks 
                    for node in self.coordinator.nodes.values() 
                    if node.status == NodeStatus.ONLINE
                ),
                "current_load": sum(
                    len(node.current_tasks) 
                    for node in self.coordinator.nodes.values() 
                    if node.status == NodeStatus.ONLINE
                )
            }
        
        # Node management endpoints
        @app.post("/api/nodes/{node_id}/maintenance")
        async def set_node_maintenance(node_id: str):
            if node_id in self.coordinator.nodes:
                self.coordinator.nodes[node_id].status = NodeStatus.MAINTENANCE
                await self.coordinator._reassign_node_tasks(node_id)
                return {"status": "maintenance", "node_id": node_id}
            else:
                raise HTTPException(status_code=404, detail="Node not found")
        
        @app.post("/api/nodes/{node_id}/online")
        async def set_node_online(node_id: str):
            if node_id in self.coordinator.nodes:
                self.coordinator.nodes[node_id].status = NodeStatus.ONLINE
                return {"status": "online", "node_id": node_id}
            else:
                raise HTTPException(status_code=404, detail="Node not found")
        
        return app
    
    async def startup(self) -> None:
        """Startup procedures"""
        logger.info("Starting cluster coordinator API")
        
        # Start heartbeat monitor
        self.heartbeat_task = asyncio.create_task(self.coordinator.heartbeat_monitor())
        
        logger.info(f"Cluster coordinator API started on port {self.coordinator_port}")
    
    async def shutdown(self) -> None:
        """Shutdown procedures"""
        logger.info("Shutting down cluster coordinator API")
        
        # Stop heartbeat monitor
        if self.heartbeat_task:
            self.heartbeat_task.cancel()
            try:
                await self.heartbeat_task
            except asyncio.CancelledError:
                pass
        
        logger.info("Cluster coordinator API shut down")
    
    def run(self, host: str = "0.0.0.0", reload: bool = False) -> None:
        """Run the coordinator API server"""
        uvicorn.run(
            self.app,
            host=host,
            port=self.coordinator_port,
            reload=reload,
            log_level="info"
        )


def create_coordinator_app(port: int = 8001) -> FastAPI:
    """Create coordinator FastAPI app for external use"""
    coordinator_api = CoordinatorAPI(port)
    return coordinator_api.app


if __name__ == "__main__":
    # Run coordinator directly
    coordinator = CoordinatorAPI()
    coordinator.run()
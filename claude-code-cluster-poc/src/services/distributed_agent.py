"""Enhanced agent with specialized agent selection and distributed processing"""

import asyncio
import logging
from typing import Dict, Any, List, Optional
from pathlib import Path

from src.services.agent import Agent
from src.agents.base_agent import BaseSpecializedAgent
from src.agents.backend_agent import BackendAgent
from src.agents.frontend_agent import FrontendAgent
from src.agents.testing_agent import TestingAgent
from src.agents.devops_agent import DevOpsAgent
from src.services.cluster_coordinator import ClusterCoordinator
from src.utils.logging import get_logger


logger = get_logger(__name__)


class DistributedAgent(Agent):
    """Enhanced agent with specialized agent selection and distributed processing support"""
    
    def __init__(self, use_distributed: bool = False, coordinator_host: str = "localhost", 
                 coordinator_port: int = 8001):
        super().__init__()
        
        # Distributed processing configuration
        self.use_distributed = use_distributed
        self.coordinator_host = coordinator_host
        self.coordinator_port = coordinator_port
        self.coordinator = None
        
        # Initialize specialized agents
        self.specialized_agents = {
            "backend": BackendAgent(),
            "frontend": FrontendAgent(), 
            "testing": TestingAgent(),
            "devops": DevOpsAgent()
        }
        
        logger.info(f"Distributed agent initialized with {len(self.specialized_agents)} specialized agents")
        
        if use_distributed:
            self._initialize_coordinator()
    
    def _initialize_coordinator(self) -> None:
        """Initialize connection to cluster coordinator"""
        try:
            self.coordinator = ClusterCoordinator()
            logger.info("Connected to cluster coordinator")
        except Exception as e:
            logger.warning(f"Failed to connect to coordinator: {e}")
            self.use_distributed = False
    
    def select_best_agent(self, task: Dict[str, Any]) -> BaseSpecializedAgent:
        """Select the best specialized agent for a task"""
        agent_scores = {}
        
        # Score each specialized agent
        for agent_name, agent in self.specialized_agents.items():
            try:
                score = agent.get_confidence_score(task)
                agent_scores[agent_name] = score
                logger.debug(f"Agent {agent_name} scored {score:.3f} for task")
            except Exception as e:
                logger.error(f"Error scoring agent {agent_name}: {e}")
                agent_scores[agent_name] = 0.0
        
        # Find the best agent
        if not agent_scores:
            logger.warning("No agents available, using fallback")
            return None
        
        best_agent_name = max(agent_scores, key=agent_scores.get)
        best_score = agent_scores[best_agent_name]
        
        # Use specialized agent if score is high enough, otherwise use general agent
        if best_score >= 0.3:  # Minimum confidence threshold
            selected_agent = self.specialized_agents[best_agent_name]
            logger.info(f"Selected {best_agent_name} agent (score: {best_score:.3f})")
            return selected_agent
        else:
            logger.info(f"No specialized agent confident enough (best: {best_score:.3f}), using general agent")
            return None
    
    async def run_task_distributed(self, task_id: str) -> Dict[str, Any]:
        """Run task using distributed processing if available"""
        if not self.use_distributed or not self.coordinator:
            return self.run_task(task_id)
        
        try:
            # Get task data
            task = self.state_manager.get_task(task_id)
            if not task:
                return {"success": False, "error": "Task not found"}
            
            # Determine requirements based on analysis
            requirements = []
            analysis = task.get("analysis", {})
            
            # Map analysis to requirements
            if analysis.get("needs_database") or analysis.get("needs_api"):
                requirements.append("backend")
            if analysis.get("needs_component") or analysis.get("needs_styling"):
                requirements.append("frontend")
            if analysis.get("needs_testing") or analysis.get("needs_bug_fix"):
                requirements.append("testing")
            if analysis.get("needs_cicd") or analysis.get("needs_infrastructure"):
                requirements.append("devops")
            
            # Submit to cluster coordinator
            priority = analysis.get("priority", "medium")
            success = await self.coordinator.submit_task(task_id, priority, requirements)
            
            if success:
                logger.info(f"Task {task_id} submitted to distributed cluster")
                
                # Wait for completion or timeout
                return await self._wait_for_distributed_completion(task_id, timeout=3600)
            else:
                logger.warning(f"Failed to submit task {task_id} to cluster, running locally")
                return self.run_task(task_id)
        
        except Exception as e:
            logger.error(f"Error in distributed processing: {e}")
            return self.run_task(task_id)
    
    async def _wait_for_distributed_completion(self, task_id: str, timeout: int = 3600) -> Dict[str, Any]:
        """Wait for distributed task completion"""
        start_time = asyncio.get_event_loop().time()
        
        while True:
            try:
                # Check if task is completed
                task_status = self.coordinator.get_task_status(task_id)
                if not task_status:
                    return {"success": False, "error": "Task not found in coordinator"}
                
                status = task_status.get("status")
                if status == "completed":
                    logger.info(f"Distributed task {task_id} completed")
                    return {"success": True, "distributed": True, "task_status": task_status}
                elif status == "failed":
                    logger.error(f"Distributed task {task_id} failed")
                    return {"success": False, "error": "Task failed on remote node", "task_status": task_status}
                elif status == "cancelled":
                    logger.warning(f"Distributed task {task_id} was cancelled")
                    return {"success": False, "error": "Task was cancelled", "task_status": task_status}
                
                # Check timeout
                if asyncio.get_event_loop().time() - start_time > timeout:
                    logger.error(f"Distributed task {task_id} timed out")
                    return {"success": False, "error": "Task timed out"}
                
                # Wait before checking again
                await asyncio.sleep(5)
            
            except Exception as e:
                logger.error(f"Error waiting for task completion: {e}")
                return {"success": False, "error": str(e)}
    
    def run_task(self, task_id: str) -> Dict[str, Any]:
        """Enhanced run_task with specialized agent selection"""
        try:
            # Get task data
            task = self.state_manager.get_task(task_id)
            if not task:
                logger.error(f"Task {task_id} not found")
                return {"success": False, "error": "Task not found"}
            
            # Select best specialized agent
            specialized_agent = self.select_best_agent(task)
            
            if specialized_agent:
                return self._run_task_with_specialized_agent(task_id, task, specialized_agent)
            else:
                # Fall back to general agent processing
                return super().run_task(task_id)
        
        except Exception as e:
            logger.error(f"Error in enhanced run_task: {e}")
            return {"success": False, "error": str(e)}
    
    def _run_task_with_specialized_agent(self, task_id: str, task: Dict[str, Any], 
                                        agent: BaseSpecializedAgent) -> Dict[str, Any]:
        """Run task using a specialized agent"""
        try:
            logger.info(f"Running task {task_id} with {agent.__class__.__name__}")
            
            # Update task status
            self.state_manager.update_task_status(task_id, "in_progress")
            
            # Get issue data and repository context
            issue_data = task["issue"]
            repo_context = self._get_repository_context()
            
            # Analyze task requirements with specialized agent
            task_analysis = agent.analyze_task_requirements(task)
            
            # Get relevant files using agent's patterns
            relevant_files = self._get_relevant_files_for_agent(agent, repo_context)
            
            # Enhance prompt with agent specialization
            base_prompt = self._build_implementation_prompt(issue_data, repo_context, task["analysis"]["requirements"])
            enhanced_prompt = agent.enhance_prompt(base_prompt, task)
            
            # Generate implementation using specialized model
            claude_model = agent.get_claude_model()
            implementation = self.claude_client.generate_implementation(
                issue_data, 
                repo_context, 
                task["analysis"]["requirements"],
                model=claude_model,
                system_prompt=enhanced_prompt
            )
            
            if implementation["success"]:
                # Validate implementation with specialized agent
                validation = agent.validate_implementation(implementation, task)
                
                if validation["valid"]:
                    # Apply changes
                    changes_applied = self._apply_implementation_changes(implementation["changes"])
                    
                    if changes_applied:
                        # Create pull request
                        pr_result = self._create_pull_request(task_id, implementation, agent)
                        
                        # Update task status
                        self.state_manager.update_task_status(task_id, "completed")
                        
                        return {
                            "success": True,
                            "specialized_agent": agent.__class__.__name__,
                            "task_analysis": task_analysis,
                            "validation": validation,
                            "implementation": implementation,
                            "pull_request": pr_result
                        }
                    else:
                        self.state_manager.update_task_status(task_id, "failed", "Failed to apply changes")
                        return {"success": False, "error": "Failed to apply implementation changes"}
                else:
                    self.state_manager.update_task_status(task_id, "failed", "Validation failed")
                    return {"success": False, "error": "Implementation validation failed", "validation": validation}
            else:
                self.state_manager.update_task_status(task_id, "failed", "Implementation generation failed")
                return {"success": False, "error": "Failed to generate implementation"}
        
        except Exception as e:
            self.state_manager.update_task_status(task_id, "failed", str(e))
            logger.error(f"Error in specialized agent task execution: {e}")
            return {"success": False, "error": str(e)}
    
    def _get_relevant_files_for_agent(self, agent: BaseSpecializedAgent, 
                                     repo_context: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Get files relevant to the specialized agent"""
        all_files = repo_context.get("files", [])
        return agent.filter_relevant_files(all_files)
    
    def _create_pull_request(self, task_id: str, implementation: Dict[str, Any], 
                           agent: BaseSpecializedAgent) -> Dict[str, Any]:
        """Create pull request with specialized agent context"""
        task = self.state_manager.get_task(task_id)
        issue_data = task["issue"]
        
        # Build PR description with agent-specific information
        pr_description = f"""## Summary
{implementation.get('summary', 'Implementation for ' + issue_data['title'])}

## Specialized Agent
This implementation was generated by **{agent.__class__.__name__}** with the following specialties:
- {', '.join(agent.specialties)}

## Changes Made
{self._format_changes_for_pr(implementation['changes'])}

## Testing Strategy
{self._format_testing_strategy(agent.get_testing_strategy(task))}

## Review Criteria
{self._format_review_criteria(agent.get_review_criteria(task))}

🤖 Generated with [Claude Code Cluster PoC](https://github.com/claude-code-cluster)

Agent: {agent.__class__.__name__}
Task ID: {task_id}
"""
        
        # Create PR using GitHub client
        try:
            pr_result = self.github_client.create_pull_request(
                title=f"[{agent.__class__.__name__}] {issue_data['title']}",
                body=pr_description,
                issue_number=issue_data["number"]
            )
            
            return {"success": True, "pr_url": pr_result.get("url")}
        
        except Exception as e:
            logger.error(f"Failed to create pull request: {e}")
            return {"success": False, "error": str(e)}
    
    def _format_testing_strategy(self, strategy: List[str]) -> str:
        """Format testing strategy for PR description"""
        return "\n".join(f"- {item}" for item in strategy)
    
    def _format_review_criteria(self, criteria: List[str]) -> str:
        """Format review criteria for PR description"""
        return "\n".join(f"- {item}" for item in criteria)
    
    def get_available_agents(self) -> List[Dict[str, Any]]:
        """Get information about available specialized agents"""
        agents_info = []
        
        for agent_name, agent in self.specialized_agents.items():
            agents_info.append({
                "name": agent_name,
                "class": agent.__class__.__name__,
                "specialties": agent.specialties,
                "model": agent.get_claude_model(),
                "file_patterns": agent.get_relevant_files_patterns()
            })
        
        return agents_info
    
    def get_cluster_status(self) -> Optional[Dict[str, Any]]:
        """Get cluster status if using distributed processing"""
        if not self.use_distributed or not self.coordinator:
            return None
        
        return self.coordinator.get_cluster_status()
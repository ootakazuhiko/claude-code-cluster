"""Base specialized agent class"""

import logging
from abc import ABC, abstractmethod
from typing import Dict, Any, List, Optional
from pathlib import Path

from src.core.config import get_settings
from src.clients.github_client import GitHubClient
from src.clients.claude_client import ClaudeClient
from src.services.git_handler import GitHandler
from src.utils.logging import get_logger


logger = get_logger(__name__)


class BaseSpecializedAgent(ABC):
    """Base class for specialized agents"""
    
    def __init__(self, agent_id: str, specialties: List[str]):
        self.agent_id = agent_id
        self.specialties = specialties
        self.settings = get_settings()
        
        # Initialize clients
        self.github_client = GitHubClient()
        self.claude_client = ClaudeClient()
        self.git_handler = GitHandler()
        
        logger.info(f"Initialized {self.__class__.__name__} with specialties: {specialties}")
    
    @abstractmethod
    def can_handle_task(self, task: Dict[str, Any]) -> float:
        """
        Check if agent can handle the task
        Returns a score from 0.0 to 1.0 indicating suitability
        """
        pass
    
    @abstractmethod
    def get_system_prompt_additions(self) -> str:
        """Get additional system prompt content for this agent"""
        pass
    
    @abstractmethod
    def analyze_task_requirements(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze task requirements specific to this agent"""
        pass
    
    @abstractmethod
    def get_relevant_files_patterns(self) -> List[str]:
        """Get file patterns relevant to this agent"""
        pass
    
    @abstractmethod
    def validate_implementation(self, implementation: Dict[str, Any], task: Dict[str, Any]) -> Dict[str, Any]:
        """Validate implementation specific to this agent"""
        pass
    
    def get_claude_model(self) -> str:
        """Get appropriate Claude model for this agent"""
        return "claude-3-haiku-20240307"  # Default model
    
    def filter_relevant_files(self, files: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Filter files relevant to this agent"""
        patterns = self.get_relevant_files_patterns()
        relevant_files = []
        
        for file_info in files:
            file_path = file_info["path"]
            if any(self._matches_pattern(file_path, pattern) for pattern in patterns):
                relevant_files.append(file_info)
        
        return relevant_files
    
    def _matches_pattern(self, file_path: str, pattern: str) -> bool:
        """Check if file path matches pattern"""
        import fnmatch
        return fnmatch.fnmatch(file_path.lower(), pattern.lower())
    
    def enhance_prompt(self, base_prompt: str, task: Dict[str, Any]) -> str:
        """Enhance prompt with agent-specific context"""
        additions = self.get_system_prompt_additions()
        
        enhanced_prompt = f"""{base_prompt}

# Agent Specialization: {self.__class__.__name__}
# Specialties: {', '.join(self.specialties)}

{additions}

# Task-Specific Requirements:
{self._get_task_specific_requirements(task)}
"""
        return enhanced_prompt
    
    def _get_task_specific_requirements(self, task: Dict[str, Any]) -> str:
        """Get task-specific requirements"""
        requirements = task.get("analysis", {}).get("requirements", [])
        
        if not requirements:
            return "No specific requirements identified."
        
        req_text = "Based on the task analysis, please focus on:\n"
        for req in requirements:
            if req in self.specialties:
                req_text += f"- {req.title()} development (primary focus)\n"
            else:
                req_text += f"- {req.title()} integration (secondary consideration)\n"
        
        return req_text
    
    def get_confidence_score(self, task: Dict[str, Any]) -> float:
        """Get confidence score for handling this task"""
        base_score = self.can_handle_task(task)
        
        # Adjust based on task complexity
        complexity = task.get("analysis", {}).get("complexity", "medium")
        complexity_multiplier = {
            "low": 1.1,
            "medium": 1.0,
            "high": 0.9
        }.get(complexity, 1.0)
        
        # Adjust based on task type
        task_type = task.get("analysis", {}).get("type", "general")
        if task_type in ["bug", "feature", "enhancement"]:
            type_multiplier = 1.0
        else:
            type_multiplier = 0.9
        
        final_score = base_score * complexity_multiplier * type_multiplier
        return min(1.0, max(0.0, final_score))
    
    def get_agent_info(self) -> Dict[str, Any]:
        """Get agent information"""
        return {
            "agent_id": self.agent_id,
            "class": self.__class__.__name__,
            "specialties": self.specialties,
            "model": self.get_claude_model(),
            "file_patterns": self.get_relevant_files_patterns()
        }
    
    async def pre_process_task(self, task: Dict[str, Any], workspace: Path) -> Dict[str, Any]:
        """Pre-process task before implementation"""
        # Default implementation - can be overridden
        return {"pre_process": "completed"}
    
    async def post_process_task(self, task: Dict[str, Any], implementation: Dict[str, Any], workspace: Path) -> Dict[str, Any]:
        """Post-process task after implementation"""
        # Default implementation - can be overridden
        return {"post_process": "completed"}
    
    def get_testing_strategy(self, task: Dict[str, Any]) -> List[str]:
        """Get testing strategy for this agent"""
        # Default testing strategy
        return [
            "Verify implementation matches requirements",
            "Test for basic functionality",
            "Check for syntax errors",
            "Validate integration points"
        ]
    
    def get_review_criteria(self, task: Dict[str, Any]) -> List[str]:
        """Get review criteria for this agent"""
        # Default review criteria
        return [
            "Code quality and readability",
            "Following best practices",
            "Error handling",
            "Documentation quality",
            "Performance considerations"
        ]
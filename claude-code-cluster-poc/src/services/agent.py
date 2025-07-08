"""Main Claude Agent implementation"""

import logging
from typing import Dict, Any, List, Optional

from src.core.config import get_settings
from src.core.exceptions import ClaudeClusterError, TaskNotFoundError
from src.clients.github_client import GitHubClient
from src.clients.claude_client import ClaudeClient
from src.services.state_manager import StateManager
from src.services.git_handler import GitHandler
from src.utils.helpers import current_timestamp


logger = logging.getLogger(__name__)


class ClaudeAgent:
    """Main Claude Code Cluster Agent"""
    
    def __init__(self, settings = None):
        self.settings = settings or get_settings()
        
        # Initialize clients and services
        self.github_client = GitHubClient()
        self.claude_client = ClaudeClient()
        self.state_manager = StateManager()
        self.git_handler = GitHandler()
        
        logger.info("Claude Agent initialized")
    
    def create_task_from_issue(self, issue_number: int, repo_name: str) -> str:
        """Create a task from GitHub issue"""
        
        try:
            # Get issue data from GitHub
            logger.info(f"Fetching issue #{issue_number} from {repo_name}")
            issue_data = self.github_client.get_issue(repo_name, issue_number)
            
            # Analyze issue requirements
            logger.info("Analyzing issue requirements")
            analysis = self.github_client.analyze_issue_requirements(issue_data)
            
            # Create task in state manager
            task_id = self.state_manager.create_task(issue_data, analysis)
            
            logger.info(f"Created task {task_id} for issue #{issue_number}")
            return task_id
            
        except Exception as e:
            logger.error(f"Failed to create task from issue: {e}")
            raise ClaudeClusterError(f"Failed to create task from issue: {e}")
    
    def run_task(self, task_id: str) -> Dict[str, Any]:
        """Execute a task"""
        
        try:
            # Get task data
            task = self.state_manager.get_task(task_id)
            
            if task["status"] != "created":
                raise ClaudeClusterError(f"Task {task_id} is not in created state")
            
            logger.info(f"Starting execution of task {task_id}")
            
            # Update task status
            self.state_manager.update_task_status(task_id, "running")
            
            # Execute task steps
            result = self._execute_task_steps(task_id, task)
            
            # Update task status
            self.state_manager.update_task_status(task_id, "completed")
            
            logger.info(f"Task {task_id} completed successfully")
            return result
            
        except Exception as e:
            logger.error(f"Task {task_id} failed: {e}")
            self.state_manager.update_task_status(task_id, "failed", str(e))
            raise ClaudeClusterError(f"Task execution failed: {e}")
    
    def _execute_task_steps(self, task_id: str, task: Dict[str, Any]) -> Dict[str, Any]:
        """Execute the main task steps"""
        
        issue_data = task["issue"]
        analysis = task["analysis"]
        
        # Step 1: Clone repository
        logger.info("Step 1: Cloning repository")
        repo_path = self._clone_repository(task_id, issue_data)
        
        # Step 2: Analyze repository context
        logger.info("Step 2: Analyzing repository context")
        repo_context = self._analyze_repository_context(repo_path, analysis)
        
        # Step 3: Generate implementation
        logger.info("Step 3: Generating implementation")
        implementation = self._generate_implementation(task_id, issue_data, repo_context, analysis)
        
        # Step 4: Review implementation
        logger.info("Step 4: Reviewing implementation")
        review = self._review_implementation(task_id, implementation, issue_data)
        
        # Step 5: Apply changes
        logger.info("Step 5: Applying changes")
        applied_files = self._apply_changes(repo_path, implementation)
        
        # Step 6: Create git branch and commit
        logger.info("Step 6: Creating git branch and commit")
        branch_name = self._create_git_branch_and_commit(task_id, repo_path, implementation, issue_data)
        
        # Step 7: Push branch
        logger.info("Step 7: Pushing branch")
        self._push_branch(repo_path, branch_name)
        
        # Step 8: Create pull request
        logger.info("Step 8: Creating pull request")
        pr_info = self._create_pull_request(task_id, implementation, issue_data, branch_name)
        
        # Step 9: Cleanup (optional)
        if not self.settings.log_level == "DEBUG":
            logger.info("Step 9: Cleaning up workspace")
            self.git_handler.cleanup_workspace(task_id)
        
        return {
            "task_id": task_id,
            "status": "completed",
            "implementation": implementation,
            "review": review,
            "applied_files": applied_files,
            "branch_name": branch_name,
            "pr_info": pr_info,
            "completed_at": current_timestamp()
        }
    
    def _clone_repository(self, task_id: str, issue_data: Dict[str, Any]) -> Any:
        """Clone repository for task"""
        
        repo_info = issue_data
        repo_url = repo_info["repository"]["clone_url"]
        
        # Clone repository
        repo_path = self.git_handler.clone_repository(repo_url, task_id)
        
        # Configure git
        self.git_handler.configure_git(repo_path)
        
        return repo_path
    
    def _analyze_repository_context(self, repo_path: Any, analysis: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze repository context for implementation"""
        
        # Get repository info
        repo_info = self.git_handler.get_repository_info(repo_path)
        
        # Get file list
        files = self.git_handler.get_file_list(repo_path)
        
        # Get relevant files based on analysis keywords
        keywords = analysis.get("keywords", [])
        relevant_files = self.git_handler.get_relevant_files(repo_path, keywords)
        
        # Build file contents for context
        file_contents = {}
        for file_info in relevant_files[:5]:  # Limit to 5 most relevant files
            file_contents[file_info["path"]] = file_info["content"]
        
        return {
            "repo_info": repo_info,
            "files": files,
            "relevant_files": relevant_files,
            "file_contents": file_contents,
            "total_files": len(files)
        }
    
    def _generate_implementation(self, task_id: str, issue_data: Dict[str, Any], repo_context: Dict[str, Any], analysis: Dict[str, Any]) -> Dict[str, Any]:
        """Generate implementation using Claude"""
        
        # Generate implementation
        implementation = self.claude_client.generate_implementation(
            issue_data,
            repo_context,
            analysis["requirements"]
        )
        
        # Save implementation to state
        self.state_manager.save_task_implementation(task_id, implementation)
        
        return implementation
    
    def _review_implementation(self, task_id: str, implementation: Dict[str, Any], issue_data: Dict[str, Any]) -> Dict[str, Any]:
        """Review implementation"""
        
        # Review implementation
        review = self.claude_client.review_implementation(implementation, issue_data)
        
        # Save review to state
        self.state_manager.save_task_review(task_id, review)
        
        return review
    
    def _apply_changes(self, repo_path: Any, implementation: Dict[str, Any]) -> List[str]:
        """Apply implementation changes to repository"""
        
        changes = implementation.get("changes", [])
        applied_files = self.git_handler.apply_changes(repo_path, changes)
        
        return applied_files
    
    def _create_git_branch_and_commit(self, task_id: str, repo_path: Any, implementation: Dict[str, Any], issue_data: Dict[str, Any]) -> str:
        """Create git branch and commit changes"""
        
        # Generate branch name
        branch_name = self.git_handler.generate_branch_name(task_id, issue_data["title"])
        
        # Create branch
        self.git_handler.create_branch(repo_path, branch_name)
        
        # Commit changes
        commit_message = f"feat: {issue_data['title']}\n\n{implementation.get('summary', '')}"
        self.git_handler.commit_changes(repo_path, commit_message, task_id)
        
        return branch_name
    
    def _push_branch(self, repo_path: Any, branch_name: str) -> None:
        """Push branch to remote"""
        
        self.git_handler.push_branch(repo_path, branch_name)
    
    def _create_pull_request(self, task_id: str, implementation: Dict[str, Any], issue_data: Dict[str, Any], branch_name: str) -> Dict[str, Any]:
        """Create pull request"""
        
        # Generate PR title
        pr_title = f"feat: {issue_data['title']}"
        
        # Generate PR description
        pr_description = self.claude_client.generate_pr_description(implementation, issue_data)
        
        # Create PR
        repo_name = issue_data["repository"]["full_name"]
        pr_info = self.github_client.create_pull_request(
            repo_name,
            pr_title,
            pr_description,
            branch_name
        )
        
        # Save PR info to state
        self.state_manager.save_task_git_info(
            task_id,
            branch_name,
            pr_info["html_url"],
            pr_info["number"]
        )
        
        return pr_info
    
    def get_task_status(self, task_id: Optional[str] = None) -> Any:
        """Get status of tasks"""
        
        if task_id:
            try:
                return self.state_manager.get_task(task_id)
            except TaskNotFoundError:
                return None
        else:
            return self.state_manager.list_tasks()
    
    def cancel_task(self, task_id: str) -> bool:
        """Cancel a running task"""
        
        try:
            task = self.state_manager.get_task(task_id)
            
            if task["status"] == "running":
                self.state_manager.update_task_status(task_id, "cancelled")
                
                # Cleanup workspace
                self.git_handler.cleanup_workspace(task_id)
                
                logger.info(f"Task {task_id} cancelled")
                return True
            else:
                logger.warning(f"Task {task_id} is not running, cannot cancel")
                return False
                
        except TaskNotFoundError:
            logger.error(f"Task {task_id} not found")
            return False
    
    def get_system_status(self) -> Dict[str, Any]:
        """Get system status"""
        
        # Get task summary
        task_summary = self.state_manager.get_task_summary()
        
        # Check Git availability
        git_available = self.git_handler.check_git_available()
        
        # Get GitHub rate limit
        try:
            rate_limit = self.github_client.get_rate_limit()
        except Exception as e:
            rate_limit = {"error": str(e)}
        
        # Get Claude usage info
        claude_usage = self.claude_client.get_usage_info()
        
        return {
            "status": "healthy",
            "tasks": task_summary,
            "git_available": git_available,
            "github_rate_limit": rate_limit,
            "claude_usage": claude_usage,
            "workspace_path": str(self.settings.workspace_path),
            "data_path": str(self.settings.data_path)
        }
    
    def cleanup_old_tasks(self, days: int = 30) -> int:
        """Clean up old completed tasks"""
        
        return self.state_manager.cleanup_old_tasks(days)
    
    def export_tasks(self, output_file: str) -> None:
        """Export tasks to file"""
        
        from pathlib import Path
        self.state_manager.export_tasks(Path(output_file))
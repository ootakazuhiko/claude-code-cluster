"""Git operations handler"""

import logging
import subprocess
import shutil
from pathlib import Path
from typing import Dict, Any, List, Optional

from src.core.config import get_settings
from src.core.exceptions import GitOperationError
from src.utils.helpers import sanitize_filename


logger = logging.getLogger(__name__)


class GitHandler:
    """Handle Git operations"""
    
    def __init__(self):
        self.settings = get_settings()
        self.workspace_path = self.settings.workspace_path
        
        # Ensure workspace directory exists
        self.workspace_path.mkdir(exist_ok=True, parents=True)
    
    def clone_repository(self, repo_url: str, task_id: str, branch: str = "main") -> Path:
        """Clone repository to workspace"""
        
        # Create task-specific directory
        repo_dir = self.workspace_path / f"repo-{task_id}"
        
        # Remove existing directory if it exists
        if repo_dir.exists():
            shutil.rmtree(repo_dir)
        
        try:
            # Clone repository
            cmd = [
                "git", "clone",
                "--branch", branch,
                "--single-branch",
                repo_url,
                str(repo_dir)
            ]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True
            )
            
            logger.info(f"Successfully cloned repository to {repo_dir}")
            return repo_dir
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to clone repository: {e.stderr}")
            raise GitOperationError(f"Failed to clone repository: {e.stderr}")
    
    def configure_git(self, repo_path: Path) -> None:
        """Configure Git user information"""
        
        try:
            # Set user name
            subprocess.run([
                "git", "config", "user.name", self.settings.git_user_name
            ], cwd=repo_path, check=True)
            
            # Set user email
            subprocess.run([
                "git", "config", "user.email", self.settings.git_user_email
            ], cwd=repo_path, check=True)
            
            logger.info("Git configuration set successfully")
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to configure git: {e}")
            raise GitOperationError(f"Failed to configure git: {e}")
    
    def create_branch(self, repo_path: Path, branch_name: str) -> None:
        """Create and switch to a new branch"""
        
        try:
            # Create and switch to new branch
            subprocess.run([
                "git", "checkout", "-b", branch_name
            ], cwd=repo_path, check=True, capture_output=True)
            
            logger.info(f"Created and switched to branch: {branch_name}")
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to create branch: {e.stderr}")
            raise GitOperationError(f"Failed to create branch: {e.stderr}")
    
    def apply_changes(self, repo_path: Path, changes: List[Dict[str, Any]]) -> List[str]:
        """Apply code changes to repository"""
        
        applied_files = []
        
        for change in changes:
            action = change.get("action", "modify")
            file_path = change.get("file_path", "")
            content = change.get("content", "")
            
            if not file_path:
                logger.warning("Skipping change with no file path")
                continue
            
            full_path = repo_path / file_path
            
            try:
                if action == "create" or action == "modify":
                    # Create directory if it doesn't exist
                    full_path.parent.mkdir(parents=True, exist_ok=True)
                    
                    # Write content to file
                    with open(full_path, "w", encoding="utf-8") as f:
                        f.write(content)
                    
                    applied_files.append(file_path)
                    logger.info(f"Applied change: {action} {file_path}")
                
                elif action == "delete":
                    if full_path.exists():
                        full_path.unlink()
                        applied_files.append(file_path)
                        logger.info(f"Deleted file: {file_path}")
                
            except Exception as e:
                logger.error(f"Failed to apply change to {file_path}: {e}")
                continue
        
        return applied_files
    
    def commit_changes(self, repo_path: Path, message: str, task_id: str) -> str:
        """Commit changes to repository"""
        
        try:
            # Add all changes
            subprocess.run([
                "git", "add", "."
            ], cwd=repo_path, check=True)
            
            # Create commit message
            commit_message = f"""{message}

Task ID: {task_id}

🤖 Generated with Claude Code Cluster PoC

Co-authored-by: Claude <claude@anthropic.com>"""
            
            # Commit changes
            subprocess.run([
                "git", "commit", "-m", commit_message
            ], cwd=repo_path, check=True)
            
            # Get commit hash
            result = subprocess.run([
                "git", "rev-parse", "HEAD"
            ], cwd=repo_path, capture_output=True, text=True, check=True)
            
            commit_hash = result.stdout.strip()
            
            logger.info(f"Committed changes: {commit_hash}")
            return commit_hash
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to commit changes: {e}")
            raise GitOperationError(f"Failed to commit changes: {e}")
    
    def push_branch(self, repo_path: Path, branch_name: str) -> None:
        """Push branch to remote repository"""
        
        try:
            # Push branch to origin
            subprocess.run([
                "git", "push", "origin", branch_name
            ], cwd=repo_path, check=True, capture_output=True)
            
            logger.info(f"Pushed branch: {branch_name}")
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to push branch: {e.stderr}")
            raise GitOperationError(f"Failed to push branch: {e.stderr}")
    
    def get_repository_info(self, repo_path: Path) -> Dict[str, Any]:
        """Get repository information"""
        
        try:
            # Get current branch
            result = subprocess.run([
                "git", "branch", "--show-current"
            ], cwd=repo_path, capture_output=True, text=True, check=True)
            current_branch = result.stdout.strip()
            
            # Get remote URL
            result = subprocess.run([
                "git", "remote", "get-url", "origin"
            ], cwd=repo_path, capture_output=True, text=True, check=True)
            remote_url = result.stdout.strip()
            
            # Get last commit
            result = subprocess.run([
                "git", "log", "-1", "--format=%H %s"
            ], cwd=repo_path, capture_output=True, text=True, check=True)
            last_commit = result.stdout.strip()
            
            return {
                "current_branch": current_branch,
                "remote_url": remote_url,
                "last_commit": last_commit,
                "path": str(repo_path)
            }
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to get repository info: {e}")
            return {}
    
    def get_file_list(self, repo_path: Path, max_files: int = 100) -> List[Dict[str, Any]]:
        """Get list of files in repository"""
        
        try:
            # Get all tracked files
            result = subprocess.run([
                "git", "ls-files"
            ], cwd=repo_path, capture_output=True, text=True, check=True)
            
            files = []
            for line in result.stdout.strip().split('\n'):
                if line and len(files) < max_files:
                    file_path = repo_path / line
                    if file_path.exists():
                        files.append({
                            "path": line,
                            "size": file_path.stat().st_size,
                            "type": "file"
                        })
            
            logger.info(f"Found {len(files)} files in repository")
            return files
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to get file list: {e}")
            return []
    
    def read_file_content(self, repo_path: Path, file_path: str, max_lines: int = 100) -> Optional[str]:
        """Read content of a file"""
        
        full_path = repo_path / file_path
        
        if not full_path.exists():
            return None
        
        try:
            with open(full_path, "r", encoding="utf-8") as f:
                lines = f.readlines()
                
                # Limit number of lines
                if len(lines) > max_lines:
                    lines = lines[:max_lines]
                    lines.append(f"\n... (truncated, {len(lines)} more lines)")
                
                return "".join(lines)
                
        except Exception as e:
            logger.error(f"Failed to read file {file_path}: {e}")
            return None
    
    def get_relevant_files(self, repo_path: Path, keywords: List[str]) -> List[Dict[str, Any]]:
        """Get files relevant to the task keywords"""
        
        files = self.get_file_list(repo_path)
        relevant_files = []
        
        for file_info in files:
            file_path = file_info["path"]
            
            # Check if file path contains any keywords
            if any(keyword.lower() in file_path.lower() for keyword in keywords):
                content = self.read_file_content(repo_path, file_path, max_lines=50)
                if content:
                    relevant_files.append({
                        "path": file_path,
                        "size": file_info["size"],
                        "content": content
                    })
            
            # Limit number of relevant files
            if len(relevant_files) >= 10:
                break
        
        logger.info(f"Found {len(relevant_files)} relevant files")
        return relevant_files
    
    def generate_branch_name(self, task_id: str, issue_title: str) -> str:
        """Generate branch name for task"""
        
        # Sanitize issue title
        sanitized_title = sanitize_filename(issue_title)
        
        # Create branch name
        branch_name = f"claude-{task_id}-{sanitized_title}"
        
        # Ensure branch name is not too long
        if len(branch_name) > 50:
            branch_name = branch_name[:50]
        
        return branch_name
    
    def cleanup_workspace(self, task_id: str) -> None:
        """Clean up workspace for completed task"""
        
        repo_dir = self.workspace_path / f"repo-{task_id}"
        
        if repo_dir.exists():
            try:
                shutil.rmtree(repo_dir)
                logger.info(f"Cleaned up workspace for task {task_id}")
            except Exception as e:
                logger.error(f"Failed to cleanup workspace: {e}")
    
    def check_git_available(self) -> bool:
        """Check if Git is available"""
        
        try:
            result = subprocess.run([
                "git", "--version"
            ], capture_output=True, text=True, check=True)
            
            logger.info(f"Git available: {result.stdout.strip()}")
            return True
            
        except subprocess.CalledProcessError:
            logger.error("Git is not available")
            return False
        except FileNotFoundError:
            logger.error("Git command not found")
            return False
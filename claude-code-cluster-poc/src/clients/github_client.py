"""GitHub API client"""

import logging
from typing import Dict, Any, Optional, List
from github import Github, GithubException
from github.Issue import Issue
from github.Repository import Repository
from github.PullRequest import PullRequest

from src.core.config import get_settings
from src.core.exceptions import GitHubAPIError
from src.utils.helpers import extract_keywords_from_text


logger = logging.getLogger(__name__)


class GitHubClient:
    """GitHub API client wrapper"""
    
    def __init__(self, token: Optional[str] = None):
        """Initialize GitHub client"""
        self.settings = get_settings()
        self.token = token or self.settings.github_token
        self.github = Github(self.token)
        
        # Test connection
        try:
            user = self.github.get_user()
            logger.info(f"Connected to GitHub as: {user.login}")
        except GithubException as e:
            raise GitHubAPIError(f"Failed to connect to GitHub: {e}")
    
    def get_issue(self, repo_name: str, issue_number: int) -> Dict[str, Any]:
        """Get issue information"""
        try:
            repo = self.github.get_repo(repo_name)
            issue = repo.get_issue(issue_number)
            
            # Extract relevant information
            issue_data = {
                "id": issue.id,
                "number": issue.number,
                "title": issue.title,
                "body": issue.body or "",
                "state": issue.state,
                "created_at": issue.created_at.isoformat(),
                "updated_at": issue.updated_at.isoformat(),
                "user": {
                    "login": issue.user.login,
                    "id": issue.user.id,
                },
                "labels": [label.name for label in issue.labels],
                "assignees": [assignee.login for assignee in issue.assignees],
                "milestone": issue.milestone.title if issue.milestone else None,
                "comments": issue.comments,
                "html_url": issue.html_url,
                "repository": {
                    "name": repo.name,
                    "full_name": repo.full_name,
                    "owner": repo.owner.login,
                    "default_branch": repo.default_branch,
                    "clone_url": repo.clone_url,
                    "html_url": repo.html_url,
                }
            }
            
            logger.info(f"Retrieved issue #{issue_number} from {repo_name}")
            return issue_data
            
        except GithubException as e:
            if e.status == 404:
                raise GitHubAPIError(f"Issue #{issue_number} not found in {repo_name}")
            else:
                raise GitHubAPIError(f"Failed to get issue: {e}")
    
    def analyze_issue_requirements(self, issue_data: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze issue to determine requirements"""
        
        title = issue_data["title"].lower()
        body = issue_data["body"].lower()
        labels = [label.lower() for label in issue_data["labels"]]
        
        # Extract keywords from title and body
        keywords = extract_keywords_from_text(title + " " + body)
        
        # Determine priority
        priority = "medium"
        if any(label in ["urgent", "critical", "high-priority", "p1"] for label in labels):
            priority = "high"
        elif any(label in ["low-priority", "nice-to-have", "p3"] for label in labels):
            priority = "low"
        
        # Determine type/category
        issue_type = "general"
        if any(word in title + body for word in ["bug", "error", "fix", "broken"]):
            issue_type = "bug"
        elif any(word in title + body for word in ["feature", "add", "new", "implement"]):
            issue_type = "feature"
        elif any(word in title + body for word in ["improve", "enhance", "optimize"]):
            issue_type = "enhancement"
        elif any(word in title + body for word in ["doc", "documentation", "readme"]):
            issue_type = "documentation"
        
        # Determine technology requirements
        requirements = []
        
        # Backend-related
        if any(word in title + body for word in ["api", "backend", "server", "database", "endpoint"]):
            requirements.append("backend")
        
        # Frontend-related
        if any(word in title + body for word in ["ui", "frontend", "react", "component", "interface"]):
            requirements.append("frontend")
        
        # Testing-related
        if any(word in title + body for word in ["test", "testing", "spec", "unit", "integration"]):
            requirements.append("testing")
        
        # DevOps-related
        if any(word in title + body for word in ["deploy", "ci", "cd", "docker", "build"]):
            requirements.append("devops")
        
        # Default if no specific requirements found
        if not requirements:
            requirements = ["general"]
        
        # Estimate complexity
        complexity = "medium"
        complexity_indicators = {
            "low": ["fix", "update", "change", "simple", "minor"],
            "high": ["refactor", "architecture", "migration", "complex", "major", "rewrite"]
        }
        
        for level, indicators in complexity_indicators.items():
            if any(indicator in title + body for indicator in indicators):
                complexity = level
                break
        
        # Estimate duration in minutes
        duration_mapping = {
            "low": 60,      # 1 hour
            "medium": 180,  # 3 hours  
            "high": 480     # 8 hours
        }
        estimated_duration = duration_mapping.get(complexity, 180)
        
        analysis = {
            "priority": priority,
            "type": issue_type,
            "requirements": requirements,
            "complexity": complexity,
            "estimated_duration_minutes": estimated_duration,
            "keywords": keywords[:10],  # Limit to top 10 keywords
            "labels": labels
        }
        
        logger.info(f"Issue analysis: {analysis}")
        return analysis
    
    def create_pull_request(
        self,
        repo_name: str,
        title: str,
        body: str,
        head_branch: str,
        base_branch: str = "main"
    ) -> Dict[str, Any]:
        """Create a pull request"""
        try:
            repo = self.github.get_repo(repo_name)
            
            pr = repo.create_pull(
                title=title,
                body=body,
                head=head_branch,
                base=base_branch
            )
            
            pr_data = {
                "id": pr.id,
                "number": pr.number,
                "title": pr.title,
                "body": pr.body,
                "state": pr.state,
                "html_url": pr.html_url,
                "created_at": pr.created_at.isoformat(),
                "head": {
                    "ref": pr.head.ref,
                    "sha": pr.head.sha,
                },
                "base": {
                    "ref": pr.base.ref,
                    "sha": pr.base.sha,
                }
            }
            
            logger.info(f"Created PR #{pr.number}: {title}")
            return pr_data
            
        except GithubException as e:
            if e.status == 422:
                raise GitHubAPIError(f"Pull request creation failed: {e.data}")
            else:
                raise GitHubAPIError(f"Failed to create pull request: {e}")
    
    def add_comment_to_issue(self, repo_name: str, issue_number: int, comment: str) -> None:
        """Add comment to an issue"""
        try:
            repo = self.github.get_repo(repo_name)
            issue = repo.get_issue(issue_number)
            issue.create_comment(comment)
            
            logger.info(f"Added comment to issue #{issue_number}")
            
        except GithubException as e:
            raise GitHubAPIError(f"Failed to add comment: {e}")
    
    def close_issue(self, repo_name: str, issue_number: int, comment: Optional[str] = None) -> None:
        """Close an issue"""
        try:
            repo = self.github.get_repo(repo_name)
            issue = repo.get_issue(issue_number)
            
            if comment:
                issue.create_comment(comment)
            
            issue.edit(state="closed")
            logger.info(f"Closed issue #{issue_number}")
            
        except GithubException as e:
            raise GitHubAPIError(f"Failed to close issue: {e}")
    
    def get_repository_info(self, repo_name: str) -> Dict[str, Any]:
        """Get repository information"""
        try:
            repo = self.github.get_repo(repo_name)
            
            repo_data = {
                "id": repo.id,
                "name": repo.name,
                "full_name": repo.full_name,
                "owner": repo.owner.login,
                "description": repo.description,
                "default_branch": repo.default_branch,
                "clone_url": repo.clone_url,
                "ssh_url": repo.ssh_url,
                "html_url": repo.html_url,
                "language": repo.language,
                "languages": dict(repo.get_languages()),
                "topics": repo.get_topics(),
                "created_at": repo.created_at.isoformat(),
                "updated_at": repo.updated_at.isoformat(),
                "size": repo.size,
                "stargazers_count": repo.stargazers_count,
                "watchers_count": repo.watchers_count,
                "forks_count": repo.forks_count,
                "open_issues_count": repo.open_issues_count,
                "private": repo.private,
            }
            
            logger.info(f"Retrieved repository info for {repo_name}")
            return repo_data
            
        except GithubException as e:
            if e.status == 404:
                raise GitHubAPIError(f"Repository {repo_name} not found")
            else:
                raise GitHubAPIError(f"Failed to get repository info: {e}")
    
    def list_repository_files(self, repo_name: str, path: str = "", max_files: int = 100) -> List[Dict[str, Any]]:
        """List files in repository"""
        try:
            repo = self.github.get_repo(repo_name)
            contents = repo.get_contents(path)
            
            files = []
            for content in contents:
                if len(files) >= max_files:
                    break
                    
                file_data = {
                    "name": content.name,
                    "path": content.path,
                    "type": content.type,
                    "size": content.size,
                    "sha": content.sha,
                    "download_url": content.download_url,
                    "html_url": content.html_url,
                }
                files.append(file_data)
                
                # Recursively get files from directories (limited depth)
                if content.type == "dir" and len(files) < max_files:
                    subfiles = self.list_repository_files(
                        repo_name, 
                        content.path, 
                        max_files - len(files)
                    )
                    files.extend(subfiles)
            
            logger.info(f"Listed {len(files)} files from {repo_name}")
            return files
            
        except GithubException as e:
            raise GitHubAPIError(f"Failed to list repository files: {e}")
    
    def get_file_content(self, repo_name: str, file_path: str) -> str:
        """Get file content from repository"""
        try:
            repo = self.github.get_repo(repo_name)
            content = repo.get_contents(file_path)
            
            if content.type != "file":
                raise GitHubAPIError(f"{file_path} is not a file")
            
            # Decode content
            file_content = content.decoded_content.decode('utf-8')
            
            logger.info(f"Retrieved content for {file_path}")
            return file_content
            
        except GithubException as e:
            if e.status == 404:
                raise GitHubAPIError(f"File {file_path} not found in {repo_name}")
            else:
                raise GitHubAPIError(f"Failed to get file content: {e}")
    
    def get_rate_limit(self) -> Dict[str, Any]:
        """Get rate limit information"""
        try:
            rate_limit = self.github.get_rate_limit()
            
            return {
                "core": {
                    "limit": rate_limit.core.limit,
                    "remaining": rate_limit.core.remaining,
                    "reset": rate_limit.core.reset.isoformat(),
                },
                "search": {
                    "limit": rate_limit.search.limit,
                    "remaining": rate_limit.search.remaining,
                    "reset": rate_limit.search.reset.isoformat(),
                }
            }
            
        except GithubException as e:
            raise GitHubAPIError(f"Failed to get rate limit: {e}")
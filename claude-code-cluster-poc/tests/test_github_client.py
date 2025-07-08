"""Tests for GitHub client"""

import pytest
from unittest.mock import Mock, patch
from src.clients.github_client import GitHubClient
from src.core.exceptions import GitHubAPIError


class TestGitHubClient:
    """Test GitHub client functionality"""
    
    @patch('src.clients.github_client.Github')
    def test_init_success(self, mock_github):
        """Test successful GitHub client initialization"""
        mock_user = Mock()
        mock_user.login = "testuser"
        mock_github.return_value.get_user.return_value = mock_user
        
        client = GitHubClient("test_token")
        
        assert client.token == "test_token"
        mock_github.assert_called_once_with("test_token")
    
    @patch('src.clients.github_client.Github')
    def test_init_failure(self, mock_github):
        """Test GitHub client initialization failure"""
        mock_github.return_value.get_user.side_effect = Exception("API Error")
        
        with pytest.raises(GitHubAPIError):
            GitHubClient("invalid_token")
    
    @patch('src.clients.github_client.Github')
    def test_get_issue_success(self, mock_github):
        """Test successful issue retrieval"""
        # Mock GitHub objects
        mock_issue = Mock()
        mock_issue.id = 123
        mock_issue.number = 1
        mock_issue.title = "Test Issue"
        mock_issue.body = "Test body"
        mock_issue.state = "open"
        mock_issue.created_at = Mock()
        mock_issue.created_at.isoformat.return_value = "2023-01-01T00:00:00Z"
        mock_issue.updated_at = Mock()
        mock_issue.updated_at.isoformat.return_value = "2023-01-01T00:00:00Z"
        mock_issue.user = Mock()
        mock_issue.user.login = "testuser"
        mock_issue.user.id = 456
        mock_issue.labels = []
        mock_issue.assignees = []
        mock_issue.milestone = None
        mock_issue.comments = 0
        mock_issue.html_url = "https://github.com/test/repo/issues/1"
        
        mock_repo = Mock()
        mock_repo.name = "repo"
        mock_repo.full_name = "test/repo"
        mock_repo.owner = Mock()
        mock_repo.owner.login = "test"
        mock_repo.default_branch = "main"
        mock_repo.clone_url = "https://github.com/test/repo.git"
        mock_repo.html_url = "https://github.com/test/repo"
        mock_repo.get_issue.return_value = mock_issue
        
        mock_github.return_value.get_repo.return_value = mock_repo
        mock_github.return_value.get_user.return_value = Mock(login="testuser")
        
        client = GitHubClient("test_token")
        result = client.get_issue("test/repo", 1)
        
        assert result["number"] == 1
        assert result["title"] == "Test Issue"
        assert result["repository"]["full_name"] == "test/repo"
    
    @patch('src.clients.github_client.Github')
    def test_analyze_issue_requirements(self, mock_github):
        """Test issue requirements analysis"""
        mock_github.return_value.get_user.return_value = Mock(login="testuser")
        
        client = GitHubClient("test_token")
        
        issue_data = {
            "title": "Add API endpoint for user authentication",
            "body": "Need to implement a new API endpoint for user login",
            "labels": ["enhancement", "backend"]
        }
        
        analysis = client.analyze_issue_requirements(issue_data)
        
        assert analysis["priority"] == "medium"
        assert analysis["type"] == "feature"
        assert "backend" in analysis["requirements"]
        assert analysis["complexity"] in ["low", "medium", "high"]
    
    @patch('src.clients.github_client.Github')
    def test_create_pull_request_success(self, mock_github):
        """Test successful pull request creation"""
        mock_pr = Mock()
        mock_pr.id = 789
        mock_pr.number = 1
        mock_pr.title = "Test PR"
        mock_pr.body = "Test PR body"
        mock_pr.state = "open"
        mock_pr.html_url = "https://github.com/test/repo/pull/1"
        mock_pr.created_at = Mock()
        mock_pr.created_at.isoformat.return_value = "2023-01-01T00:00:00Z"
        mock_pr.head = Mock()
        mock_pr.head.ref = "feature-branch"
        mock_pr.head.sha = "abc123"
        mock_pr.base = Mock()
        mock_pr.base.ref = "main"
        mock_pr.base.sha = "def456"
        
        mock_repo = Mock()
        mock_repo.create_pull.return_value = mock_pr
        
        mock_github.return_value.get_repo.return_value = mock_repo
        mock_github.return_value.get_user.return_value = Mock(login="testuser")
        
        client = GitHubClient("test_token")
        result = client.create_pull_request(
            "test/repo",
            "Test PR",
            "Test PR body",
            "feature-branch"
        )
        
        assert result["number"] == 1
        assert result["title"] == "Test PR"
        assert result["html_url"] == "https://github.com/test/repo/pull/1"
"""Custom exceptions"""


class ClaudeClusterError(Exception):
    """Base exception for Claude Cluster"""
    pass


class GitHubAPIError(ClaudeClusterError):
    """GitHub API related errors"""
    pass


class ClaudeAPIError(ClaudeClusterError):
    """Claude API related errors"""
    pass


class GitOperationError(ClaudeClusterError):
    """Git operation errors"""
    pass


class TaskNotFoundError(ClaudeClusterError):
    """Task not found error"""
    pass


class InvalidTaskStateError(ClaudeClusterError):
    """Invalid task state error"""
    pass
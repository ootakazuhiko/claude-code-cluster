"""Backend specialized agent"""

import logging
from typing import Dict, Any, List
from pathlib import Path

from .base_agent import BaseSpecializedAgent
from src.utils.logging import get_logger


logger = get_logger(__name__)


class BackendAgent(BaseSpecializedAgent):
    """Agent specialized in backend development"""
    
    def __init__(self, agent_id: str = "backend-agent"):
        super().__init__(agent_id, ["backend", "api", "database", "server"])
    
    def can_handle_task(self, task: Dict[str, Any]) -> float:
        """Check if agent can handle backend tasks"""
        requirements = task.get("analysis", {}).get("requirements", [])
        keywords = task.get("analysis", {}).get("keywords", [])
        title = task.get("issue", {}).get("title", "").lower()
        body = task.get("issue", {}).get("body", "").lower()
        
        score = 0.0
        
        # Check requirements
        backend_requirements = ["backend", "api", "database", "server"]
        matching_requirements = [req for req in requirements if req in backend_requirements]
        if matching_requirements:
            score += 0.8 * (len(matching_requirements) / len(backend_requirements))
        
        # Check keywords
        backend_keywords = [
            "api", "endpoint", "database", "server", "backend", "fastapi", "django",
            "flask", "sqlalchemy", "postgresql", "mysql", "redis", "crud", "model",
            "schema", "migration", "authentication", "authorization", "middleware"
        ]
        matching_keywords = [kw for kw in keywords if kw in backend_keywords]
        if matching_keywords:
            score += 0.6 * min(1.0, len(matching_keywords) / 5)
        
        # Check title and body
        backend_terms = [
            "api", "endpoint", "database", "server", "backend", "model", "schema",
            "authentication", "authorization", "middleware", "service", "repository"
        ]
        title_matches = sum(1 for term in backend_terms if term in title)
        body_matches = sum(1 for term in backend_terms if term in body)
        
        if title_matches > 0:
            score += 0.4 * min(1.0, title_matches / 3)
        if body_matches > 0:
            score += 0.2 * min(1.0, body_matches / 5)
        
        return min(1.0, score)
    
    def get_system_prompt_additions(self) -> str:
        """Get backend-specific system prompt additions"""
        return """
## Backend Development Focus

You are specialized in backend development with expertise in:

### Core Technologies:
- **Python**: FastAPI, Django, Flask, SQLAlchemy
- **Databases**: PostgreSQL, MySQL, Redis, MongoDB
- **API Design**: RESTful APIs, GraphQL, OpenAPI/Swagger
- **Authentication**: JWT, OAuth2, session management
- **Testing**: pytest, unittest, integration testing

### Best Practices:
- Follow RESTful API design principles
- Implement proper error handling and logging
- Use appropriate HTTP status codes
- Implement database migrations properly
- Follow security best practices (input validation, SQL injection prevention)
- Use dependency injection and service layer patterns
- Implement proper caching strategies

### Code Structure:
- Separate business logic from presentation layer
- Use repository pattern for data access
- Implement proper exception handling
- Create comprehensive API documentation
- Follow SOLID principles

### Database Considerations:
- Design efficient database schemas
- Use proper indexing
- Implement database transactions
- Handle connection pooling
- Consider data migration strategies

### Security Focus:
- Implement authentication and authorization
- Validate all inputs
- Use secure password hashing
- Implement rate limiting
- Follow OWASP guidelines
"""
    
    def analyze_task_requirements(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze backend-specific task requirements"""
        title = task.get("issue", {}).get("title", "").lower()
        body = task.get("issue", {}).get("body", "").lower()
        
        analysis = {
            "needs_database": False,
            "needs_api": False,
            "needs_authentication": False,
            "needs_testing": False,
            "complexity_factors": []
        }
        
        # Check for database needs
        database_terms = ["database", "model", "schema", "migration", "sql", "orm"]
        if any(term in title + body for term in database_terms):
            analysis["needs_database"] = True
            analysis["complexity_factors"].append("database_operations")
        
        # Check for API needs
        api_terms = ["api", "endpoint", "rest", "graphql", "service", "route"]
        if any(term in title + body for term in api_terms):
            analysis["needs_api"] = True
            analysis["complexity_factors"].append("api_design")
        
        # Check for authentication needs
        auth_terms = ["auth", "login", "user", "permission", "token", "session"]
        if any(term in title + body for term in auth_terms):
            analysis["needs_authentication"] = True
            analysis["complexity_factors"].append("authentication")
        
        # Check for testing needs
        test_terms = ["test", "testing", "unit", "integration", "coverage"]
        if any(term in title + body for term in test_terms):
            analysis["needs_testing"] = True
            analysis["complexity_factors"].append("testing")
        
        return analysis
    
    def get_relevant_files_patterns(self) -> List[str]:
        """Get file patterns relevant to backend development"""
        return [
            "*.py",
            "*/models/*",
            "*/schemas/*", 
            "*/services/*",
            "*/repositories/*",
            "*/controllers/*",
            "*/routers/*",
            "*/api/*",
            "*/database/*",
            "*/migrations/*",
            "requirements.txt",
            "pyproject.toml",
            "Dockerfile",
            "docker-compose.yml",
            "alembic.ini",
            "*/tests/*",
            "*/test_*"
        ]
    
    def validate_implementation(self, implementation: Dict[str, Any], task: Dict[str, Any]) -> Dict[str, Any]:
        """Validate backend implementation"""
        changes = implementation.get("changes", [])
        validation = {
            "valid": True,
            "issues": [],
            "warnings": [],
            "suggestions": []
        }
        
        # Check for required files
        python_files = [change for change in changes if change.get("file_path", "").endswith(".py")]
        if not python_files:
            validation["issues"].append("No Python files found in implementation")
            validation["valid"] = False
        
        # Check for proper error handling
        for change in python_files:
            content = change.get("content", "")
            if "raise" not in content and "except" not in content:
                validation["warnings"].append(f"Consider adding error handling to {change.get('file_path')}")
        
        # Check for database operations
        task_analysis = self.analyze_task_requirements(task)
        if task_analysis["needs_database"]:
            db_terms = ["model", "schema", "database", "session", "query"]
            has_db_code = any(
                any(term in change.get("content", "").lower() for term in db_terms)
                for change in changes
            )
            if not has_db_code:
                validation["warnings"].append("Task requires database operations but no database code found")
        
        # Check for API implementation
        if task_analysis["needs_api"]:
            api_terms = ["@app.post", "@app.get", "@app.put", "@app.delete", "router", "endpoint"]
            has_api_code = any(
                any(term in change.get("content", "") for term in api_terms)
                for change in changes
            )
            if not has_api_code:
                validation["warnings"].append("Task requires API implementation but no API code found")
        
        # Check for tests
        if task_analysis["needs_testing"]:
            test_files = [change for change in changes if "test" in change.get("file_path", "")]
            if not test_files:
                validation["suggestions"].append("Consider adding test files for the implementation")
        
        return validation
    
    def get_claude_model(self) -> str:
        """Get appropriate Claude model for backend tasks"""
        return "claude-3-sonnet-20240229"  # Use Sonnet for more complex backend logic
    
    def get_testing_strategy(self, task: Dict[str, Any]) -> List[str]:
        """Get backend-specific testing strategy"""
        strategy = [
            "Unit tests for business logic",
            "Integration tests for API endpoints",
            "Database transaction tests",
            "Authentication and authorization tests",
            "Input validation tests",
            "Error handling tests"
        ]
        
        task_analysis = self.analyze_task_requirements(task)
        
        if task_analysis["needs_database"]:
            strategy.extend([
                "Database migration tests",
                "Model validation tests",
                "Query performance tests"
            ])
        
        if task_analysis["needs_api"]:
            strategy.extend([
                "API endpoint response tests",
                "HTTP status code validation",
                "Request/response schema validation"
            ])
        
        if task_analysis["needs_authentication"]:
            strategy.extend([
                "Authentication flow tests",
                "Permission and authorization tests",
                "Token validation tests"
            ])
        
        return strategy
    
    def get_review_criteria(self, task: Dict[str, Any]) -> List[str]:
        """Get backend-specific review criteria"""
        criteria = [
            "Code follows Python best practices (PEP 8)",
            "Proper error handling and logging",
            "Database operations are efficient",
            "API endpoints follow REST conventions",
            "Security considerations are addressed",
            "Code is testable and modular",
            "Documentation is adequate"
        ]
        
        task_analysis = self.analyze_task_requirements(task)
        
        if task_analysis["needs_database"]:
            criteria.extend([
                "Database schema is well-designed",
                "Migrations are properly implemented",
                "Database queries are optimized"
            ])
        
        if task_analysis["needs_api"]:
            criteria.extend([
                "API design follows REST principles",
                "Proper HTTP status codes are used",
                "Request/response validation is implemented"
            ])
        
        if task_analysis["needs_authentication"]:
            criteria.extend([
                "Authentication is secure",
                "Authorization is properly implemented",
                "Session management is appropriate"
            ])
        
        return criteria
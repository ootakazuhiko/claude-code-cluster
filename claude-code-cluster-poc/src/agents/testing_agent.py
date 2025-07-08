"""Testing specialized agent"""

import logging
from typing import Dict, Any, List
from pathlib import Path

from .base_agent import BaseSpecializedAgent
from src.utils.logging import get_logger


logger = get_logger(__name__)


class TestingAgent(BaseSpecializedAgent):
    """Agent specialized in testing and quality assurance"""
    
    def __init__(self, agent_id: str = "testing-agent"):
        super().__init__(agent_id, ["testing", "qa", "pytest", "jest", "quality"])
    
    def can_handle_task(self, task: Dict[str, Any]) -> float:
        """Check if agent can handle testing tasks"""
        requirements = task.get("analysis", {}).get("requirements", [])
        keywords = task.get("analysis", {}).get("keywords", [])
        title = task.get("issue", {}).get("title", "").lower()
        body = task.get("issue", {}).get("body", "").lower()
        
        score = 0.0
        
        # Check requirements
        testing_requirements = ["testing", "qa", "pytest", "jest", "quality"]
        matching_requirements = [req for req in requirements if req in testing_requirements]
        if matching_requirements:
            score += 0.8 * (len(matching_requirements) / len(testing_requirements))
        
        # Check keywords
        testing_keywords = [
            "test", "testing", "pytest", "jest", "unit", "integration", "e2e",
            "coverage", "mock", "fixture", "assert", "spec", "qa", "quality",
            "bug", "error", "failure", "defect", "validation", "verification"
        ]
        matching_keywords = [kw for kw in keywords if kw in testing_keywords]
        if matching_keywords:
            score += 0.6 * min(1.0, len(matching_keywords) / 5)
        
        # Check title and body
        testing_terms = [
            "test", "testing", "bug", "error", "failure", "fix", "quality",
            "coverage", "unit", "integration", "e2e", "validation", "verify"
        ]
        title_matches = sum(1 for term in testing_terms if term in title)
        body_matches = sum(1 for term in testing_terms if term in body)
        
        if title_matches > 0:
            score += 0.4 * min(1.0, title_matches / 3)
        if body_matches > 0:
            score += 0.2 * min(1.0, body_matches / 5)
        
        # High score for bug-related tasks
        if task.get("analysis", {}).get("type") == "bug":
            score += 0.3
        
        return min(1.0, score)
    
    def get_system_prompt_additions(self) -> str:
        """Get testing-specific system prompt additions"""
        return """
## Testing and Quality Assurance Focus

You are specialized in testing and quality assurance with expertise in:

### Core Testing Technologies:
- **Python Testing**: pytest, unittest, nose2, coverage
- **JavaScript Testing**: Jest, Mocha, Cypress, Playwright
- **Mock/Stub**: unittest.mock, Jest mocks, Sinon
- **Test Runners**: pytest, Jest, Karma, Jasmine
- **Coverage Tools**: coverage.py, Istanbul, nyc

### Testing Types:
- **Unit Tests**: Test individual functions/methods
- **Integration Tests**: Test component interactions
- **End-to-End Tests**: Test complete user workflows
- **Performance Tests**: Load testing, stress testing
- **Security Tests**: Vulnerability scanning, penetration testing

### Best Practices:
- Write clear, maintainable test code
- Follow AAA pattern (Arrange, Act, Assert)
- Use descriptive test names
- Implement proper test isolation
- Mock external dependencies
- Achieve good test coverage (80%+)
- Write tests for edge cases and error conditions
- Use fixtures for test data setup

### Quality Assurance:
- Implement proper test pyramids
- Create comprehensive test suites
- Perform code reviews focused on testability
- Implement continuous integration testing
- Use static analysis tools
- Validate requirements against implementation
- Perform regression testing

### Bug Analysis:
- Reproduce bugs systematically
- Identify root causes
- Write regression tests
- Validate fixes thoroughly
- Document test cases clearly

### Test Architecture:
- Organize tests logically
- Use shared fixtures and utilities
- Implement test configuration
- Create test data builders
- Use page object pattern for UI tests
"""
    
    def analyze_task_requirements(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze testing-specific task requirements"""
        title = task.get("issue", {}).get("title", "").lower()
        body = task.get("issue", {}).get("body", "").lower()
        task_type = task.get("analysis", {}).get("type", "")
        
        analysis = {
            "needs_unit_tests": False,
            "needs_integration_tests": False,
            "needs_e2e_tests": False,
            "needs_bug_fix": False,
            "needs_performance_tests": False,
            "test_framework": "pytest",  # default
            "complexity_factors": []
        }
        
        # Check for unit testing needs
        unit_terms = ["unit", "function", "method", "class", "module"]
        if any(term in title + body for term in unit_terms):
            analysis["needs_unit_tests"] = True
            analysis["complexity_factors"].append("unit_testing")
        
        # Check for integration testing needs
        integration_terms = ["integration", "api", "database", "service", "component"]
        if any(term in title + body for term in integration_terms):
            analysis["needs_integration_tests"] = True
            analysis["complexity_factors"].append("integration_testing")
        
        # Check for e2e testing needs
        e2e_terms = ["e2e", "end-to-end", "ui", "user", "workflow", "browser"]
        if any(term in title + body for term in e2e_terms):
            analysis["needs_e2e_tests"] = True
            analysis["complexity_factors"].append("e2e_testing")
        
        # Check for bug fix needs
        if task_type == "bug" or any(term in title + body for term in ["bug", "fix", "error", "failure"]):
            analysis["needs_bug_fix"] = True
            analysis["complexity_factors"].append("bug_fixing")
        
        # Check for performance testing needs
        performance_terms = ["performance", "load", "stress", "speed", "optimization"]
        if any(term in title + body for term in performance_terms):
            analysis["needs_performance_tests"] = True
            analysis["complexity_factors"].append("performance_testing")
        
        # Determine test framework
        if any(term in title + body for term in ["jest", "javascript", "react", "frontend"]):
            analysis["test_framework"] = "jest"
        elif any(term in title + body for term in ["pytest", "python", "backend"]):
            analysis["test_framework"] = "pytest"
        
        return analysis
    
    def get_relevant_files_patterns(self) -> List[str]:
        """Get file patterns relevant to testing"""
        return [
            "test_*.py",
            "*_test.py",
            "*/tests/*",
            "*/test/*",
            "*.test.js",
            "*.test.ts",
            "*.test.tsx",
            "*.spec.js",
            "*.spec.ts",
            "*.spec.tsx",
            "conftest.py",
            "pytest.ini",
            "jest.config.js",
            "cypress.json",
            "playwright.config.js",
            "*/fixtures/*",
            "*/mocks/*",
            "*/test-utils/*",
            "*/e2e/*",
            "*/cypress/*",
            "*/playwright/*",
            "coverage/*",
            ".coveragerc",
            "coverage.xml",
            "junit.xml"
        ]
    
    def validate_implementation(self, implementation: Dict[str, Any], task: Dict[str, Any]) -> Dict[str, Any]:
        """Validate testing implementation"""
        changes = implementation.get("changes", [])
        validation = {
            "valid": True,
            "issues": [],
            "warnings": [],
            "suggestions": []
        }
        
        # Check for test files
        test_files = [
            change for change in changes 
            if any(pattern in change.get("file_path", "") for pattern in ["test_", "_test", ".test.", ".spec."])
        ]
        
        if not test_files:
            validation["warnings"].append("No test files found in implementation")
        
        # Check task-specific requirements
        task_analysis = self.analyze_task_requirements(task)
        
        # Validate test structure
        for test_file in test_files:
            content = test_file.get("content", "")
            file_path = test_file.get("file_path", "")
            
            # Check for proper test function naming
            if task_analysis["test_framework"] == "pytest":
                if "def test_" not in content:
                    validation["warnings"].append(f"No test functions found in {file_path}")
            elif task_analysis["test_framework"] == "jest":
                if "test(" not in content and "it(" not in content:
                    validation["warnings"].append(f"No test cases found in {file_path}")
            
            # Check for assertions
            assertion_terms = ["assert", "expect", "should", "assertEqual", "toBe", "toEqual"]
            if not any(term in content for term in assertion_terms):
                validation["warnings"].append(f"No assertions found in {file_path}")
        
        # Check for specific test types
        if task_analysis["needs_unit_tests"]:
            unit_test_indicators = ["test_", "def test", "it(", "describe("]
            has_unit_tests = any(
                any(indicator in change.get("content", "") for indicator in unit_test_indicators)
                for change in test_files
            )
            if not has_unit_tests:
                validation["warnings"].append("Task requires unit tests but none found")
        
        if task_analysis["needs_integration_tests"]:
            integration_indicators = ["integration", "api", "database", "service"]
            has_integration_tests = any(
                any(indicator in change.get("content", "").lower() for indicator in integration_indicators)
                for change in test_files
            )
            if not has_integration_tests:
                validation["suggestions"].append("Consider adding integration tests")
        
        if task_analysis["needs_bug_fix"]:
            # Check for regression test
            regression_indicators = ["regression", "bug", "fix", "issue"]
            has_regression_test = any(
                any(indicator in change.get("content", "").lower() for indicator in regression_indicators)
                for change in test_files
            )
            if not has_regression_test:
                validation["suggestions"].append("Consider adding regression test for the bug fix")
        
        return validation
    
    def get_claude_model(self) -> str:
        """Get appropriate Claude model for testing tasks"""
        return "claude-3-sonnet-20240229"  # Use Sonnet for thorough test analysis
    
    def get_testing_strategy(self, task: Dict[str, Any]) -> List[str]:
        """Get testing-specific strategy"""
        strategy = [
            "Write comprehensive test cases",
            "Test both positive and negative scenarios",
            "Include edge cases and boundary conditions",
            "Test error handling and exceptions",
            "Ensure proper test isolation",
            "Use appropriate mocking strategies"
        ]
        
        task_analysis = self.analyze_task_requirements(task)
        
        if task_analysis["needs_unit_tests"]:
            strategy.extend([
                "Test individual functions in isolation",
                "Mock external dependencies",
                "Test all code paths and branches"
            ])
        
        if task_analysis["needs_integration_tests"]:
            strategy.extend([
                "Test component interactions",
                "Test API endpoints end-to-end",
                "Test database operations"
            ])
        
        if task_analysis["needs_e2e_tests"]:
            strategy.extend([
                "Test complete user workflows",
                "Test across different browsers",
                "Test responsive design"
            ])
        
        if task_analysis["needs_bug_fix"]:
            strategy.extend([
                "Write test to reproduce the bug",
                "Verify fix resolves the issue",
                "Add regression test"
            ])
        
        return strategy
    
    def get_review_criteria(self, task: Dict[str, Any]) -> List[str]:
        """Get testing-specific review criteria"""
        criteria = [
            "Test coverage is comprehensive",
            "Test cases are well-organized and readable",
            "Tests are independent and isolated",
            "Mocking is used appropriately",
            "Test names are descriptive",
            "Tests cover edge cases and error conditions",
            "Test execution is fast and reliable"
        ]
        
        task_analysis = self.analyze_task_requirements(task)
        
        if task_analysis["needs_unit_tests"]:
            criteria.extend([
                "Unit tests cover all public methods",
                "Tests are focused and atomic",
                "External dependencies are mocked"
            ])
        
        if task_analysis["needs_integration_tests"]:
            criteria.extend([
                "Integration tests verify component interactions",
                "Database tests use proper fixtures",
                "API tests validate request/response"
            ])
        
        if task_analysis["needs_bug_fix"]:
            criteria.extend([
                "Bug reproduction test is included",
                "Fix is verified with tests",
                "Regression test prevents future occurrences"
            ])
        
        return criteria
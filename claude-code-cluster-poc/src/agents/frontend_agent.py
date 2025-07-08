"""Frontend specialized agent"""

import logging
from typing import Dict, Any, List
from pathlib import Path

from .base_agent import BaseSpecializedAgent
from src.utils.logging import get_logger


logger = get_logger(__name__)


class FrontendAgent(BaseSpecializedAgent):
    """Agent specialized in frontend development"""
    
    def __init__(self, agent_id: str = "frontend-agent"):
        super().__init__(agent_id, ["frontend", "ui", "react", "javascript", "typescript"])
    
    def can_handle_task(self, task: Dict[str, Any]) -> float:
        """Check if agent can handle frontend tasks"""
        requirements = task.get("analysis", {}).get("requirements", [])
        keywords = task.get("analysis", {}).get("keywords", [])
        title = task.get("issue", {}).get("title", "").lower()
        body = task.get("issue", {}).get("body", "").lower()
        
        score = 0.0
        
        # Check requirements
        frontend_requirements = ["frontend", "ui", "react", "javascript", "typescript"]
        matching_requirements = [req for req in requirements if req in frontend_requirements]
        if matching_requirements:
            score += 0.8 * (len(matching_requirements) / len(frontend_requirements))
        
        # Check keywords
        frontend_keywords = [
            "ui", "frontend", "react", "component", "javascript", "typescript", "css",
            "html", "jsx", "tsx", "hook", "state", "props", "interface", "responsive",
            "design", "styling", "layout", "navigation", "form", "validation", "user"
        ]
        matching_keywords = [kw for kw in keywords if kw in frontend_keywords]
        if matching_keywords:
            score += 0.6 * min(1.0, len(matching_keywords) / 5)
        
        # Check title and body
        frontend_terms = [
            "ui", "frontend", "react", "component", "interface", "design", "layout",
            "form", "button", "modal", "page", "view", "navigation", "styling", "css"
        ]
        title_matches = sum(1 for term in frontend_terms if term in title)
        body_matches = sum(1 for term in frontend_terms if term in body)
        
        if title_matches > 0:
            score += 0.4 * min(1.0, title_matches / 3)
        if body_matches > 0:
            score += 0.2 * min(1.0, body_matches / 5)
        
        return min(1.0, score)
    
    def get_system_prompt_additions(self) -> str:
        """Get frontend-specific system prompt additions"""
        return """
## Frontend Development Focus

You are specialized in frontend development with expertise in:

### Core Technologies:
- **React**: Components, hooks, state management, context
- **TypeScript/JavaScript**: ES6+, async/await, modules
- **CSS**: Flexbox, Grid, responsive design, animations
- **HTML**: Semantic markup, accessibility, SEO
- **Testing**: Jest, React Testing Library, Cypress

### Best Practices:
- Write reusable and composable components
- Follow React best practices and hooks patterns
- Implement proper state management
- Use TypeScript for type safety
- Follow accessibility guidelines (WCAG)
- Implement responsive design principles
- Optimize performance (lazy loading, memoization)
- Write comprehensive tests

### Code Structure:
- Organize components hierarchically
- Separate concerns (presentation vs logic)
- Use custom hooks for reusable logic
- Implement proper error boundaries
- Follow consistent naming conventions
- Create maintainable CSS architecture

### UI/UX Considerations:
- Create intuitive user interfaces
- Implement proper form validation
- Handle loading and error states
- Ensure mobile responsiveness
- Follow design systems and style guides
- Implement proper navigation patterns

### Performance:
- Optimize bundle size
- Implement code splitting
- Use proper image optimization
- Minimize re-renders
- Implement proper caching strategies
"""
    
    def analyze_task_requirements(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze frontend-specific task requirements"""
        title = task.get("issue", {}).get("title", "").lower()
        body = task.get("issue", {}).get("body", "").lower()
        
        analysis = {
            "needs_component": False,
            "needs_styling": False,
            "needs_state_management": False,
            "needs_routing": False,
            "needs_forms": False,
            "needs_responsive": False,
            "complexity_factors": []
        }
        
        # Check for component needs
        component_terms = ["component", "element", "widget", "ui", "interface"]
        if any(term in title + body for term in component_terms):
            analysis["needs_component"] = True
            analysis["complexity_factors"].append("component_development")
        
        # Check for styling needs
        styling_terms = ["style", "css", "design", "layout", "responsive", "theme"]
        if any(term in title + body for term in styling_terms):
            analysis["needs_styling"] = True
            analysis["complexity_factors"].append("styling")
        
        # Check for state management
        state_terms = ["state", "context", "redux", "store", "data", "management"]
        if any(term in title + body for term in state_terms):
            analysis["needs_state_management"] = True
            analysis["complexity_factors"].append("state_management")
        
        # Check for routing
        routing_terms = ["route", "navigation", "router", "page", "redirect"]
        if any(term in title + body for term in routing_terms):
            analysis["needs_routing"] = True
            analysis["complexity_factors"].append("routing")
        
        # Check for forms
        form_terms = ["form", "input", "validation", "submit", "field"]
        if any(term in title + body for term in form_terms):
            analysis["needs_forms"] = True
            analysis["complexity_factors"].append("forms")
        
        # Check for responsive design
        responsive_terms = ["responsive", "mobile", "tablet", "desktop", "breakpoint"]
        if any(term in title + body for term in responsive_terms):
            analysis["needs_responsive"] = True
            analysis["complexity_factors"].append("responsive_design")
        
        return analysis
    
    def get_relevant_files_patterns(self) -> List[str]:
        """Get file patterns relevant to frontend development"""
        return [
            "*.tsx",
            "*.jsx", 
            "*.ts",
            "*.js",
            "*.css",
            "*.scss",
            "*.sass",
            "*.less",
            "*.html",
            "*/components/*",
            "*/pages/*",
            "*/views/*",
            "*/styles/*",
            "*/assets/*",
            "*/hooks/*",
            "*/context/*",
            "*/utils/*",
            "*/types/*",
            "package.json",
            "tsconfig.json",
            "*.config.js",
            "*/tests/*",
            "*/test/*",
            "*.test.tsx",
            "*.test.ts",
            "*.spec.tsx",
            "*.spec.ts"
        ]
    
    def validate_implementation(self, implementation: Dict[str, Any], task: Dict[str, Any]) -> Dict[str, Any]:
        """Validate frontend implementation"""
        changes = implementation.get("changes", [])
        validation = {
            "valid": True,
            "issues": [],
            "warnings": [],
            "suggestions": []
        }
        
        # Check for required files
        frontend_files = [
            change for change in changes 
            if any(change.get("file_path", "").endswith(ext) for ext in [".tsx", ".jsx", ".ts", ".js"])
        ]
        if not frontend_files:
            validation["issues"].append("No frontend files found in implementation")
            validation["valid"] = False
        
        # Check for proper React patterns
        for change in frontend_files:
            content = change.get("content", "")
            file_path = change.get("file_path", "")
            
            # Check for React imports
            if file_path.endswith((".tsx", ".jsx")):
                if "import React" not in content and "import {" not in content:
                    validation["warnings"].append(f"Missing React import in {file_path}")
            
            # Check for TypeScript usage
            if file_path.endswith(".tsx") or file_path.endswith(".ts"):
                if ":" not in content and "interface" not in content and "type" not in content:
                    validation["warnings"].append(f"Consider adding TypeScript types in {file_path}")
        
        # Check task-specific requirements
        task_analysis = self.analyze_task_requirements(task)
        
        if task_analysis["needs_component"]:
            component_terms = ["function", "const", "export", "component"]
            has_component_code = any(
                any(term in change.get("content", "").lower() for term in component_terms)
                for change in frontend_files
            )
            if not has_component_code:
                validation["warnings"].append("Task requires component implementation but no component code found")
        
        if task_analysis["needs_styling"]:
            css_files = [change for change in changes if change.get("file_path", "").endswith((".css", ".scss", ".sass"))]
            has_inline_styles = any("style=" in change.get("content", "") for change in frontend_files)
            if not css_files and not has_inline_styles:
                validation["warnings"].append("Task requires styling but no CSS files or inline styles found")
        
        if task_analysis["needs_forms"]:
            form_terms = ["form", "input", "onchange", "onsubmit", "validation"]
            has_form_code = any(
                any(term in change.get("content", "").lower() for term in form_terms)
                for change in frontend_files
            )
            if not has_form_code:
                validation["warnings"].append("Task requires form implementation but no form code found")
        
        # Check for accessibility
        a11y_terms = ["alt=", "aria-", "role=", "tabindex", "label"]
        has_a11y = any(
            any(term in change.get("content", "") for term in a11y_terms)
            for change in frontend_files
        )
        if not has_a11y:
            validation["suggestions"].append("Consider adding accessibility attributes")
        
        return validation
    
    def get_claude_model(self) -> str:
        """Get appropriate Claude model for frontend tasks"""
        return "claude-3-haiku-20240307"  # Haiku is good for frontend code generation
    
    def get_testing_strategy(self, task: Dict[str, Any]) -> List[str]:
        """Get frontend-specific testing strategy"""
        strategy = [
            "Component rendering tests",
            "User interaction tests",
            "Props and state tests",
            "Event handling tests",
            "Snapshot testing",
            "Accessibility testing"
        ]
        
        task_analysis = self.analyze_task_requirements(task)
        
        if task_analysis["needs_component"]:
            strategy.extend([
                "Component lifecycle tests",
                "Hook behavior tests",
                "Context provider tests"
            ])
        
        if task_analysis["needs_styling"]:
            strategy.extend([
                "CSS class application tests",
                "Responsive design tests",
                "Theme switching tests"
            ])
        
        if task_analysis["needs_state_management"]:
            strategy.extend([
                "State update tests",
                "Context state tests",
                "Redux action tests"
            ])
        
        if task_analysis["needs_forms"]:
            strategy.extend([
                "Form validation tests",
                "Input field tests",
                "Form submission tests"
            ])
        
        if task_analysis["needs_routing"]:
            strategy.extend([
                "Route navigation tests",
                "Route parameter tests",
                "Protected route tests"
            ])
        
        return strategy
    
    def get_review_criteria(self, task: Dict[str, Any]) -> List[str]:
        """Get frontend-specific review criteria"""
        criteria = [
            "Components are reusable and well-structured",
            "TypeScript types are properly defined",
            "CSS follows best practices and conventions",
            "Accessibility guidelines are followed",
            "Code is responsive and mobile-friendly",
            "Performance optimizations are implemented",
            "Error handling is appropriate for UI"
        ]
        
        task_analysis = self.analyze_task_requirements(task)
        
        if task_analysis["needs_component"]:
            criteria.extend([
                "Component props are well-defined",
                "Component state is managed properly",
                "Component composition is logical"
            ])
        
        if task_analysis["needs_styling"]:
            criteria.extend([
                "CSS is organized and maintainable",
                "Design system is followed",
                "Responsive breakpoints are appropriate"
            ])
        
        if task_analysis["needs_state_management"]:
            criteria.extend([
                "State updates are immutable",
                "Context usage is appropriate",
                "State structure is logical"
            ])
        
        if task_analysis["needs_forms"]:
            criteria.extend([
                "Form validation is comprehensive",
                "User experience is smooth",
                "Error messages are helpful"
            ])
        
        return criteria
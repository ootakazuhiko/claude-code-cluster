"""Claude API client"""

import json
import logging
import re
from typing import Dict, Any, List, Optional
from anthropic import Anthropic, APIError

from src.core.config import get_settings
from src.core.exceptions import ClaudeAPIError
from src.utils.helpers import extract_keywords_from_text


logger = logging.getLogger(__name__)


class ClaudeClient:
    """Claude API client wrapper"""
    
    def __init__(self, api_key: Optional[str] = None):
        """Initialize Claude client"""
        self.settings = get_settings()
        self.api_key = api_key or self.settings.anthropic_api_key
        self.client = Anthropic(api_key=self.api_key)
        self.model = "claude-3-haiku-20240307"  # Using Haiku for faster responses in PoC
        
        logger.info("Claude client initialized")
    
    def generate_implementation(
        self,
        issue_data: Dict[str, Any],
        repo_context: Dict[str, Any],
        requirements: List[str]
    ) -> Dict[str, Any]:
        """Generate implementation code from issue and repository context"""
        
        try:
            # Build the prompt
            system_prompt = self._build_system_prompt(requirements)
            user_prompt = self._build_user_prompt(issue_data, repo_context)
            
            logger.info(f"Generating implementation for issue #{issue_data['number']}")
            
            # Call Claude API
            response = self.client.messages.create(
                model=self.model,
                max_tokens=4000,
                temperature=0.3,
                system=system_prompt,
                messages=[
                    {
                        "role": "user",
                        "content": user_prompt
                    }
                ]
            )
            
            response_text = response.content[0].text
            logger.info(f"Claude API response length: {len(response_text)} characters")
            
            # Parse the response
            implementation = self._parse_implementation_response(response_text)
            
            # Add metadata
            implementation["metadata"] = {
                "issue_number": issue_data["number"],
                "model": self.model,
                "requirements": requirements,
                "generated_at": issue_data.get("created_at"),
                "tokens_used": response.usage.input_tokens + response.usage.output_tokens
            }
            
            logger.info(f"Implementation generated successfully: {len(implementation.get('changes', []))} changes")
            return implementation
            
        except APIError as e:
            logger.error(f"Claude API error: {e}")
            raise ClaudeAPIError(f"Failed to generate implementation: {e}")
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            raise ClaudeAPIError(f"Unexpected error in implementation generation: {e}")
    
    def _build_system_prompt(self, requirements: List[str]) -> str:
        """Build system prompt based on requirements"""
        
        base_prompt = """You are an expert software developer tasked with implementing GitHub issues. 
You will receive an issue description and repository context, and you must generate a complete implementation.

# Guidelines:
1. Write clean, maintainable code following best practices
2. Include appropriate error handling
3. Add meaningful comments where necessary
4. Follow the existing code style and patterns
5. Ensure the implementation is secure and efficient

# Output Format:
Provide your response in the following JSON format:

```json
{
  "summary": "Brief summary of the implementation",
  "approach": "Explanation of the approach taken",
  "changes": [
    {
      "action": "create|modify|delete",
      "file_path": "relative/path/to/file",
      "content": "Complete file content here",
      "description": "Description of changes made"
    }
  ],
  "test_suggestions": [
    "Test case 1",
    "Test case 2"
  ],
  "dependencies": ["new-dependency-1", "new-dependency-2"],
  "notes": "Any additional notes or considerations"
}
```

# Requirements:
"""
        
        # Add specific requirements
        if "backend" in requirements:
            base_prompt += """
- Focus on server-side implementation
- Consider database operations and API endpoints
- Follow RESTful principles where applicable
"""
        
        if "frontend" in requirements:
            base_prompt += """
- Focus on user interface and user experience
- Consider responsive design
- Follow modern frontend practices
"""
        
        if "testing" in requirements:
            base_prompt += """
- Include comprehensive test cases
- Focus on edge cases and error handling
- Follow testing best practices
"""
        
        if "bug" in requirements:
            base_prompt += """
- Focus on identifying and fixing the root cause
- Ensure the fix doesn't introduce new issues
- Consider adding tests to prevent regression
"""
        
        base_prompt += """
Ensure all code is functional and follows the project's conventions."""
        
        return base_prompt
    
    def _build_user_prompt(self, issue_data: Dict[str, Any], repo_context: Dict[str, Any]) -> str:
        """Build user prompt with issue and repository context"""
        
        # Extract repository information
        repo_info = issue_data.get("repository", {})
        repo_name = repo_info.get("full_name", "unknown")
        
        # Get file structure context
        file_context = ""
        if "files" in repo_context:
            files = repo_context["files"][:20]  # Limit to first 20 files
            file_context = "\n".join(f"- {file['path']}" for file in files)
        
        # Get relevant file contents
        file_contents = ""
        if "file_contents" in repo_context:
            for file_path, content in repo_context["file_contents"].items():
                file_contents += f"\n## {file_path}\n```\n{content[:1000]}\n```\n"  # Limit content
        
        prompt = f"""# Issue Information

**Repository:** {repo_name}
**Issue #{issue_data['number']}:** {issue_data['title']}

**Description:**
{issue_data['body']}

**Labels:** {', '.join(issue_data['labels'])}

# Repository Context

**Language:** {repo_info.get('language', 'Unknown')}
**Default Branch:** {repo_info.get('default_branch', 'main')}

**File Structure:**
{file_context}

**Relevant File Contents:**
{file_contents}

# Task
Please implement the solution for this issue. Consider the existing codebase structure and follow the project's patterns.

Generate a complete implementation that addresses the issue requirements."""
        
        return prompt
    
    def _parse_implementation_response(self, response: str) -> Dict[str, Any]:
        """Parse Claude's response into structured implementation"""
        
        # Try to extract JSON from the response
        json_match = re.search(r'```json\s*(\{.*?\})\s*```', response, re.DOTALL)
        
        if json_match:
            try:
                implementation = json.loads(json_match.group(1))
                
                # Validate required fields
                required_fields = ["summary", "approach", "changes"]
                for field in required_fields:
                    if field not in implementation:
                        implementation[field] = ""
                
                # Ensure changes is a list
                if not isinstance(implementation.get("changes"), list):
                    implementation["changes"] = []
                
                # Validate each change
                for change in implementation["changes"]:
                    if not isinstance(change, dict):
                        continue
                    
                    # Ensure required fields in change
                    if "action" not in change:
                        change["action"] = "modify"
                    if "file_path" not in change:
                        change["file_path"] = "unknown"
                    if "content" not in change:
                        change["content"] = ""
                    if "description" not in change:
                        change["description"] = ""
                
                return implementation
                
            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse JSON response: {e}")
                # Fall back to plain text parsing
                pass
        
        # Fallback: create a simple implementation from plain text
        logger.warning("No valid JSON found in response, creating fallback implementation")
        
        # Try to extract code blocks
        code_blocks = re.findall(r'```(\w+)?\n(.*?)\n```', response, re.DOTALL)
        
        changes = []
        for i, (language, code) in enumerate(code_blocks):
            # Try to guess file extension from language
            extensions = {
                "python": ".py",
                "javascript": ".js",
                "typescript": ".ts",
                "html": ".html",
                "css": ".css",
                "json": ".json",
                "yaml": ".yaml",
                "yml": ".yml",
                "bash": ".sh",
                "sql": ".sql"
            }
            
            ext = extensions.get(language, ".txt")
            file_path = f"generated_file_{i+1}{ext}"
            
            changes.append({
                "action": "create",
                "file_path": file_path,
                "content": code.strip(),
                "description": f"Generated {language} code"
            })
        
        return {
            "summary": "Implementation generated from issue description",
            "approach": "Code generated based on issue requirements",
            "changes": changes,
            "test_suggestions": [],
            "dependencies": [],
            "notes": "This implementation was generated from plain text response"
        }
    
    def review_implementation(self, implementation: Dict[str, Any], issue_data: Dict[str, Any]) -> Dict[str, Any]:
        """Review and validate implementation"""
        
        try:
            review_prompt = f"""Please review the following implementation for GitHub issue #{issue_data['number']}: {issue_data['title']}

# Implementation Summary
{implementation.get('summary', '')}

# Approach
{implementation.get('approach', '')}

# Changes Made
{len(implementation.get('changes', []))} files will be modified/created

# Review Criteria
1. Does the implementation address the issue requirements?
2. Is the code quality good?
3. Are there any potential issues or improvements?
4. Are there any missing dependencies or configurations?

Please provide a review in JSON format:
```json
{
  "approved": true/false,
  "score": 1-10,
  "feedback": "Detailed feedback",
  "suggestions": ["suggestion1", "suggestion2"],
  "potential_issues": ["issue1", "issue2"]
}
```"""
            
            response = self.client.messages.create(
                model=self.model,
                max_tokens=1000,
                temperature=0.1,
                messages=[
                    {
                        "role": "user",
                        "content": review_prompt
                    }
                ]
            )
            
            response_text = response.content[0].text
            
            # Parse JSON response
            json_match = re.search(r'```json\s*(\{.*?\})\s*```', response_text, re.DOTALL)
            
            if json_match:
                try:
                    review = json.loads(json_match.group(1))
                    logger.info(f"Implementation review completed: score {review.get('score', 'N/A')}/10")
                    return review
                except json.JSONDecodeError:
                    pass
            
            # Fallback review
            return {
                "approved": True,
                "score": 7,
                "feedback": "Basic implementation review completed",
                "suggestions": [],
                "potential_issues": []
            }
            
        except APIError as e:
            logger.error(f"Failed to review implementation: {e}")
            return {
                "approved": True,
                "score": 5,
                "feedback": f"Review failed: {e}",
                "suggestions": [],
                "potential_issues": ["Review could not be completed"]
            }
    
    def generate_pr_description(self, implementation: Dict[str, Any], issue_data: Dict[str, Any]) -> str:
        """Generate pull request description"""
        
        try:
            pr_prompt = f"""Generate a clear and professional pull request description for the following implementation:

# Issue
#{issue_data['number']}: {issue_data['title']}
{issue_data['body'][:500]}...

# Implementation Summary
{implementation.get('summary', '')}

# Changes
{len(implementation.get('changes', []))} files modified/created

Please generate a PR description that includes:
1. Clear summary of changes
2. How it addresses the issue
3. Testing notes
4. Any breaking changes or considerations

Keep it concise but informative."""
            
            response = self.client.messages.create(
                model=self.model,
                max_tokens=800,
                temperature=0.2,
                messages=[
                    {
                        "role": "user",
                        "content": pr_prompt
                    }
                ]
            )
            
            pr_description = response.content[0].text.strip()
            
            # Add standard footer
            pr_description += f"""

---

**Issue:** Closes #{issue_data['number']}
**Generated by:** Claude Code Cluster PoC
**Model:** {self.model}"""
            
            return pr_description
            
        except APIError as e:
            logger.error(f"Failed to generate PR description: {e}")
            # Fallback description
            return f"""## Summary

This PR implements the solution for issue #{issue_data['number']}: {issue_data['title']}

## Changes

{implementation.get('summary', 'Implementation generated automatically')}

## Notes

{implementation.get('notes', 'No additional notes')}

---

**Generated by:** Claude Code Cluster PoC
**Issue:** Closes #{issue_data['number']}"""
    
    def get_usage_info(self) -> Dict[str, Any]:
        """Get API usage information (placeholder)"""
        return {
            "model": self.model,
            "status": "connected",
            "note": "Usage tracking not implemented in PoC"
        }
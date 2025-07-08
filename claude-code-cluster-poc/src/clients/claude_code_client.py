"""Claude Code CLI client for distributed execution"""

import asyncio
import json
import logging
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, Any, List, Optional
import shutil

from src.core.config import get_settings
from src.utils.logging import get_logger


logger = get_logger(__name__)


class ClaudeCodeClient:
    """Client for executing Claude Code CLI commands"""
    
    def __init__(self):
        self.settings = get_settings()
        self.claude_code_path = self._find_claude_code_cli()
        
        if not self.claude_code_path:
            raise RuntimeError("Claude Code CLI not found. Please install Claude Code CLI first.")
        
        logger.info(f"Claude Code CLI found at: {self.claude_code_path}")
    
    def _find_claude_code_cli(self) -> Optional[str]:
        """Find Claude Code CLI executable"""
        # Check environment variable first
        if hasattr(self.settings, 'claude_code_cli_path'):
            cli_path = self.settings.claude_code_cli_path
            if Path(cli_path).exists():
                return cli_path
        
        # Check common locations
        common_paths = [
            '/usr/local/bin/claude-code',
            '/usr/bin/claude-code',
            '/opt/claude-code/bin/claude-code',
            '~/.local/bin/claude-code'
        ]
        
        for path in common_paths:
            expanded_path = Path(path).expanduser()
            if expanded_path.exists():
                return str(expanded_path)
        
        # Check if it's in PATH
        claude_code_path = shutil.which('claude-code')
        if claude_code_path:
            return claude_code_path
        
        return None
    
    def check_claude_code_status(self) -> Dict[str, Any]:
        """Check Claude Code CLI status and authentication"""
        try:
            result = subprocess.run(
                [self.claude_code_path, '--version'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                return {
                    'available': True,
                    'version': result.stdout.strip(),
                    'path': self.claude_code_path
                }
            else:
                return {
                    'available': False,
                    'error': result.stderr or 'Unknown error',
                    'path': self.claude_code_path
                }
        
        except Exception as e:
            return {
                'available': False,
                'error': str(e),
                'path': self.claude_code_path
            }
    
    async def generate_implementation(self, issue_data: Dict[str, Any], 
                                    repo_context: Dict[str, Any],
                                    requirements: List[str],
                                    workspace_path: str,
                                    agent_specialty: str = None) -> Dict[str, Any]:
        """
        Generate implementation using Claude Code CLI
        
        Args:
            issue_data: GitHub issue information
            repo_context: Repository context and file information
            requirements: List of technical requirements
            workspace_path: Path to workspace directory
            agent_specialty: Agent specialty (backend, frontend, testing, devops)
        
        Returns:
            Dict containing success status, changes, and execution details
        """
        try:
            # Prepare context for Claude Code
            context = self._build_claude_context(
                issue_data, repo_context, requirements, agent_specialty
            )
            
            # Execute Claude Code CLI
            result = await self._execute_claude_code(context, workspace_path)
            
            if result['success']:
                # Analyze changes made by Claude Code
                changes = await self._analyze_changes(workspace_path)
                
                return {
                    'success': True,
                    'changes': changes,
                    'execution_log': result['output'],
                    'workspace_path': workspace_path,
                    'agent_specialty': agent_specialty
                }
            else:
                return {
                    'success': False,
                    'error': result['error'],
                    'execution_log': result['output'],
                    'workspace_path': workspace_path
                }
        
        except Exception as e:
            logger.error(f"Error in generate_implementation: {e}")
            return {
                'success': False,
                'error': str(e),
                'workspace_path': workspace_path
            }
    
    def _build_claude_context(self, issue_data: Dict[str, Any], 
                             repo_context: Dict[str, Any],
                             requirements: List[str],
                             agent_specialty: str = None) -> str:
        """Build context prompt for Claude Code CLI"""
        
        # Get specialty-specific context
        specialty_context = self._get_specialty_context(agent_specialty, repo_context)
        
        context = f"""# GitHub Issue Resolution

## Issue Information
- **Issue #{issue_data['number']}**: {issue_data['title']}
- **Repository**: {repo_context.get('repository_name', 'Unknown')}
- **Agent Specialty**: {agent_specialty or 'General'}

## Issue Description
{issue_data['body']}

## Repository Analysis
{repo_context.get('summary', 'No summary available')}

## Current File Structure
```
{repo_context.get('file_structure', 'No structure available')}
```

## Detected Technologies
{', '.join(repo_context.get('technologies', []))}

## Requirements
{json.dumps(requirements, indent=2)}

{specialty_context}

## Task Instructions
Please analyze this issue and implement the necessary changes:

1. **Understand the codebase**: Review existing code patterns and architecture
2. **Implement the solution**: Create/modify files to resolve the issue
3. **Follow conventions**: Maintain existing code style and patterns
4. **Add tests**: Include appropriate tests for new functionality
5. **Update documentation**: Update relevant documentation if needed

Please make all necessary changes to completely resolve this issue.
"""
        return context
    
    def _get_specialty_context(self, agent_specialty: str, repo_context: Dict[str, Any]) -> str:
        """Generate specialty-specific context"""
        
        if agent_specialty == 'backend':
            return """
## Backend Development Focus
- Implement server-side logic, APIs, and database operations
- Follow backend best practices (error handling, logging, validation)
- Consider database migrations and schema changes
- Ensure proper API documentation and testing
- Focus on performance and security considerations
"""
        
        elif agent_specialty == 'frontend':
            return """
## Frontend Development Focus  
- Implement UI components and user interactions
- Follow frontend best practices (accessibility, responsive design)
- Ensure proper state management and component structure
- Add comprehensive component testing
- Consider user experience and design consistency
"""
        
        elif agent_specialty == 'testing':
            return """
## Testing Specialist Focus
- Implement comprehensive test coverage (unit, integration, e2e)
- Follow testing best practices for reliability and maintainability
- Add performance and security tests where appropriate
- Ensure test documentation and setup instructions
- Focus on edge cases and error scenarios
"""
        
        elif agent_specialty == 'devops':
            return """
## DevOps Specialist Focus
- Implement infrastructure, deployment, and CI/CD improvements
- Follow containerization and orchestration best practices
- Add monitoring, logging, and observability features
- Ensure security and scalability considerations
- Update deployment and infrastructure documentation
"""
        
        else:
            return """
## General Development Focus
- Follow project conventions and best practices
- Ensure code quality and maintainability
- Add appropriate tests and documentation
- Consider both immediate solution and long-term maintainability
"""
    
    async def _execute_claude_code(self, context: str, workspace_path: str) -> Dict[str, Any]:
        """Execute Claude Code CLI with the given context"""
        
        workspace = Path(workspace_path)
        if not workspace.exists():
            workspace.mkdir(parents=True, exist_ok=True)
        
        # Create temporary context file
        context_file = workspace / '.claude_context.md'
        context_file.write_text(context, encoding='utf-8')
        
        try:
            # Build Claude Code command
            cmd = [
                self.claude_code_path,
                '--directory', str(workspace),
                '--non-interactive',  # Non-interactive mode
                '--context-file', str(context_file)
            ]
            
            # Execute Claude Code CLI
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=workspace
            )
            
            stdout, stderr = await process.communicate()
            
            output = stdout.decode('utf-8') if stdout else ''
            error = stderr.decode('utf-8') if stderr else ''
            
            return {
                'success': process.returncode == 0,
                'output': output,
                'error': error if process.returncode != 0 else None,
                'return_code': process.returncode
            }
        
        except Exception as e:
            return {
                'success': False,
                'output': '',
                'error': str(e),
                'return_code': -1
            }
        
        finally:
            # Clean up context file
            if context_file.exists():
                try:
                    context_file.unlink()
                except Exception:
                    pass  # Ignore cleanup errors
    
    async def _analyze_changes(self, workspace_path: str) -> List[Dict[str, Any]]:
        """Analyze changes made by Claude Code in the workspace"""
        
        workspace = Path(workspace_path)
        changes = []
        
        try:
            # Use git to detect changes
            result = await asyncio.create_subprocess_exec(
                'git', 'status', '--porcelain',
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=workspace
            )
            
            stdout, stderr = await result.communicate()
            
            if result.returncode == 0:
                lines = stdout.decode('utf-8').strip().split('\n')
                
                for line in lines:
                    if not line.strip():
                        continue
                    
                    status = line[:2]
                    file_path = line[3:]
                    
                    change_type = 'modified'
                    if status.startswith('A'):
                        change_type = 'added'
                    elif status.startswith('D'):
                        change_type = 'deleted'
                    elif status.startswith('M'):
                        change_type = 'modified'
                    elif status.startswith('??'):
                        change_type = 'untracked'
                    
                    full_path = workspace / file_path
                    content = ''
                    
                    if change_type != 'deleted' and full_path.exists():
                        try:
                            content = full_path.read_text(encoding='utf-8')
                        except Exception:
                            content = '<binary or unreadable file>'
                    
                    changes.append({
                        'file_path': file_path,
                        'change_type': change_type,
                        'content': content[:10000] if len(content) <= 10000 else content[:10000] + '...[truncated]'
                    })
            
            return changes
        
        except Exception as e:
            logger.error(f"Error analyzing changes: {e}")
            return []
    
    def test_claude_code_execution(self, test_workspace: str = None) -> Dict[str, Any]:
        """Test Claude Code CLI execution with a simple task"""
        
        if test_workspace is None:
            test_workspace = tempfile.mkdtemp(prefix='claude_test_')
        
        test_workspace = Path(test_workspace)
        test_workspace.mkdir(parents=True, exist_ok=True)
        
        # Create a simple test context
        test_context = """
# Test Task

Please create a simple Python function that adds two numbers.

## Instructions
1. Create a file called `calculator.py`
2. Implement a function `add(a, b)` that returns a + b
3. Add a simple test to verify the function works

This is a test of the Claude Code CLI integration.
"""
        
        try:
            # Run synchronous version for testing
            result = asyncio.run(self._execute_claude_code(test_context, str(test_workspace)))
            
            if result['success']:
                # Check if files were created
                created_files = list(test_workspace.glob('*'))
                
                return {
                    'success': True,
                    'test_workspace': str(test_workspace),
                    'output': result['output'],
                    'created_files': [str(f.name) for f in created_files],
                    'message': 'Claude Code CLI test completed successfully'
                }
            else:
                return {
                    'success': False,
                    'test_workspace': str(test_workspace),
                    'error': result['error'],
                    'message': 'Claude Code CLI test failed'
                }
        
        except Exception as e:
            return {
                'success': False,
                'test_workspace': str(test_workspace),
                'error': str(e),
                'message': 'Claude Code CLI test encountered an error'
            }
        
        finally:
            # Optional: Clean up test workspace
            # shutil.rmtree(test_workspace, ignore_errors=True)
            pass
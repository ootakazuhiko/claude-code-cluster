#!/usr/bin/env python3
"""
Agent Auto-Loop Hook System for Claude Code
Enables continuous task processing and autonomous agent operation

Based on: https://github.com/ootakazuhiko/claude-code-cluster/blob/main/docs/tmp/claude-code-hook-system-doc.md
Universal hook system for any GitHub repository with Claude Code agents
"""

import time
import sqlite3
import json
import subprocess
import logging
from datetime import datetime
from typing import List, Dict, Optional, Any
from dataclasses import dataclass
from pathlib import Path
import os
import sys

# Add project root to path
sys.path.append(str(Path(__file__).parent.parent))

@dataclass
class AgentConfig:
    """Configuration for each agent"""
    agent_id: str
    specialization: str
    labels: List[str]
    priority_keywords: List[str]
    repo_owner: str
    repo_name: str
    max_task_duration: int = 1800  # 30 minutes
    cooldown_time: int = 60  # 1 minute between tasks
    sonnet_model: str = "claude-3-5-sonnet-20241022"

class AgentAutoLoopHook:
    """
    Claude Code hook for autonomous agent operation
    Continuously monitors for tasks and executes them autonomously
    Universal system for any GitHub repository
    """
    
    def __init__(self, config: AgentConfig):
        self.config = config
        self.repo_full_name = f"{config.repo_owner}/{config.repo_name}"
        self.db_path = Path(f"/tmp/agent-{config.agent_id}-{config.repo_name}-loop.db")
        self.log_path = Path(f"/tmp/agent-{config.agent_id}-{config.repo_name}-loop.log")
        self.setup_logging()
        self.setup_database()
        self.setup_environment()
        
    def setup_logging(self):
        """Setup comprehensive logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.log_path),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(f"Agent-{self.config.agent_id}-{self.config.repo_name}")
        
    def setup_database(self):
        """Setup SQLite database for tracking"""
        self.conn = sqlite3.connect(self.db_path)
        self.conn.execute('''
            CREATE TABLE IF NOT EXISTS task_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                agent_id TEXT NOT NULL,
                repo_name TEXT NOT NULL,
                task_type TEXT NOT NULL,
                task_id TEXT NOT NULL,
                task_title TEXT,
                start_time TIMESTAMP,
                end_time TIMESTAMP,
                duration INTEGER,
                status TEXT,
                error_message TEXT,
                parameters TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        self.conn.execute('''
            CREATE TABLE IF NOT EXISTS agent_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                agent_id TEXT NOT NULL,
                repo_name TEXT NOT NULL,
                date TEXT NOT NULL,
                tasks_completed INTEGER DEFAULT 0,
                tasks_failed INTEGER DEFAULT 0,
                avg_duration REAL DEFAULT 0,
                escalations INTEGER DEFAULT 0,
                autonomous_rate REAL DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        self.conn.commit()
        
    def setup_environment(self):
        """Setup Claude Code environment for agent"""
        os.environ['CLAUDE_MODEL'] = self.config.sonnet_model
        os.environ['CLAUDE_AGENT_MODE'] = 'autonomous'
        os.environ['AGENT_ID'] = self.config.agent_id
        os.environ['AGENT_SPECIALIZATION'] = self.config.specialization
        os.environ['ESCALATION_THRESHOLD'] = str(self.config.max_task_duration)
        os.environ['TARGET_REPO'] = self.repo_full_name
        
    def fetch_available_tasks(self) -> List[Dict[str, Any]]:
        """Fetch available tasks from GitHub"""
        try:
            # Build label filter
            label_filter = ' '.join([f'--label "{label}"' for label in self.config.labels])
            
            # Fetch issues
            cmd = f'gh issue list --repo {self.repo_full_name} --state open {label_filter} --json number,title,labels,assignees,updatedAt --limit 10'
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                issues = json.loads(result.stdout)
                return self.prioritize_tasks(issues)
            else:
                self.logger.error(f"Failed to fetch tasks: {result.stderr}")
                return []
                
        except Exception as e:
            self.logger.error(f"Error fetching tasks: {e}")
            return []
    
    def prioritize_tasks(self, issues: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Prioritize tasks based on agent specialization and keywords"""
        prioritized = []
        
        for issue in issues:
            score = 0
            title = issue.get('title', '').lower()
            
            # Check for priority keywords
            for keyword in self.config.priority_keywords:
                if keyword.lower() in title:
                    score += 10
            
            # Check for failure/critical keywords
            critical_keywords = ['failure', 'critical', 'urgent', 'broken', 'error']
            for keyword in critical_keywords:
                if keyword in title:
                    score += 20
            
            # Check if unassigned
            if not issue.get('assignees'):
                score += 5
                
            # Check recent activity
            updated_at = datetime.fromisoformat(issue['updatedAt'].replace('Z', '+00:00'))
            hours_since_update = (datetime.now().astimezone() - updated_at).total_seconds() / 3600
            if hours_since_update < 24:
                score += 3
                
            issue['priority_score'] = score
            prioritized.append(issue)
            
        return sorted(prioritized, key=lambda x: x['priority_score'], reverse=True)
    
    def check_task_eligibility(self, task: Dict[str, Any]) -> bool:
        """Check if task is eligible for autonomous processing"""
        # Check if already processed recently
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT COUNT(*) FROM task_history 
            WHERE agent_id = ? AND repo_name = ? AND task_id = ? AND start_time > datetime('now', '-1 hour')
        ''', (self.config.agent_id, self.config.repo_name, str(task['number'])))
        
        recent_attempts = cursor.fetchone()[0]
        if recent_attempts > 0:
            return False
            
        # Check if task is assigned to someone else
        assignees = task.get('assignees', [])
        if assignees and not any(a.get('login') == self.config.agent_id for a in assignees):
            return False
            
        return True
    
    def execute_task(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """Execute a single task autonomously"""
        task_id = str(task['number'])
        task_title = task.get('title', 'Unknown Task')
        start_time = datetime.now()
        
        self.logger.info(f"Starting task #{task_id}: {task_title}")
        
        # Record task start
        self.conn.execute('''
            INSERT INTO task_history (agent_id, repo_name, task_type, task_id, task_title, start_time, status, parameters)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (self.config.agent_id, self.config.repo_name, 'github_issue', task_id, task_title, start_time, 'IN_PROGRESS', json.dumps(task)))
        self.conn.commit()
        
        try:
            # Assign task to agent
            self.assign_task_to_agent(task_id)
            
            # Create Claude Code session with autonomous instructions
            session_result = self.create_autonomous_session(task)
            
            # Monitor task execution
            execution_result = self.monitor_task_execution(task_id, start_time)
            
            # Update task completion
            end_time = datetime.now()
            duration = int((end_time - start_time).total_seconds())
            
            self.conn.execute('''
                UPDATE task_history 
                SET end_time = ?, duration = ?, status = ?
                WHERE agent_id = ? AND repo_name = ? AND task_id = ? AND start_time = ?
            ''', (end_time, duration, execution_result['status'], self.config.agent_id, self.config.repo_name, task_id, start_time))
            self.conn.commit()
            
            self.logger.info(f"Completed task #{task_id} in {duration}s with status: {execution_result['status']}")
            
            return execution_result
            
        except Exception as e:
            self.logger.error(f"Error executing task #{task_id}: {e}")
            
            # Record error
            end_time = datetime.now()
            duration = int((end_time - start_time).total_seconds())
            
            self.conn.execute('''
                UPDATE task_history 
                SET end_time = ?, duration = ?, status = ?, error_message = ?
                WHERE agent_id = ? AND repo_name = ? AND task_id = ? AND start_time = ?
            ''', (end_time, duration, 'ERROR', str(e), self.config.agent_id, self.config.repo_name, task_id, start_time))
            self.conn.commit()
            
            return {'status': 'ERROR', 'error': str(e)}
    
    def assign_task_to_agent(self, task_id: str):
        """Assign GitHub issue to the agent"""
        try:
            cmd = f'gh issue edit {task_id} --repo {self.repo_full_name} --add-assignee {self.config.agent_id}'
            subprocess.run(cmd, shell=True, check=True)
            self.logger.info(f"Assigned task #{task_id} to {self.config.agent_id}")
        except subprocess.CalledProcessError as e:
            self.logger.warning(f"Failed to assign task #{task_id}: {e}")
    
    def create_autonomous_session(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """Create Claude Code session with autonomous instructions"""
        task_id = str(task['number'])
        task_title = task.get('title', 'Unknown Task')
        
        # Generate autonomous instruction
        instruction = self.generate_autonomous_instruction(task)
        
        # Create session file
        session_file = Path(f"/tmp/agent-{self.config.agent_id}-{self.config.repo_name}-session-{task_id}.md")
        with open(session_file, 'w') as f:
            f.write(instruction)
            
        self.logger.info(f"Created autonomous session for task #{task_id}")
        return {'status': 'SESSION_CREATED', 'session_file': str(session_file)}
    
    def generate_autonomous_instruction(self, task: Dict[str, Any]) -> str:
        """Generate autonomous instruction for the task"""
        task_id = str(task['number'])
        task_title = task.get('title', 'Unknown Task')
        
        instruction = f"""# Agent {self.config.agent_id} Autonomous Task Execution

## Task Information
- **Repository**: {self.repo_full_name}
- **Issue**: #{task_id}
- **Title**: {task_title}
- **Agent**: {self.config.agent_id} ({self.config.specialization})
- **Model**: {self.config.sonnet_model}

## Setup Instructions
```bash
# Use claude-code-cluster for Sonnet system
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster
./start-agent-sonnet.sh {self.config.agent_id}

# Navigate to target repository
cd /path/to/{self.config.repo_name}
```

## Autonomous Execution Protocol
1. **Issue Analysis** (5 min): Read issue #{task_id} details thoroughly
2. **Implementation Planning** (10 min): Create detailed implementation plan
3. **TDD Implementation** (20 min): Implement with test-driven approach
4. **Quality Assurance** (10 min): Run tests, lint, security checks
5. **Progress Reporting** (5 min): Update GitHub issue with progress
6. **Task Completion** (5 min): Mark as complete or escalate if blocked

## Success Criteria
- Task completed within {self.config.max_task_duration // 60} minutes
- All tests passing
- Code quality standards met
- Progress reported in GitHub issue

## Escalation Triggers
- Time limit exceeded ({self.config.max_task_duration // 60} minutes)
- Complex architectural decisions needed
- Security-critical changes required
- Multi-component integration issues

## Auto-Commands
```bash
# Check task status
gh issue view {task_id} --repo {self.repo_full_name}

# Update progress
gh issue comment {task_id} --repo {self.repo_full_name} --body "🤖 Agent {self.config.agent_id} Progress: [Status]"

# Quality checks (adapt to repository)
make test && make lint && make typecheck

# Escalation (if needed)
escalate "Complex issue description" "Current context" "Attempted solutions"
```

## Repository-Specific Notes
- **Repository**: {self.repo_full_name}
- **Specialization**: {self.config.specialization}
- **Priority Keywords**: {', '.join(self.config.priority_keywords)}

## Expected Output
- Implementation completed
- Tests passing
- Quality metrics achieved
- Progress documented in GitHub

## Next Action
Start with: `gh issue view {task_id} --repo {self.repo_full_name}`

---
🤖 Autonomous Agent {self.config.agent_id} - Auto-Generated Task Execution for {self.repo_full_name}
"""
        return instruction
    
    def monitor_task_execution(self, task_id: str, start_time: datetime) -> Dict[str, Any]:
        """Monitor task execution and determine completion status"""
        max_duration = self.config.max_task_duration
        check_interval = 60  # Check every minute
        
        while True:
            current_time = datetime.now()
            elapsed = (current_time - start_time).total_seconds()
            
            if elapsed > max_duration:
                self.logger.warning(f"Task #{task_id} exceeded time limit ({max_duration}s)")
                return {'status': 'TIMEOUT', 'duration': elapsed}
            
            # Check if task is completed (issue closed or specific labels)
            completion_status = self.check_task_completion(task_id)
            if completion_status['completed']:
                return {'status': 'COMPLETED', 'duration': elapsed, 'result': completion_status}
            
            # Check for escalation signals
            if self.check_escalation_needed(task_id):
                return {'status': 'ESCALATED', 'duration': elapsed}
            
            time.sleep(check_interval)
    
    def check_task_completion(self, task_id: str) -> Dict[str, Any]:
        """Check if task is completed"""
        try:
            cmd = f'gh issue view {task_id} --repo {self.repo_full_name} --json state,labels,comments'
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                issue_data = json.loads(result.stdout)
                
                # Check if issue is closed
                if issue_data.get('state') == 'CLOSED':
                    return {'completed': True, 'reason': 'CLOSED'}
                
                # Check for completion labels
                labels = [label.get('name', '') for label in issue_data.get('labels', [])]
                if 'completed' in labels or 'done' in labels:
                    return {'completed': True, 'reason': 'LABELED_COMPLETE'}
                
                # Check for recent agent progress comments
                comments = issue_data.get('comments', [])
                recent_comments = [c for c in comments if self.config.agent_id in c.get('body', '')]
                if recent_comments:
                    latest_comment = recent_comments[-1].get('body', '')
                    if 'completed' in latest_comment.lower() or 'done' in latest_comment.lower():
                        return {'completed': True, 'reason': 'AGENT_REPORTED_COMPLETE'}
                
                return {'completed': False}
            
            return {'completed': False}
            
        except Exception as e:
            self.logger.error(f"Error checking task completion: {e}")
            return {'completed': False}
    
    def check_escalation_needed(self, task_id: str) -> bool:
        """Check if task needs escalation"""
        try:
            cmd = f'gh issue view {task_id} --repo {self.repo_full_name} --json comments'
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                issue_data = json.loads(result.stdout)
                comments = issue_data.get('comments', [])
                
                # Check for escalation keywords in recent comments
                escalation_keywords = ['escalate', 'complex', 'blocked', 'help needed', 'manager']
                for comment in comments[-3:]:  # Check last 3 comments
                    body = comment.get('body', '').lower()
                    if any(keyword in body for keyword in escalation_keywords):
                        return True
                        
            return False
            
        except Exception as e:
            self.logger.error(f"Error checking escalation: {e}")
            return False
    
    def update_agent_metrics(self, task_result: Dict[str, Any]):
        """Update agent performance metrics"""
        today = datetime.now().strftime('%Y-%m-%d')
        
        # Get or create today's metrics
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT * FROM agent_metrics 
            WHERE agent_id = ? AND repo_name = ? AND date = ?
        ''', (self.config.agent_id, self.config.repo_name, today))
        
        existing = cursor.fetchone()
        
        if existing:
            # Update existing metrics
            if task_result['status'] == 'COMPLETED':
                self.conn.execute('''
                    UPDATE agent_metrics 
                    SET tasks_completed = tasks_completed + 1
                    WHERE agent_id = ? AND repo_name = ? AND date = ?
                ''', (self.config.agent_id, self.config.repo_name, today))
            else:
                self.conn.execute('''
                    UPDATE agent_metrics 
                    SET tasks_failed = tasks_failed + 1
                    WHERE agent_id = ? AND repo_name = ? AND date = ?
                ''', (self.config.agent_id, self.config.repo_name, today))
        else:
            # Create new metrics
            completed = 1 if task_result['status'] == 'COMPLETED' else 0
            failed = 1 if task_result['status'] != 'COMPLETED' else 0
            
            self.conn.execute('''
                INSERT INTO agent_metrics (agent_id, repo_name, date, tasks_completed, tasks_failed)
                VALUES (?, ?, ?, ?, ?)
            ''', (self.config.agent_id, self.config.repo_name, today, completed, failed))
        
        self.conn.commit()
    
    def run_autonomous_loop(self, max_iterations: Optional[int] = None):
        """Main autonomous execution loop"""
        self.logger.info(f"Starting autonomous loop for Agent {self.config.agent_id} on {self.repo_full_name}")
        
        iteration = 0
        while max_iterations is None or iteration < max_iterations:
            try:
                self.logger.info(f"Loop iteration {iteration + 1}")
                
                # Fetch available tasks
                tasks = self.fetch_available_tasks()
                
                if not tasks:
                    self.logger.info("No tasks available, waiting...")
                    time.sleep(self.config.cooldown_time)
                    continue
                
                # Select the highest priority eligible task
                selected_task = None
                for task in tasks:
                    if self.check_task_eligibility(task):
                        selected_task = task
                        break
                
                if not selected_task:
                    self.logger.info("No eligible tasks found, waiting...")
                    time.sleep(self.config.cooldown_time)
                    continue
                
                # Execute the selected task
                self.logger.info(f"Executing task #{selected_task['number']}: {selected_task['title']}")
                task_result = self.execute_task(selected_task)
                
                # Update metrics
                self.update_agent_metrics(task_result)
                
                # Cooldown between tasks
                time.sleep(self.config.cooldown_time)
                
                iteration += 1
                
            except KeyboardInterrupt:
                self.logger.info("Received interrupt signal, shutting down...")
                break
            except Exception as e:
                self.logger.error(f"Error in main loop: {e}")
                time.sleep(self.config.cooldown_time)
        
        self.logger.info(f"Autonomous loop completed after {iteration} iterations")
    
    def __del__(self):
        """Cleanup resources"""
        if hasattr(self, 'conn'):
            self.conn.close()

def create_agent_config(agent_id: str, repo_owner: str, repo_name: str, **kwargs) -> AgentConfig:
    """Create agent configuration for any repository"""
    
    # Default configurations for common agent types
    default_configs = {
        'CC01': {
            'specialization': 'Backend Specialist',
            'labels': ['claude-code-task', 'backend', 'cc01'],
            'priority_keywords': ['backend', 'api', 'database', 'python', 'fastapi', 'server']
        },
        'CC02': {
            'specialization': 'Database Specialist',
            'labels': ['claude-code-task', 'database', 'cc02'],
            'priority_keywords': ['database', 'sql', 'performance', 'migration', 'query', 'data']
        },
        'CC03': {
            'specialization': 'Frontend Specialist',
            'labels': ['claude-code-task', 'frontend', 'cc03'],
            'priority_keywords': ['frontend', 'ui', 'react', 'typescript', 'css', 'client']
        },
        'CC04': {
            'specialization': 'DevOps Specialist',
            'labels': ['claude-code-task', 'devops', 'cc04'],
            'priority_keywords': ['devops', 'ci', 'cd', 'docker', 'kubernetes', 'deployment']
        },
        'CC05': {
            'specialization': 'Security Specialist',
            'labels': ['claude-code-task', 'security', 'cc05'],
            'priority_keywords': ['security', 'auth', 'vulnerability', 'encryption', 'audit']
        }
    }
    
    base_config = default_configs.get(agent_id, {
        'specialization': 'General Specialist',
        'labels': ['claude-code-task'],
        'priority_keywords': ['bug', 'feature', 'improvement']
    })
    
    # Override with provided kwargs
    config_params = {**base_config, **kwargs}
    
    return AgentConfig(
        agent_id=agent_id,
        repo_owner=repo_owner,
        repo_name=repo_name,
        **config_params
    )

def main():
    """Main entry point for universal agent system"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Universal Agent Auto-Loop Hook System')
    parser.add_argument('agent_id', help='Agent ID (e.g., CC01, CC02, CC03)')
    parser.add_argument('repo_owner', help='GitHub repository owner')
    parser.add_argument('repo_name', help='GitHub repository name')
    parser.add_argument('--max-iterations', type=int, help='Maximum iterations (default: unlimited)')
    parser.add_argument('--cooldown', type=int, default=60, help='Cooldown time between tasks (seconds)')
    parser.add_argument('--specialization', help='Agent specialization')
    parser.add_argument('--labels', nargs='+', help='GitHub labels to monitor')
    parser.add_argument('--keywords', nargs='+', help='Priority keywords')
    
    args = parser.parse_args()
    
    # Create configuration
    config_kwargs = {}
    if args.specialization:
        config_kwargs['specialization'] = args.specialization
    if args.labels:
        config_kwargs['labels'] = args.labels
    if args.keywords:
        config_kwargs['priority_keywords'] = args.keywords
    if args.cooldown:
        config_kwargs['cooldown_time'] = args.cooldown
    
    config = create_agent_config(args.agent_id, args.repo_owner, args.repo_name, **config_kwargs)
    hook = AgentAutoLoopHook(config)
    
    try:
        hook.run_autonomous_loop(max_iterations=args.max_iterations)
    except KeyboardInterrupt:
        print(f"\nAgent {args.agent_id} shutting down gracefully...")
    except Exception as e:
        print(f"Fatal error in Agent {args.agent_id}: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
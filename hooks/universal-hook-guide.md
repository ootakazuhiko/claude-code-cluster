# Universal Agent Auto-Loop Hook System

## Overview

This is a universal version of the Agent Auto-Loop Hook System that can work with any GitHub repository. It extends the original ITDO_ERP2-specific system to be completely repository-agnostic.

## Key Features

### Universal Repository Support
- Works with any GitHub repository
- Repository-specific configuration
- Flexible agent specialization

### Multi-Agent Support
- Predefined agent types: CC01-CC05
- Custom agent configurations
- Extensible agent framework

### Repository-Agnostic Design
- Dynamic repository targeting
- Flexible label and keyword systems
- Adaptable quality checks

## Usage

### Basic Usage
```bash
# For ITDO_ERP2 project
python3 agent-auto-loop.py CC01 itdojp ITDO_ERP2

# For any other repository
python3 agent-auto-loop.py CC01 owner repo-name

# With custom configuration
python3 agent-auto-loop.py CC01 owner repo-name \
  --specialization "Custom Specialist" \
  --labels "custom-label" "agent-task" \
  --keywords "custom" "keyword" \
  --cooldown 30
```

### Advanced Usage
```bash
# DevOps specialist for kubernetes project
python3 agent-auto-loop.py CC04 kubernetes kubernetes \
  --labels "kind/feature" "area/kubelet" \
  --keywords "deployment" "container" "cluster"

# Security specialist for security project
python3 agent-auto-loop.py CC05 OWASP owasp-top-ten \
  --labels "security" "vulnerability" \
  --keywords "auth" "encryption" "audit"
```

## Agent Types

### CC01 - Backend Specialist
- **Specialization**: Backend development
- **Labels**: `claude-code-task`, `backend`, `cc01`
- **Keywords**: backend, api, database, python, fastapi, server

### CC02 - Database Specialist
- **Specialization**: Database optimization
- **Labels**: `claude-code-task`, `database`, `cc02`
- **Keywords**: database, sql, performance, migration, query, data

### CC03 - Frontend Specialist
- **Specialization**: Frontend development
- **Labels**: `claude-code-task`, `frontend`, `cc03`
- **Keywords**: frontend, ui, react, typescript, css, client

### CC04 - DevOps Specialist
- **Specialization**: DevOps and infrastructure
- **Labels**: `claude-code-task`, `devops`, `cc04`
- **Keywords**: devops, ci, cd, docker, kubernetes, deployment

### CC05 - Security Specialist
- **Specialization**: Security and auditing
- **Labels**: `claude-code-task`, `security`, `cc05`
- **Keywords**: security, auth, vulnerability, encryption, audit

## Configuration

### AgentConfig Parameters
```python
@dataclass
class AgentConfig:
    agent_id: str              # Agent identifier
    repo_owner: str           # GitHub repository owner
    repo_name: str            # GitHub repository name
    specialization: str       # Agent specialization
    labels: List[str]         # GitHub labels to monitor
    priority_keywords: List[str]  # Priority keywords for scoring
    max_task_duration: int = 1800    # 30 minutes
    cooldown_time: int = 60          # 1 minute
    sonnet_model: str = "claude-3-5-sonnet-20241022"
```

### Custom Agent Creation
```python
from agent_auto_loop import create_agent_config, AgentAutoLoopHook

# Create custom agent
config = create_agent_config(
    agent_id="CUSTOM01",
    repo_owner="myorg",
    repo_name="myrepo",
    specialization="Custom Specialist",
    labels=["custom-task", "my-label"],
    priority_keywords=["custom", "specific", "keywords"],
    cooldown_time=30
)

hook = AgentAutoLoopHook(config)
hook.run_autonomous_loop()
```

## Database Schema

### Universal Schema
The system creates repository-specific databases with the following schema:

```sql
-- Task execution history
CREATE TABLE task_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_id TEXT NOT NULL,
    repo_name TEXT NOT NULL,        -- Repository-specific
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
);

-- Performance metrics
CREATE TABLE agent_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_id TEXT NOT NULL,
    repo_name TEXT NOT NULL,        -- Repository-specific
    date TEXT NOT NULL,
    tasks_completed INTEGER DEFAULT 0,
    tasks_failed INTEGER DEFAULT 0,
    avg_duration REAL DEFAULT 0,
    escalations INTEGER DEFAULT 0,
    autonomous_rate REAL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## File Structure

```
/tmp/agent-{AGENT_ID}-{REPO_NAME}-loop.db      # Database
/tmp/agent-{AGENT_ID}-{REPO_NAME}-loop.log     # Logs
/tmp/agent-{AGENT_ID}-{REPO_NAME}-session-{TASK_ID}.md  # Session files
```

## Integration Examples

### GitHub Actions Integration
```yaml
name: Agent Auto-Loop
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

jobs:
  agent-loop:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Start Agent
        run: |
          python3 hooks/agent-auto-loop.py CC01 ${{ github.repository_owner }} ${{ github.event.repository.name }} --max-iterations 5
```

### Docker Integration
```dockerfile
FROM python:3.11-slim

COPY hooks/agent-auto-loop.py /app/
WORKDIR /app

RUN pip install requests

CMD ["python3", "agent-auto-loop.py", "CC01", "$REPO_OWNER", "$REPO_NAME"]
```

## Migration from ITDO_ERP2 System

### Update Existing Commands
```bash
# Old ITDO_ERP2 specific
python3 agent-auto-loop.py CC01

# New universal
python3 agent-auto-loop.py CC01 itdojp ITDO_ERP2
```

### Configuration Migration
```bash
# Create wrapper script for backward compatibility
#!/bin/bash
python3 /path/to/universal/agent-auto-loop.py "$1" itdojp ITDO_ERP2 "${@:2}"
```

## Best Practices

### Repository Setup
1. Create appropriate labels for your repository
2. Configure GitHub CLI authentication
3. Set up proper permissions for the agent user
4. Test with limited iterations first

### Agent Configuration
1. Choose appropriate specialization
2. Configure relevant labels and keywords
3. Set appropriate cooldown times
4. Monitor database growth

### Monitoring
1. Check logs regularly
2. Monitor database metrics
3. Track success/failure rates
4. Adjust configuration based on performance

## Troubleshooting

### Common Issues

#### Repository Access
```bash
# Check authentication
gh auth status

# Test repository access
gh repo view owner/repo-name
```

#### Database Issues
```bash
# Check database size
ls -la /tmp/agent-*-loop.db

# View recent entries
sqlite3 /tmp/agent-CC01-myrepo-loop.db "SELECT * FROM task_history ORDER BY start_time DESC LIMIT 10;"
```

#### Performance Issues
```bash
# Monitor resource usage
top -p $(pgrep -f agent-auto-loop)

# Check cooldown settings
python3 agent-auto-loop.py CC01 owner repo --cooldown 120
```

---

**Status**: ✅ Production Ready
**Compatibility**: All GitHub repositories
**Integration**: Claude Code Hook System

🤖 Universal Agent Auto-Loop Hook System for Claude Code
# Claude Code Cluster PoC

A Proof of Concept implementation of a distributed Claude Code execution system with specialized agents.

## Features

### Core Features
- ✅ **GitHub Issue to PR Automation**: Automatically convert GitHub issues into pull requests
- ✅ **Webhook Support**: Real-time processing of GitHub events
- ✅ **Multiple Specialized Agents**: Backend, Frontend, Testing, and DevOps agents
- ✅ **Distributed Processing**: Multi-machine cluster support with load balancing

### Specialized Agents
1. **Backend Agent**: Python/FastAPI, databases, APIs, authentication
2. **Frontend Agent**: React/TypeScript, UI components, styling
3. **Testing Agent**: pytest/Jest, unit/integration tests, QA
4. **DevOps Agent**: Docker, CI/CD, infrastructure, monitoring

### Distributed Architecture
- **Cluster Coordinator**: Central task orchestration and node management
- **Agent Nodes**: Distributed workers with specialized capabilities
- **Load Balancing**: Automatic task assignment based on specialties and load
- **Fault Tolerance**: Node failure detection and task reassignment

## Quick Start

## ⚠️ 重要な設計変更

**このPoCはClaude Code CLIを使用した分散実行システムに変更されました。**

📚 **必読ドキュメント**: 
- 🔄 [REVISED_CONCEPT.md](../REVISED_CONCEPT.md) - **設計変更の詳細**
- 🏗️ [ARCHITECTURE.md](../ARCHITECTURE.md) - **新アーキテクチャ**
- 🔧 [CLAUDE_CODE_INTEGRATION.md](CLAUDE_CODE_INTEGRATION.md) - **Claude Code CLI統合**

📖 **使用ガイド**:
- 📋 [POC_USAGE_GUIDE.md](POC_USAGE_GUIDE.md) - **完全な使用ガイド（5台PC構成）**
- 🧪 [SIMULATOR_GUIDE.md](SIMULATOR_GUIDE.md) - **シミュレーター実行ガイド（単一PC）**
- 🎮 [CLAUDE_CODE_SIMULATOR.py](CLAUDE_CODE_SIMULATOR.py) - **動作確認用シミュレーター**
- 📚 [QUICKSTART.md](QUICKSTART.md) | [USAGE.md](USAGE.md) | [DEPLOYMENT.md](DEPLOYMENT.md) | [EXAMPLES.md](EXAMPLES.md)

### 1. Setup Environment

```bash
# Clone and setup
cd claude-code-cluster-poc
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -e .

# Configure environment
cp .env.example .env
# Edit .env with your GitHub token and Anthropic API key
```

### 2. Local Mode (Single Machine)

```bash
# Setup
claude-cluster setup

# Create and run task
claude-cluster workflow --issue 123 --repo owner/repo

# Check status
claude-cluster status
```

### 3. Distributed Mode

#### Start Cluster Coordinator
```bash
claude-cluster-distributed start-coordinator --port 8001
```

#### Start Agent Nodes
```bash
# Backend agent
claude-cluster-distributed start-node --specialties backend,api,database --agent-port 8002

# Frontend agent  
claude-cluster-distributed start-node --specialties frontend,react,ui --agent-port 8003

# Testing agent
claude-cluster-distributed start-node --specialties testing,qa,pytest --agent-port 8004

# DevOps agent
claude-cluster-distributed start-node --specialties devops,docker,ci --agent-port 8005
```

#### Submit Tasks
```bash
# Create and run distributed task
claude-cluster-distributed workflow --issue 123 --repo owner/repo --distributed

# Check cluster status
claude-cluster-distributed status --show-cluster
```

### 4. Docker Deployment

```bash
# Start full cluster
docker-compose up

# Check cluster status
curl http://localhost:8001/api/cluster/status

# Submit task via API
curl -X POST http://localhost:8001/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"task_id": "task-123", "priority": "high", "requirements": ["backend"]}'
```

## Architecture

### Local Mode
```
GitHub Issue → Agent → Specialized Agent Selection → Claude API → Implementation → PR
```

### Distributed Mode
```
GitHub Issue → Coordinator → Task Queue → Agent Node Selection → Specialized Agent → Implementation → PR
```

### Components

#### Core Services
- **Agent**: Main orchestration logic
- **State Manager**: Task persistence and state tracking
- **GitHub Client**: Issue fetching and PR creation
- **Claude Client**: AI-powered implementation generation

#### Distributed Services
- **Cluster Coordinator**: Central coordination and load balancing
- **Agent Node**: Distributed worker with specialized capabilities
- **Coordinator API**: RESTful API for cluster management
- **Webhook Server**: GitHub webhook processing

#### Specialized Agents
- **Base Agent**: Abstract agent interface
- **Backend Agent**: Python/API development (Sonnet model)
- **Frontend Agent**: React/UI development (Haiku model)
- **Testing Agent**: Test automation (Sonnet model)
- **DevOps Agent**: Infrastructure/deployment (Sonnet model)

## Configuration

### Environment Variables
```bash
GITHUB_TOKEN=ghp_your_token_here
ANTHROPIC_API_KEY=sk-ant-your_key_here
```

### Agent Specialties
- `backend`: Python, FastAPI, databases, APIs
- `frontend`: React, TypeScript, UI, styling
- `testing`: pytest, Jest, QA, bug fixes
- `devops`: Docker, CI/CD, infrastructure
- `general`: Fallback for unspecialized tasks

## API Reference

### Coordinator API
- `GET /api/cluster/status` - Cluster overview
- `POST /api/nodes/register` - Register agent node
- `POST /api/tasks` - Submit task
- `GET /api/tasks/{task_id}` - Task status

### Agent Node API
- `GET /health` - Node health check
- `POST /api/tasks/{task_id}/assign` - Accept task assignment
- `GET /api/node/info` - Node information

### Webhook API
- `POST /webhook/github` - GitHub webhook endpoint

## Commands

### Local Commands
```bash
claude-cluster setup           # Environment setup
claude-cluster create-task     # Create task from issue
claude-cluster run-task        # Run specific task
claude-cluster workflow        # Complete workflow
claude-cluster status          # Show task status
claude-cluster agents          # List specialized agents
```

### Distributed Commands
```bash
claude-cluster-distributed start-coordinator  # Start coordinator
claude-cluster-distributed start-node         # Start agent node
claude-cluster-distributed create-task        # Create distributed task
claude-cluster-distributed run-task           # Run with distribution
claude-cluster-distributed workflow           # Distributed workflow
claude-cluster-distributed status             # Cluster status
```

## Development

### Running Tests
```bash
uv pip install -e ".[dev]"
pytest
```

### Code Quality
```bash
black src/
isort src/
flake8 src/
mypy src/
```

### Adding New Specialized Agents
1. Create agent class inheriting from `BaseSpecializedAgent`
2. Implement required abstract methods
3. Add to `DistributedAgent.specialized_agents`
4. Update documentation

## Deployment

### Docker Compose
- Coordinator: Port 8001
- Backend Agent: Port 8002  
- Frontend Agent: Port 8003
- Testing Agent: Port 8004
- DevOps Agent: Port 8005
- Webhook Server: Port 8000

### Scaling
```bash
# Scale agent nodes
docker-compose up --scale agent-backend=3 --scale agent-frontend=2

# Add new agent types
docker-compose -f docker-compose.yml -f docker-compose.scale.yml up
```

## Monitoring

### Health Checks
```bash
# Coordinator health
curl http://localhost:8001/health

# Agent node health
curl http://localhost:8002/health
```

### Logs
```bash
# Docker logs
docker-compose logs -f coordinator
docker-compose logs -f agent-backend

# Local logs
tail -f logs/cluster.log
```

## Troubleshooting

### Common Issues
1. **Node Registration Failed**: Check coordinator connectivity
2. **Task Assignment Failed**: Verify agent capacity and specialties
3. **Implementation Failed**: Check Claude API key and rate limits
4. **PR Creation Failed**: Verify GitHub token permissions

### Debug Mode
```bash
# Enable debug logging
export LOG_LEVEL=DEBUG
claude-cluster-distributed status --show-cluster
```

## Contributing

1. Fork the repository
2. Create feature branch
3. Implement changes with tests
4. Submit pull request

## License

MIT License - see LICENSE file for details.

---

**Note**: This is a Proof of Concept implementation. For production use, additional error handling, security measures, and scalability considerations would be needed.
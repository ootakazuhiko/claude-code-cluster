# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code Cluster is a distributed system for running multiple Claude Code agents on independent PCs to automate collaborative development centered around GitHub. This is a **documentation project** that defines the architecture, implementation specifications, and deployment procedures for a hypothetical distributed Claude Code execution environment.

## Architecture

### System Design
- **Central Coordinator**: Main coordination system running on a dedicated PC
- **Claude Code Agents**: Specialized agents (backend, frontend, testing, devops) running on independent PCs  
- **GitHub Integration**: Issue-driven development workflow with automatic PR creation
- **Distributed Workspaces**: Each agent maintains completely independent development environments

### Key Components

1. **Central Coordinator** (`coordinator/` - not implemented)
   - FastAPI-based task scheduling and agent management system
   - PostgreSQL database for task tracking and agent state
   - Redis for caching and real-time communication
   - GitHub webhook handling for issue-driven development

2. **Claude Code Agents** (`agent/` - not implemented)
   - Python-based agents with Claude API integration
   - Specialized by domain (backend, frontend, testing, etc.)
   - Independent workspace management and Git operations
   - Task execution with automated testing and PR creation

3. **GitHub Integration**
   - Webhook-based issue processing
   - Automatic task creation from GitHub issues
   - PR generation with test results and code review

4. **Deployment System**
   - Ansible-based automated deployment
   - Docker containerization for coordinator services
   - Multi-PC configuration management

## Development Commands

Since this is a documentation project, there are no build commands. The repository contains:

- Markdown documentation files
- Configuration examples
- Architecture diagrams (in Mermaid format)
- Implementation specifications

### Key Scripts
- `examples/scripts/setup-development.sh` - Development environment setup script
- `examples/scripts/deploy-cluster.sh` - Deployment automation script (referenced)
- `examples/scripts/health-check.sh` - System health monitoring script (referenced)

## Documentation Structure

### Architecture Documentation
- `architecture/overview.md` - System architecture and design patterns
- `implementation/coordinator.md` - Central coordinator implementation details
- `implementation/agent.md` - Agent implementation specifications
- `implementation/github-integration.md` - GitHub integration patterns

### Deployment Documentation  
- `deployment/automation.md` - Ansible-based deployment procedures
- `docs/requirements.md` - Hardware and software requirements
- `examples/configurations/` - Configuration file examples

### Development Setup
- `examples/scripts/setup-development.sh` - Single-machine development setup
- `examples/configurations/` - Agent and coordinator configuration examples

## Configuration Files

### Agent Configuration (Example)
```bash
# Agent environment variables
AGENT_ID=dev-agent-backend
AGENT_SPECIALTY=backend
COORDINATOR_URL=http://127.0.0.1:8080
ANTHROPIC_API_KEY=sk-ant-YOUR_KEY_HERE
GITHUB_TOKEN=ghp_YOUR_TOKEN_HERE
```

### Coordinator Configuration (Example)
```bash
# Coordinator environment variables
DATABASE_URL=postgresql://coordinator:password@localhost:5432/coordinator_dev
REDIS_URL=redis://localhost:6379/0
GITHUB_TOKEN=ghp_YOUR_TOKEN_HERE
ANTHROPIC_API_KEY=sk-ant-YOUR_KEY_HERE
```

## System Requirements

### Minimum Configuration
- **Coordinator**: 4 cores, 16GB RAM, 500GB SSD
- **Agents**: 4 cores, 16GB RAM, 500GB SSD each
- **Network**: Gigabit Ethernet between systems
- **Software**: Ubuntu 22.04 LTS, Python 3.11+, Docker 24.0+

### Recommended Configuration
- **Coordinator**: 8 cores, 32GB RAM, 1TB NVMe SSD
- **Agents**: 8 cores, 32GB RAM, 1TB NVMe SSD each
- **Total System**: 5 PCs (1 coordinator + 4 agents)

## Technology Stack

### Core Technologies
- **Language**: Python 3.11+, TypeScript
- **Framework**: FastAPI (coordinator), React (frontend agents)
- **Database**: PostgreSQL, Redis
- **Container**: Docker, Docker Compose
- **Monitoring**: Prometheus, Grafana
- **Automation**: Ansible, systemd

### Development Tools
- **Python**: uv (package manager), PyEnv
- **Node.js**: npm/yarn, nvm
- **Git**: Automated branch management and PR creation
- **Testing**: pytest, Jest, Selenium

## Agent Specialties

### Backend Specialist
- **Focus**: Server-side development, APIs, databases
- **Skills**: Python, FastAPI, PostgreSQL, Redis
- **Responsibilities**: API implementation, database operations, server logic

### Frontend Specialist
- **Focus**: Client-side development, UI/UX
- **Skills**: TypeScript, React, CSS, JavaScript
- **Responsibilities**: Component development, UI implementation, user interfaces

### Testing Specialist
- **Focus**: Quality assurance, automated testing
- **Skills**: pytest, Jest, Selenium, QA methodologies
- **Responsibilities**: Test implementation, quality validation, bug detection

### DevOps Specialist
- **Focus**: Infrastructure, CI/CD, deployment
- **Skills**: Docker, Ansible, GitHub Actions, infrastructure
- **Responsibilities**: Deployment automation, monitoring, infrastructure management

## Workflow

### Issue-Driven Development
1. GitHub issue created → Webhook triggers coordinator
2. Coordinator analyzes issue → Creates task with requirements
3. Task assigned to optimal agent based on specialization
4. Agent clones repository → Analyzes codebase → Generates implementation
5. Agent runs tests → Creates branch → Submits PR
6. PR reviewed and merged → Issue automatically closed

### Task Execution Flow
- **Workspace Preparation**: Agent creates isolated workspace
- **Code Analysis**: Understanding existing codebase structure
- **Implementation**: Claude API-generated code changes
- **Testing**: Automated test execution and validation
- **Git Operations**: Branch creation, commits, PR submission

## Monitoring and Observability

### Metrics Collection
- Task execution times and success rates
- Agent performance and utilization
- GitHub API usage and rate limits
- System resource utilization

### Alerting
- Agent offline/failure detection
- Task timeout and error handling
- Resource exhaustion warnings
- GitHub integration issues

## Security Considerations

- SSH key-based authentication between systems
- API key management and rotation
- Network segmentation and firewalls
- Workspace isolation and cleanup
- GitHub webhook signature verification

## Important Notes

This is a **documentation and specification project**. The actual implementation does not exist - this repository contains detailed architectural documentation, implementation specifications, and deployment procedures for a hypothetical distributed Claude Code system.

The documentation is comprehensive and includes:
- Complete system architecture
- Detailed implementation specifications
- Deployment automation procedures
- Configuration examples
- Monitoring and security guidelines

All code examples and configurations are for specification purposes and would need to be implemented according to these documented requirements.
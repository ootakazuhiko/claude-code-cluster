# Claude Code Agent Log Analysis Scripts

These scripts help analyze Claude Code agent activity across multiple Ubuntu instances.

## Quick Start

See [LOG_COLLECTION_GUIDE.md](LOG_COLLECTION_GUIDE.md) for detailed instructions.

## Scripts

### 1. agent-log-collector.sh
Collects logs from agent's Ubuntu instance and pushes to GitHub.

**Usage:**
```bash
export AGENT_NAME=CC01  # or CC02, CC03
./agent-log-collector.sh
```

### 2. analyze-agent-logs.sh
Analyzes collected logs from GitHub repository.

**Usage:**
```bash
# After logs are collected and pushed to GitHub
./analyze-agent-logs.sh
```

## Workflow

1. Run `agent-log-collector.sh` on each agent machine
2. Logs are pushed to `logs/{AGENT_NAME}/YYYYMMDD` branches
3. Run `analyze-agent-logs.sh` on central machine to generate report

## Repository

https://github.com/ootakazuhiko/claude-code-cluster
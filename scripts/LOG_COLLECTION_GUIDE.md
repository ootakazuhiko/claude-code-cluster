# Agent Log Collection Guide

This guide explains how to collect logs from Claude Code agents for analysis.

## Overview

The log collection system helps understand actual agent activity when GitHub communication is not working as expected.

## Prerequisites

- Access to each agent's Ubuntu instance
- Git installed on each agent machine
- Write access to the claude-code-cluster repository

## Log Collection Steps

### For Each Agent (CC01, CC02, CC03)

1. **Clone or update the repository**
   ```bash
   # If not already cloned
   git clone https://github.com/ootakazuhiko/claude-code-cluster.git
   cd claude-code-cluster
   
   # If already cloned
   cd claude-code-cluster
   git pull origin main
   ```

2. **Run the log collector**
   ```bash
   # Set your agent name (CC01, CC02, or CC03)
   export AGENT_NAME=CC01
   
   # Make script executable
   chmod +x scripts/agent-log-collector.sh
   
   # Run the collector
   ./scripts/agent-log-collector.sh
   ```

3. **What the script collects**
   - System information (memory, disk, processes)
   - Claude Code session files and logs
   - Shell history (last 1000 commands)
   - Git status and recent commits
   - Recent file modifications
   - Environment variables (filtered for safety)

4. **Output**
   - Logs are pushed to branch: `logs/{AGENT_NAME}/YYYYMMDD`
   - Example: `logs/CC01/20250119`
   - View on GitHub: `https://github.com/ootakazuhiko/claude-code-cluster/tree/logs/CC01/20250119`

## Log Analysis

After collecting logs from all agents:

1. **On the analysis machine**
   ```bash
   cd claude-code-cluster
   git fetch origin
   
   # Check available log branches
   git branch -r | grep logs/
   
   # Run the analyzer
   ./scripts/analyze-agent-logs.sh
   ```

2. **Analysis output**
   - Main report: `/tmp/agent-analysis-{timestamp}/multi_agent_analysis.md`
   - Individual agent analyses
   - Comparative activity report
   - Recommendations

## Troubleshooting

### Script fails to find project directory
- Update line 74 in `agent-log-collector.sh` with correct project path
- Default searches: `~/ITDO_ERP2` and `~/claude-code-cluster`

### Permission denied
```bash
chmod +x scripts/agent-log-collector.sh
```

### Push fails
- Ensure you have write access to the repository
- Check your Git credentials
- Verify network connectivity

## Security Notes

- No passwords or secrets are collected
- Environment variables are filtered
- Only recent activity is collected (last 7 days)
- All data is pushed to a public repository - review before running

## Quick Reference

```bash
# CC01
export AGENT_NAME=CC01 && ./scripts/agent-log-collector.sh

# CC02
export AGENT_NAME=CC02 && ./scripts/agent-log-collector.sh

# CC03
export AGENT_NAME=CC03 && ./scripts/agent-log-collector.sh
```
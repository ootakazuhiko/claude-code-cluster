# Agent Instruction System

This directory contains the improved instruction handling system for Claude Code agents, implementing the proposal from [Issue #31](https://github.com/ootakazuhiko/claude-code-cluster/issues/31).

## Overview

The system provides standardized scripts for:
1. Receiving instructions from GitHub Issues
2. Executing tasks based on instruction type
3. Reporting results back to GitHub
4. Continuous processing with stagnation detection

## Components

### 1. `instruction-handler.sh`
- Fetches new instructions from GitHub Issues
- Prioritizes urgent tasks
- Detects process stagnation
- Returns structured task information

### 2. `task-executor.sh`
- Executes tasks based on type (test, fix, implement)
- Agent-specific implementations
- Creates branches for code changes
- Handles different task types appropriately

### 3. `report-generator.sh`
- Generates success/failure/progress reports
- Submits reports as GitHub Issue comments
- Tracks execution metrics
- Updates issue labels on completion

### 4. `agent-loop.sh`
- Main continuous processing loop
- Orchestrates the other scripts
- Handles interruptions gracefully
- Performs health checks

## Usage

### Starting an Agent

```bash
# Start CC01 (Frontend Agent)
./agent-loop.sh CC01 cc01

# Start CC02 (Backend Agent)
./agent-loop.sh CC02 cc02

# Start CC03 (Infrastructure Agent)
./agent-loop.sh CC03 cc03
```

### Environment Variables

- `LOOP_DELAY`: Seconds between instruction checks (default: 60)
- `MAX_ITERATIONS`: Maximum loop iterations, 0=infinite (default: 0)
- `LOG_FILE`: Path to log file (default: /tmp/agent-loop.log)
- `WORKSPACE`: Project workspace path (default: /home/work/ITDO_ERP2)

### Running in Background

```bash
# Start agent in background with nohup
nohup ./agent-loop.sh CC01 cc01 > cc01.log 2>&1 &

# Or with systemd service (recommended)
# See agent-cc01.service example
```

## Instruction Format

GitHub Issues should follow this format:

### Title
- Include agent identifier: `[CC01]`, `[CC02]`, or `[CC03]`
- Use priority markers: `URGENT`, `PRIORITY`, `P1` for high priority
- Include task type: `test`, `fix`, `implement`

### Body
The issue body should contain:
- Clear task description
- Technical requirements
- Success criteria
- Any specific instructions

### Labels
- Must include agent-specific label: `cc01`, `cc02`, or `cc03`
- Additional labels for categorization

## Features

### Stagnation Detection
- Monitors time since last activity
- Warns if no progress for 30 minutes
- Attempts recovery from stuck states

### Priority Handling
- Processes urgent tasks first
- Looks for priority markers in titles
- Falls back to FIFO if no priorities

### Error Handling
- Comprehensive error reporting
- Graceful failure with detailed logs
- Automatic cleanup of temporary files

### Progress Tracking
- Reports start/progress/completion
- Tracks execution time
- Counts modified files and test results

## Example Workflow

1. **Instruction Reception**
   ```bash
   $ ./instruction-handler.sh
   [2025-07-18 22:00:00] Fetching instructions for CC01 (label: cc01)...
   {"issue": 287, "type": "implement", "title": "Create Loading Component"}
   ```

2. **Task Execution**
   ```bash
   $ ./task-executor.sh '{"issue": 287, "type": "implement"}'
   [2025-07-18 22:00:30] Executing implement task for issue #287
   {"issue": 287, "success": true}
   ```

3. **Report Generation**
   ```bash
   $ ./report-generator.sh '{"issue": 287, "success": true}'
   [2025-07-18 22:01:00] Submitting report for issue #287
   ```

## Monitoring

Check agent status:
```bash
# View logs
tail -f /tmp/agent-loop.log

# Check active issues
cat /tmp/agent_active_issue_CC01

# Monitor GitHub activity
gh issue list --label cc01 --state open
```

## Troubleshooting

### Agent Not Processing Instructions
1. Check GitHub authentication: `gh auth status`
2. Verify label exists on issues
3. Check log files for errors
4. Ensure workspace is accessible

### Stagnation Detected
1. Agent will attempt self-recovery
2. Check for blocking operations
3. Review recent task logs
4. Manually intervene if needed

### Failed Task Execution
1. Check task-specific logs
2. Verify prerequisites (deps, permissions)
3. Review error reports on GitHub
4. Adjust task instructions if needed

## Future Improvements

- [ ] Parallel task processing
- [ ] Advanced priority algorithms
- [ ] Machine learning for task estimation
- [ ] Integration with CI/CD pipelines
- [ ] Real-time monitoring dashboard
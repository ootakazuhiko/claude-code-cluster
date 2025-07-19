# Claude Code Hooks for Agent System

This directory contains hooks that integrate Claude Code with the agent instruction system.

## Hook Files

### on-idle.sh
- **Purpose**: Checks for new tasks when Claude Code is idle
- **Trigger**: Every 60 seconds (configurable) when no active command
- **Function**: 
  - Calls `instruction-handler.sh` to fetch GitHub issues
  - Signals Claude Code about new tasks
  - Saves task info for processing

### post-command.sh
- **Purpose**: Generates reports after command execution
- **Trigger**: After every command execution in Claude Code
- **Function**:
  - Captures command results and exit codes
  - Calls `report-generator.sh` to create GitHub reports
  - Cleans up completed tasks

## Environment Variables

These hooks expect the following environment variables from Claude Code:

- `CLAUDE_CODE_WORKSPACE`: Base workspace directory
- `CLAUDE_CODE_AGENT_NAME`: Agent identifier (CC01, CC02, CC03)
- `CLAUDE_CODE_ISSUE_LABEL`: GitHub label to filter issues
- `CLAUDE_CODE_COMMAND_EXIT_CODE`: Exit code of executed command
- `CLAUDE_CODE_COMMAND_OUTPUT`: Output from command execution
- `CLAUDE_CODE_COMMAND_EXECUTED`: The command that was executed

## Communication Protocol

### Task Discovery (on-idle.sh output)
```json
{
  "action": "new_task",
  "task_info": {
    "issue": 123,
    "type": "implement",
    "title": "Task title"
  },
  "instruction_file": "/path/to/instruction.md"
}
```

### Task Completion (post-command.sh output)
```json
{
  "action": "task_complete",
  "issue": 123,
  "success": true
}
```

### Task Failure (post-command.sh output)
```json
{
  "action": "task_failed",
  "issue": 123,
  "exit_code": 1,
  "retry_available": true
}
```

## Debugging

Check logs at:
- `$WORKSPACE/.agent/logs/claude-code-hook.log` - Hook execution logs
- `$WORKSPACE/.agent/logs/claude-code.log` - Main Claude Code logs

## Testing Hooks Manually

```bash
# Test on-idle hook
export CLAUDE_CODE_WORKSPACE=/home/work/project
export CLAUDE_CODE_AGENT_NAME=CC01
export CLAUDE_CODE_ISSUE_LABEL=cc01
./on-idle.sh

# Test post-command hook
export CLAUDE_CODE_COMMAND_EXIT_CODE=0
export CLAUDE_CODE_COMMAND_EXECUTED="npm test"
./post-command.sh
```
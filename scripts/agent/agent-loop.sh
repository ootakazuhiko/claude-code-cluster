#!/bin/bash
# Agent Continuous Loop Script
# Purpose: Main loop for continuous instruction processing

set -e

# Configuration
AGENT_NAME="${1:-}"
ISSUE_LABEL="${2:-}"
LOOP_DELAY="${LOOP_DELAY:-60}"  # Delay between loops in seconds
MAX_ITERATIONS="${MAX_ITERATIONS:-0}"  # 0 = infinite
LOG_FILE="${LOG_FILE:-$WORKSPACE/.agent/logs/agent-loop.log}"

# Export for child scripts
export AGENT_NAME
export ISSUE_LABEL
export WORKSPACE="/home/work/ITDO_ERP2"

# Script paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTRUCTION_HANDLER="${SCRIPT_DIR}/instruction-handler.sh"
TASK_EXECUTOR="${SCRIPT_DIR}/task-executor.sh"
REPORT_GENERATOR="${SCRIPT_DIR}/report-generator.sh"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$AGENT_NAME] $@" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    if [ -z "$AGENT_NAME" ] || [ -z "$ISSUE_LABEL" ]; then
        echo "Usage: $0 <AGENT_NAME> <ISSUE_LABEL>"
        echo "Example: $0 CC01 cc01"
        exit 1
    fi
    
    # Check if scripts exist
    for script in "$INSTRUCTION_HANDLER" "$TASK_EXECUTOR" "$REPORT_GENERATOR"; do
        if [ ! -x "$script" ]; then
            log "ERROR: Script not found or not executable: $script"
            exit 1
        fi
    done
    
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        log "ERROR: GitHub CLI (gh) is not installed"
        exit 1
    fi
}

# Handle interruption
cleanup() {
    log "Received interrupt signal, cleaning up..."
    
    # Mark any in-progress work
    local active_issue=$(cat $WORKSPACE/.agent/state/active_issue_${AGENT_NAME} 2>/dev/null)
    if [ -n "$active_issue" ]; then
        gh issue comment "$active_issue" --body "## ${AGENT_NAME} Status
        
Agent loop interrupted. Work may be incomplete.
Time: $(date '+%Y-%m-%d %H:%M:%S JST')" 2>/dev/null || true
    fi
    
    rm -f $WORKSPACE/.agent/state/active_issue_${AGENT_NAME}
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Process single instruction
process_instruction() {
    local start_time=$(date +%s)
    
    # Step 1: Get instruction
    log "Fetching instructions..."
    local task_info=$("$INSTRUCTION_HANDLER")
    
    if [ -z "$task_info" ] || [ "$task_info" = "{}" ]; then
        log "No instructions available"
        return 1
    fi
    
    local issue_number=$(echo "$task_info" | jq -r '.issue')
    log "Processing issue #$issue_number"
    
    # Mark as active
    echo "$issue_number" > $WORKSPACE/.agent/state/active_issue_${AGENT_NAME}
    
    # Step 2: Execute task
    log "Executing task..."
    local task_result=$("$TASK_EXECUTOR" "$task_info" 2>&1 | tee $WORKSPACE/.agent/logs/task_output_${issue_number}.log | tail -1)
    
    # Ensure we have valid JSON result
    if ! echo "$task_result" | jq . >/dev/null 2>&1; then
        task_result="{\"issue\": $issue_number, \"success\": false}"
        log "Task execution produced invalid output, marking as failed"
    fi
    
    # Step 3: Generate report
    log "Generating report..."
    "$REPORT_GENERATOR" "$task_result"
    
    # Clean up
    rm -f $WORKSPACE/.agent/state/active_issue_${AGENT_NAME}
    rm -f $WORKSPACE/.agent/instructions/instruction_${issue_number}.md
    rm -f $WORKSPACE/.agent/logs/task_output_${issue_number}.log
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log "Completed processing issue #$issue_number in ${duration}s"
    
    return 0
}

# Check agent health
check_health() {
    # Check if agent can access workspace
    if [ ! -d "$WORKSPACE" ]; then
        log "ERROR: Workspace not found: $WORKSPACE"
        return 1
    fi
    
    # Check git status
    cd "$WORKSPACE"
    if ! git status >/dev/null 2>&1; then
        log "ERROR: Git repository issues in workspace"
        return 1
    fi
    
    # Check for clean working directory
    if ! git diff --quiet 2>/dev/null; then
        log "WARNING: Uncommitted changes in workspace"
        # Optionally stash changes
        git stash push -m "Agent $AGENT_NAME auto-stash $(date +%s)" 2>/dev/null || true
    fi
    
    return 0
}

# Main loop
main_loop() {
    local iteration=0
    
    while true; do
        iteration=$((iteration + 1))
        
        log "Starting iteration $iteration"
        
        # Check health
        if ! check_health; then
            log "Health check failed, waiting before retry..."
            sleep $LOOP_DELAY
            continue
        fi
        
        # Process instruction
        if process_instruction; then
            log "Instruction processed successfully"
        else
            log "No instruction processed, waiting..."
        fi
        
        # Check iteration limit
        if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$iteration" -ge "$MAX_ITERATIONS" ]; then
            log "Reached maximum iterations ($MAX_ITERATIONS), exiting"
            break
        fi
        
        # Wait before next iteration
        log "Waiting ${LOOP_DELAY}s before next check..."
        sleep $LOOP_DELAY
    done
}

# Initialize agent
initialize_agent() {
    log "Initializing $AGENT_NAME with label $ISSUE_LABEL"
    
    # Post startup message
    local startup_issue=$(gh issue list --label "$ISSUE_LABEL" --state open --limit 1 --json number -q '.[0].number')
    if [ -n "$startup_issue" ]; then
        gh issue comment "$startup_issue" --body "## ${AGENT_NAME} Agent Started

Agent loop initialized and ready to process instructions.
- Time: $(date '+%Y-%m-%d %H:%M:%S JST')
- Label: $ISSUE_LABEL
- Loop Delay: ${LOOP_DELAY}s" 2>/dev/null || true
    fi
}

# Main execution
main() {
    check_prerequisites
    
    # Create necessary directories
    mkdir -p "$WORKSPACE/.agent/logs"
    mkdir -p "$WORKSPACE/.agent/state"
    mkdir -p "$WORKSPACE/.agent/instructions"
    
    initialize_agent
    
    log "Starting continuous loop for $AGENT_NAME"
    main_loop
    
    log "Agent loop completed"
}

# Run main function
main "$@"
#!/bin/bash
# Agent Instruction Handler Script
# Purpose: Standardized instruction reception and processing for Claude Code agents

set -e

# Configuration
AGENT_NAME="${AGENT_NAME:-}"
ISSUE_LABEL="${ISSUE_LABEL:-}"
WORKSPACE="${WORKSPACE:-/home/work/ITDO_ERP2}"
LOG_FILE="${LOG_FILE:-$WORKSPACE/.agent/logs/instruction-handler.log}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    if [ -z "$AGENT_NAME" ] || [ -z "$ISSUE_LABEL" ]; then
        log "ERROR: AGENT_NAME and ISSUE_LABEL must be set"
        exit 1
    fi
    
    if ! command -v gh &> /dev/null; then
        log "ERROR: GitHub CLI (gh) is not installed"
        exit 1
    fi
    
    # Check GitHub authentication
    if ! gh auth status &> /dev/null; then
        log "ERROR: Not authenticated with GitHub"
        exit 1
    fi
}

# Fetch new instructions from GitHub
fetch_instructions() {
    log "Fetching instructions for $AGENT_NAME (label: $ISSUE_LABEL)..."
    
    # Get open issues assigned to this agent
    local issues=$(gh issue list \
        --label "$ISSUE_LABEL" \
        --state open \
        --assignee @me \
        --json number,title,body,labels \
        --limit 10)
    
    if [ -z "$issues" ] || [ "$issues" = "[]" ]; then
        log "No new instructions found"
        return 1
    fi
    
    echo "$issues"
}

# Check for priority tasks
get_priority_task() {
    local issues="$1"
    
    # Look for priority indicators
    echo "$issues" | jq -r '.[] | 
        select(.title | test("URGENT|PRIORITY|P1|\\[P1\\]"; "i")) | 
        .number' | head -1
}

# Get next available task
get_next_task() {
    local issues="$1"
    
    # Get first unprocessed issue
    echo "$issues" | jq -r '.[0].number'
}

# Process single instruction
process_instruction() {
    local issue_number="$1"
    
    log "Processing instruction from issue #$issue_number"
    
    # Get issue details
    local issue_details=$(gh issue view "$issue_number" --json title,body,labels)
    local title=$(echo "$issue_details" | jq -r '.title')
    local body=$(echo "$issue_details" | jq -r '.body')
    
    # Extract task type
    local task_type="general"
    if echo "$title" | grep -qi "test"; then
        task_type="test"
    elif echo "$title" | grep -qi "fix"; then
        task_type="fix"
    elif echo "$title" | grep -qi "implement"; then
        task_type="implement"
    fi
    
    # Report start
    report_status "$issue_number" "start" "Beginning work on: $title"
    
    # Save instruction for processing
    echo "$body" > "$WORKSPACE/.agent/instructions/instruction_${issue_number}.md"
    
    # Return task metadata
    echo "{\"issue\": $issue_number, \"type\": \"$task_type\", \"title\": \"$title\"}"
}

# Report status back to GitHub
report_status() {
    local issue_number="$1"
    local status="$2"
    local message="$3"
    
    local comment="## ${AGENT_NAME} Status Report

**Status**: ${status}
**Time**: $(date '+%Y-%m-%d %H:%M:%S JST')

${message}"
    
    gh issue comment "$issue_number" --body "$comment"
    log "Reported status '$status' for issue #$issue_number"
}

# Check for stalled processes
check_stagnation() {
    local last_activity_file="$WORKSPACE/.agent/state/last_activity_${AGENT_NAME}"
    local stagnation_threshold=1800  # 30 minutes
    
    if [ -f "$last_activity_file" ]; then
        local last_activity=$(cat "$last_activity_file")
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_activity))
        
        if [ $time_diff -gt $stagnation_threshold ]; then
            log "WARNING: Possible stagnation detected (${time_diff}s since last activity)"
            return 0
        fi
    fi
    
    # Update last activity
    date +%s > "$last_activity_file"
    return 1
}

# Main execution flow
main() {
    check_prerequisites
    
    log "Starting instruction handler for $AGENT_NAME"
    
    # Check for stagnation
    if check_stagnation; then
        log "Attempting to recover from stagnation..."
        # Could implement recovery logic here
    fi
    
    # Fetch instructions
    local instructions=$(fetch_instructions)
    if [ $? -ne 0 ]; then
        log "No instructions to process"
        exit 0
    fi
    
    # Get task to process
    local task_number=$(get_priority_task "$instructions")
    if [ -z "$task_number" ]; then
        task_number=$(get_next_task "$instructions")
    fi
    
    if [ -z "$task_number" ]; then
        log "No tasks available"
        exit 0
    fi
    
    # Process the instruction
    local task_info=$(process_instruction "$task_number")
    
    # Output task info for next stage
    echo "$task_info"
}

# Run main function
main "$@"
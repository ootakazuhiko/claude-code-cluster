#!/bin/bash
# Agent Report Generator Script
# Purpose: Generate and submit status reports to GitHub

set -e

# Configuration
AGENT_NAME="${AGENT_NAME:-}"
LOG_FILE="${LOG_FILE:-/tmp/agent-report-generator.log}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" | tee -a "$LOG_FILE"
}

# Generate success report
generate_success_report() {
    local issue_number="$1"
    local details="$2"
    
    cat << EOF
## ${AGENT_NAME} Task Completion Report

### ✅ Task Completed Successfully

**Issue**: #${issue_number}
**Completion Time**: $(date '+%Y-%m-%d %H:%M:%S JST')
**Agent**: ${AGENT_NAME}

### Work Summary
${details}

### Next Steps
- Awaiting review
- Ready for next task

### Metrics
- Execution Time: ${EXECUTION_TIME:-N/A}
- Files Modified: $(git diff --name-only 2>/dev/null | wc -l || echo "0")
- Tests Passed: ${TESTS_PASSED:-N/A}
EOF
}

# Generate failure report
generate_failure_report() {
    local issue_number="$1"
    local error_details="$2"
    
    cat << EOF
## ${AGENT_NAME} Task Status Report

### ⚠️ Task Encountered Issues

**Issue**: #${issue_number}
**Report Time**: $(date '+%Y-%m-%d %H:%M:%S JST')
**Agent**: ${AGENT_NAME}

### Error Details
\`\`\`
${error_details}
\`\`\`

### Attempted Actions
- ${ATTEMPTED_ACTIONS:-Task execution attempted}

### Blockers
- ${BLOCKERS:-See error details above}

### Requesting Assistance
Please review the error and provide guidance for resolution.
EOF
}

# Generate progress report
generate_progress_report() {
    local issue_number="$1"
    local progress_details="$2"
    
    cat << EOF
## ${AGENT_NAME} Progress Update

### 🔄 Work in Progress

**Issue**: #${issue_number}
**Update Time**: $(date '+%Y-%m-%d %H:%M:%S JST')
**Agent**: ${AGENT_NAME}

### Progress Summary
${progress_details}

### Completed Steps
${COMPLETED_STEPS:-"- Initial setup completed"}

### Remaining Work
${REMAINING_WORK:-"- Continue implementation"}

### Estimated Completion
${ESTIMATED_COMPLETION:-"Within next cycle"}
EOF
}

# Submit report to GitHub
submit_report() {
    local issue_number="$1"
    local report_content="$2"
    
    log "Submitting report for issue #$issue_number"
    
    # Post comment to issue
    gh issue comment "$issue_number" --body "$report_content"
    
    if [ $? -eq 0 ]; then
        log "Report submitted successfully"
    else
        log "ERROR: Failed to submit report"
        return 1
    fi
}

# Check for stalled work
check_work_status() {
    local issue_number="$1"
    local work_file="/tmp/agent_work_${issue_number}.status"
    
    if [ -f "$work_file" ]; then
        local start_time=$(cat "$work_file")
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        # If work has been ongoing for more than 1 hour
        if [ $elapsed -gt 3600 ]; then
            log "WARNING: Long-running task detected (${elapsed}s)"
            return 1
        fi
    fi
    
    return 0
}

# Generate execution metrics
generate_metrics() {
    local issue_number="$1"
    local start_time="$2"
    local end_time="$3"
    
    # Calculate execution time
    if [ -n "$start_time" ] && [ -n "$end_time" ]; then
        EXECUTION_TIME="$((end_time - start_time))s"
    fi
    
    # Count tests if applicable
    case "$AGENT_NAME" in
        "CC01")
            TESTS_PASSED=$(cd frontend && npm test -- --passWithNoTests 2>/dev/null | grep -o "[0-9]* passed" | cut -d' ' -f1 || echo "N/A")
            ;;
        "CC02")
            TESTS_PASSED=$(cd backend && uv run pytest -q 2>/dev/null | grep -o "[0-9]* passed" | cut -d' ' -f1 || echo "N/A")
            ;;
    esac
}

# Main execution
main() {
    if [ -z "$1" ]; then
        log "ERROR: Task result required"
        exit 1
    fi
    
    # Parse task result
    local task_result="$1"
    local issue_number=$(echo "$task_result" | jq -r '.issue')
    local success=$(echo "$task_result" | jq -r '.success')
    
    log "Generating report for issue #$issue_number (success: $success)"
    
    # Check work status
    if ! check_work_status "$issue_number"; then
        # Generate progress report for long-running tasks
        local report=$(generate_progress_report "$issue_number" "Task is taking longer than expected. Continuing work...")
        submit_report "$issue_number" "$report"
        return 0
    fi
    
    # Generate appropriate report
    if [ "$success" = "true" ]; then
        # Get work details
        local details="Task completed successfully. "
        
        # Add git changes if any
        if ! git diff --quiet 2>/dev/null; then
            details+="Changes have been made and are ready for commit. "
        fi
        
        # Check for created PR
        local pr_number=$(gh pr list --head "$(git branch --show-current)" --json number -q '.[0].number' 2>/dev/null)
        if [ -n "$pr_number" ]; then
            details+="Pull Request #$pr_number has been created/updated. "
        fi
        
        local report=$(generate_success_report "$issue_number" "$details")
    else
        # Get error details
        local error_details="Task execution failed. Check logs for details."
        if [ -f "/tmp/agent_error_${issue_number}.log" ]; then
            error_details=$(tail -n 20 "/tmp/agent_error_${issue_number}.log")
        fi
        
        local report=$(generate_failure_report "$issue_number" "$error_details")
    fi
    
    # Submit the report
    submit_report "$issue_number" "$report"
    
    # Clean up work status file
    rm -f "/tmp/agent_work_${issue_number}.status"
    
    # Update issue labels if successful
    if [ "$success" = "true" ]; then
        gh issue edit "$issue_number" --add-label "completed-by-agent" 2>/dev/null || true
    fi
}

# Run main function
main "$@"
#!/bin/bash
# Agent Task Executor Script
# Purpose: Execute tasks based on instruction type and content

set -e

# Configuration
AGENT_NAME="${AGENT_NAME:-}"
WORKSPACE="${WORKSPACE:-/home/work/ITDO_ERP2}"
LOG_FILE="${LOG_FILE:-$WORKSPACE/.agent/logs/task-executor.log}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" | tee -a "$LOG_FILE"
}

# Execute test task
execute_test_task() {
    local issue_number="$1"
    local instruction_file="$WORKSPACE/.agent/instructions/instruction_${issue_number}.md"
    
    log "Executing test task from issue #$issue_number"
    
    cd "$WORKSPACE"
    
    # Determine test type based on agent
    case "$AGENT_NAME" in
        "CC01")
            # Frontend tests
            cd frontend
            npm test
            local result=$?
            ;;
        "CC02")
            # Backend tests
            cd backend
            uv run pytest -v
            local result=$?
            ;;
        "CC03")
            # Infrastructure tests
            gh workflow run ci.yml --ref main
            local result=$?
            ;;
        *)
            log "ERROR: Unknown agent type for testing"
            return 1
            ;;
    esac
    
    return $result
}

# Execute fix task
execute_fix_task() {
    local issue_number="$1"
    local instruction_file="$WORKSPACE/.agent/instructions/instruction_${issue_number}.md"
    
    log "Executing fix task from issue #$issue_number"
    
    # Parse instruction for specific fixes
    # This is a simplified example - real implementation would parse the markdown
    local fix_type=$(grep -i "fix:" "$instruction_file" | head -1 | cut -d: -f2- | xargs)
    
    cd "$WORKSPACE"
    
    # Create a new branch
    local branch_name="fix/issue-${issue_number}-${AGENT_NAME,,}"
    git checkout -b "$branch_name" || git checkout "$branch_name"
    
    # Execute based on agent type
    case "$AGENT_NAME" in
        "CC01")
            execute_frontend_fix "$fix_type"
            ;;
        "CC02")
            execute_backend_fix "$fix_type"
            ;;
        "CC03")
            execute_infrastructure_fix "$fix_type"
            ;;
    esac
    
    # Check for changes
    if git diff --quiet; then
        log "No changes made for fix"
        return 1
    fi
    
    # Commit changes
    git add -A
    git commit -m "fix: resolve issue #${issue_number}

- Agent: ${AGENT_NAME}
- Type: ${fix_type}
- Auto-generated fix"
    
    return 0
}

# Execute implementation task
execute_implement_task() {
    local issue_number="$1"
    local instruction_file="$WORKSPACE/.agent/instructions/instruction_${issue_number}.md"
    
    log "Executing implementation task from issue #$issue_number"
    
    cd "$WORKSPACE"
    
    # Create feature branch
    local branch_name="feature/issue-${issue_number}-${AGENT_NAME,,}"
    git checkout -b "$branch_name" || git checkout "$branch_name"
    
    # Agent-specific implementation
    case "$AGENT_NAME" in
        "CC01")
            execute_frontend_implementation "$issue_number"
            ;;
        "CC02")
            execute_backend_implementation "$issue_number"
            ;;
        "CC03")
            execute_infrastructure_implementation "$issue_number"
            ;;
    esac
}

# Frontend-specific implementations
execute_frontend_fix() {
    local fix_type="$1"
    
    cd frontend
    
    # Run type check and fix common issues
    npm run typecheck 2>&1 | tee $WORKSPACE/.agent/logs/typecheck_output.txt || true
    
    # Auto-fix linting issues
    npm run lint -- --fix
    
    # Fix specific TypeScript errors
    if grep -q "TS2339" $WORKSPACE/.agent/logs/typecheck_output.txt; then
        log "Fixing TypeScript property access errors"
        # Add type assertions or interface updates
    fi
}

execute_frontend_implementation() {
    local issue_number="$1"
    
    cd frontend/src/components
    
    # Example: Create a new component based on instruction
    # In real implementation, this would parse the instruction file
    cat > "NewComponent.tsx" << 'EOF'
import React from 'react';

interface NewComponentProps {
  title: string;
}

export const NewComponent: React.FC<NewComponentProps> = ({ title }) => {
  return (
    <div className="new-component">
      <h2>{title}</h2>
    </div>
  );
};
EOF
    
    # Create test file
    cat > "NewComponent.test.tsx" << 'EOF'
import { render, screen } from '@testing-library/react';
import { NewComponent } from './NewComponent';

describe('NewComponent', () => {
  it('renders title', () => {
    render(<NewComponent title="Test Title" />);
    expect(screen.getByText('Test Title')).toBeInTheDocument();
  });
});
EOF
}

# Backend-specific implementations
execute_backend_fix() {
    local fix_type="$1"
    
    cd backend
    
    # Run mypy and fix issues
    uv run mypy --strict app/ 2>&1 | tee $WORKSPACE/.agent/logs/mypy_output.txt || true
    
    # Auto-fix common issues
    uv run ruff check . --fix
    uv run ruff format .
}

execute_backend_implementation() {
    local issue_number="$1"
    
    cd backend/app/services
    
    # Example: Create a new service
    cat > "new_service.py" << 'EOF'
from typing import List, Optional
from sqlalchemy.orm import Session

class NewService:
    """Service for handling new functionality."""
    
    def __init__(self, db: Session):
        self.db = db
    
    async def process(self, data: dict) -> dict:
        """Process the provided data."""
        # Implementation based on instruction
        return {"status": "processed", "data": data}
EOF
}

# Infrastructure-specific implementations
execute_infrastructure_fix() {
    local fix_type="$1"
    
    # Fix CI/CD issues
    if [ -f ".github/workflows/ci.yml" ]; then
        # Check for common CI issues
        log "Checking CI configuration"
    fi
}

execute_infrastructure_implementation() {
    local issue_number="$1"
    
    # Create monitoring script
    mkdir -p scripts/monitoring
    
    cat > "scripts/monitoring/health-check.sh" << 'EOF'
#!/bin/bash
# Health check script
echo "Performing health check..."
# Implementation based on instruction
EOF
    
    chmod +x scripts/monitoring/health-check.sh
}

# Main execution
main() {
    if [ -z "$1" ]; then
        log "ERROR: Task info required"
        exit 1
    fi
    
    # Parse task info
    local task_info="$1"
    local issue_number=$(echo "$task_info" | jq -r '.issue')
    local task_type=$(echo "$task_info" | jq -r '.type')
    
    log "Executing $task_type task for issue #$issue_number"
    
    # Execute based on type
    case "$task_type" in
        "test")
            execute_test_task "$issue_number"
            ;;
        "fix")
            execute_fix_task "$issue_number"
            ;;
        "implement")
            execute_implement_task "$issue_number"
            ;;
        *)
            log "Executing general task"
            execute_implement_task "$issue_number"
            ;;
    esac
    
    local result=$?
    
    # Output result
    echo "{\"issue\": $issue_number, \"success\": $([ $result -eq 0 ] && echo true || echo false)}"
}

# Run main function
main "$@"
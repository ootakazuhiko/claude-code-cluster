#!/bin/bash
# Manager-only: Agent Activity Monitoring Script
# Version: 2.0 - Improved detection (2025-07-26)
# Changes: 
#   - Added author-based PR detection to catch unlabeled PRs
#   - Improved issue detection with agent name matching
#   - Added summary statistics

set -euo pipefail

AGENTS=("cc01" "cc02" "cc03")
ACTIVITY_THRESHOLD=24  # hours (increased for better coverage)
AUTHOR="ootakazuhiko"  # GitHub username for agents

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Agent Activity Report $(date) ===${NC}"
echo "Checking activity within last $ACTIVITY_THRESHOLD hours"
echo "Author: $AUTHOR"
echo

# Function to check recent activity
check_agent_activity() {
    local agent=$1
    local agent_upper=${agent^^}
    local pr_count=0
    local commit_count=0
    local issue_count=0
    
    echo -e "${YELLOW}━━━ ${agent_upper} Status ━━━${NC}"
    
    # Check PRs by label
    echo "▶ Recent PRs (labeled):"
    local labeled_prs=$(gh pr list --label "$agent" --state all --limit 10 \
        --json number,title,state,createdAt,updatedAt 2>/dev/null || echo "[]")
    
    if [[ "$labeled_prs" != "[]" ]]; then
        echo "$labeled_prs" | jq -r '.[] | "  PR #\(.number): \(.title) [\(.state)] - \(.createdAt)"' | head -5
        pr_count=$(echo "$labeled_prs" | jq 'length')
    else
        echo "  No labeled PRs found"
    fi
    
    # Check PRs by author with agent mention
    echo "▶ Recent PRs (by author, mentioning $agent):"
    local author_prs=$(gh pr list --author "$AUTHOR" --state all --limit 30 \
        --json number,title,state,createdAt,body 2>/dev/null || echo "[]")
    
    if [[ "$author_prs" != "[]" ]]; then
        local filtered_prs=$(echo "$author_prs" | jq --arg agent "$agent" --arg Agent "$agent_upper" \
            '[.[] | select(.title | test($agent; "i") or .title | test($Agent) or .body | test($agent; "i") or .body | test($Agent))]')
        
        if [[ $(echo "$filtered_prs" | jq 'length') -gt 0 ]]; then
            echo "$filtered_prs" | jq -r '.[] | "  PR #\(.number): \(.title) [\(.state)] - \(.createdAt)"' | head -5
            pr_count=$((pr_count + $(echo "$filtered_prs" | jq 'length')))
        else
            echo "  No PRs mentioning $agent"
        fi
    fi
    
    # Check commits
    echo "▶ Recent commits:"
    local commits=$(git log --oneline --since="$ACTIVITY_THRESHOLD hours ago" \
        --grep="$agent\|${agent_upper}" --author="$AUTHOR" 2>/dev/null | head -5)
    
    if [[ -n "$commits" ]]; then
        echo "$commits" | sed 's/^/  /'
        commit_count=$(echo "$commits" | wc -l)
    else
        echo "  No recent commits"
    fi
    
    # Check Issues
    echo "▶ Active Issues:"
    local issues=$(gh issue list --label "$agent" --state open --limit 5 \
        --json number,title,updatedAt 2>/dev/null || echo "[]")
    
    if [[ "$issues" != "[]" && $(echo "$issues" | jq 'length') -gt 0 ]]; then
        echo "$issues" | jq -r '.[] | "  Issue #\(.number): \(.title) - Updated: \(.updatedAt)"'
        issue_count=$(echo "$issues" | jq 'length')
    else
        echo "  No active issues"
    fi
    
    # Activity summary
    echo
    if [[ $pr_count -gt 0 || $commit_count -gt 0 ]]; then
        echo -e "  ${GREEN}✓ Active${NC} - PRs: $pr_count, Commits: $commit_count, Issues: $issue_count"
    else
        echo -e "  ${RED}⚠ No recent activity detected${NC} - Issues: $issue_count"
    fi
    echo
}

# Check each agent
for agent in "${AGENTS[@]}"; do
    check_agent_activity "$agent"
done

# Overall summary
echo -e "${BLUE}━━━ Summary ━━━${NC}"
echo "To see all open PRs: gh pr list --state open --author $AUTHOR"
echo "To see recent commits: git log --oneline --since='1 day ago' --author=$AUTHOR"
echo
echo -e "${YELLOW}Note:${NC} If agents are creating PRs without labels, consider updating their instructions"
echo "      to include appropriate labels (cc01, cc02, cc03) when creating PRs."
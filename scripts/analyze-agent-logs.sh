#!/bin/bash
# Central Agent Log Analyzer
# Analyzes collected logs from GitHub repository

set -euo pipefail

# Configuration
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
ANALYSIS_DIR="/tmp/agent-analysis-$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="${ANALYSIS_DIR}/multi_agent_analysis.md"

# Create analysis directory
mkdir -p "${ANALYSIS_DIR}"

echo "Starting multi-agent log analysis..."
echo "Analysis directory: ${ANALYSIS_DIR}"

# Function to analyze single agent logs
analyze_agent() {
    local agent=$1
    local log_dir=$2
    local output_file="${ANALYSIS_DIR}/${agent}_analysis.txt"
    
    echo "Analyzing ${agent} logs from ${log_dir}..."
    
    {
        echo "=== ${agent} Analysis ==="
        echo "Log Directory: ${log_dir}"
        echo ""
        
        # Check metadata
        if [ -f "${log_dir}/metadata.json" ]; then
            echo "Metadata:"
            cat "${log_dir}/metadata.json" | python3 -m json.tool 2>/dev/null || cat "${log_dir}/metadata.json"
            echo ""
        fi
        
        # Analyze system info
        if [ -f "${log_dir}/system_info.txt" ]; then
            echo "System Status:"
            grep -E "(Memory:|Disk:|claude|Agent:)" "${log_dir}/system_info.txt" || true
            echo ""
        fi
        
        # Analyze Git activity
        if [ -f "${log_dir}/git_info.txt" ]; then
            echo "Git Activity Summary:"
            echo "- Current Branch: $(grep -A1 "Current Branch" "${log_dir}/git_info.txt" | tail -1)"
            echo "- Recent Commits: $(grep -c "^[a-f0-9]\{7\}" "${log_dir}/git_info.txt" || echo "0")"
            echo "- Modified Files: $(grep -A20 "Modified Files" "${log_dir}/git_info.txt" | grep -v "===" | grep -v "^$" | wc -l || echo "0")"
            echo ""
            
            echo "Last 5 Commits:"
            grep -A10 "Recent Commits" "${log_dir}/git_info.txt" | grep "^[a-f0-9]" | head -5 || true
            echo ""
        fi
        
        # Analyze recent files
        if [ -f "${log_dir}/recent_files.txt" ]; then
            echo "Recent File Activity (last 24h):"
            echo "- Total files modified: $(wc -l < "${log_dir}/recent_files.txt")"
            echo "- Frontend files: $(grep -c "frontend/" "${log_dir}/recent_files.txt" || echo "0")"
            echo "- Backend files: $(grep -c "backend/" "${log_dir}/recent_files.txt" || echo "0")"
            echo "- Test files: $(grep -c "test" "${log_dir}/recent_files.txt" || echo "0")"
            echo ""
        fi
        
        # Analyze shell history
        local history_file="${log_dir}/bash_history.txt"
        [ -f "${log_dir}/zsh_history.txt" ] && history_file="${log_dir}/zsh_history.txt"
        
        if [ -f "$history_file" ]; then
            echo "Command Pattern Analysis:"
            echo "- Git commands: $(grep -c "^git" "$history_file" || echo "0")"
            echo "- Claude commands: $(grep -ic "claude" "$history_file" || echo "0")"
            echo "- NPM/Node commands: $(grep -c "^npm\|^node" "$history_file" || echo "0")"
            echo "- Python/uv commands: $(grep -c "^python\|^uv" "$history_file" || echo "0")"
            echo ""
            
            echo "Recent Claude commands:"
            grep -i "claude" "$history_file" | tail -5 || echo "No claude commands found"
            echo ""
        fi
        
    } > "$output_file"
    
    echo "✓ ${agent} analysis complete"
}

# Create main report
cat > "${REPORT_FILE}" << EOF
# Multi-Agent Activity Analysis Report
Generated: $(date)

## Overview
This report analyzes collected logs from Claude Code agents (CC01, CC02, CC03).

EOF

# Find and analyze all agent logs
echo "Searching for agent logs..."
cd "${PROJECT_DIR}/claude-code-cluster" 2>/dev/null || cd "${PROJECT_DIR}"

# Get latest logs for each agent
for agent in CC01 CC02 CC03; do
    # Find the most recent log directory for this agent
    latest_log=$(find "logs/${agent}" -name "metadata.json" -type f 2>/dev/null | sort -r | head -1 | xargs dirname)
    
    if [ -n "$latest_log" ] && [ -d "$latest_log" ]; then
        analyze_agent "$agent" "$latest_log"
        
        # Add to main report
        {
            echo "## ${agent} Summary"
            echo ""
            cat "${ANALYSIS_DIR}/${agent}_analysis.txt" | grep -A50 "===" | tail -n +2
            echo ""
            echo "---"
            echo ""
        } >> "${REPORT_FILE}"
    else
        echo "⚠️  No logs found for ${agent}"
        echo "## ${agent} Summary" >> "${REPORT_FILE}"
        echo "No logs available for analysis." >> "${REPORT_FILE}"
        echo "" >> "${REPORT_FILE}"
    fi
done

# Generate comparative analysis
echo "" >> "${REPORT_FILE}"
echo "## Comparative Analysis" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Compare activity levels
echo "### Activity Comparison" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "| Agent | Commits | Modified Files | Last Activity |" >> "${REPORT_FILE}"
echo "|-------|---------|----------------|---------------|" >> "${REPORT_FILE}"

for agent in CC01 CC02 CC03; do
    if [ -f "${ANALYSIS_DIR}/${agent}_analysis.txt" ]; then
        commits=$(grep "Recent Commits:" "${ANALYSIS_DIR}/${agent}_analysis.txt" | cut -d: -f2 | tr -d ' ')
        files=$(grep "Total files modified:" "${ANALYSIS_DIR}/${agent}_analysis.txt" | cut -d: -f2 | tr -d ' ')
        last_commit=$(grep "^[a-f0-9]" "${ANALYSIS_DIR}/${agent}_analysis.txt" | head -1 | cut -d' ' -f2-3 || echo "Unknown")
        echo "| ${agent} | ${commits:-0} | ${files:-0} | ${last_commit} |" >> "${REPORT_FILE}"
    else
        echo "| ${agent} | N/A | N/A | No data |" >> "${REPORT_FILE}"
    fi
done

echo "" >> "${REPORT_FILE}"

# Add recommendations
echo "## Recommendations" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Check for inactive agents
inactive_count=0
for agent in CC01 CC02 CC03; do
    if [ ! -f "${ANALYSIS_DIR}/${agent}_analysis.txt" ]; then
        ((inactive_count++))
        echo "- ⚠️  ${agent}: No recent activity detected - investigate connection" >> "${REPORT_FILE}"
    elif ! grep -q "Recent Commits: [1-9]" "${ANALYSIS_DIR}/${agent}_analysis.txt"; then
        echo "- ⚠️  ${agent}: No recent commits - may need task clarification" >> "${REPORT_FILE}"
    fi
done

if [ $inactive_count -eq 0 ]; then
    echo "- ✅ All agents show recent activity" >> "${REPORT_FILE}"
fi

echo "" >> "${REPORT_FILE}"
echo "Analysis complete: ${REPORT_FILE}" >> "${REPORT_FILE}"

# Display summary
echo ""
echo "✅ Analysis complete!"
echo ""
echo "Reports generated:"
echo "- Main report: ${REPORT_FILE}"
echo "- Individual analyses: ${ANALYSIS_DIR}/*_analysis.txt"
echo ""
echo "Key findings:"
grep -E "(Recent Commits:|Total files modified:|No logs)" "${ANALYSIS_DIR}"/*_analysis.txt 2>/dev/null | sed 's/.*\//  - /' || true
echo ""
echo "To view the full report:"
echo "  cat ${REPORT_FILE}"
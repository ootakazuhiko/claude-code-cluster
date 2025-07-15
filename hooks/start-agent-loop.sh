#!/bin/bash

# Agent Auto-Loop Startup Script
# Start autonomous agents with continuous task processing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if claude-code-cluster is available
    if [ ! -d "/tmp/claude-code-cluster" ]; then
        print_status "Cloning claude-code-cluster..."
        git clone https://github.com/ootakazuhiko/claude-code-cluster.git /tmp/claude-code-cluster
    fi
    
    # Check Python dependencies
    if ! python3 -c "import sqlite3, json, subprocess" 2>/dev/null; then
        print_error "Required Python modules not available"
        exit 1
    fi
    
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) not installed"
        exit 1
    fi
    
    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI not authenticated"
        exit 1
    fi
    
    print_status "Prerequisites check passed"
}

# Function to start a single agent
start_agent() {
    local agent_id="$1"
    local max_iterations="$2"
    local cooldown="${3:-60}"
    
    print_status "Starting Agent $agent_id..."
    
    # Create log directory
    mkdir -p "/tmp/agent-logs"
    
    # Start agent in background
    cd "$PROJECT_DIR"
    python3 hooks/agent-auto-loop.py "$agent_id" \
        --max-iterations "$max_iterations" \
        --cooldown "$cooldown" \
        > "/tmp/agent-logs/agent-$agent_id.log" 2>&1 &
    
    local pid=$!
    echo "$pid" > "/tmp/agent-$agent_id.pid"
    
    print_status "Agent $agent_id started with PID $pid"
    print_status "Log file: /tmp/agent-logs/agent-$agent_id.log"
}

# Function to stop agent
stop_agent() {
    local agent_id="$1"
    local pid_file="/tmp/agent-$agent_id.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            print_status "Stopping Agent $agent_id (PID: $pid)..."
            kill "$pid"
            rm -f "$pid_file"
            print_status "Agent $agent_id stopped"
        else
            print_warning "Agent $agent_id not running"
            rm -f "$pid_file"
        fi
    else
        print_warning "Agent $agent_id PID file not found"
    fi
}

# Function to check agent status
check_agent_status() {
    local agent_id="$1"
    local pid_file="/tmp/agent-$agent_id.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            print_status "Agent $agent_id is running (PID: $pid)"
            
            # Show recent log entries
            if [ -f "/tmp/agent-logs/agent-$agent_id.log" ]; then
                echo "Recent log entries:"
                tail -n 5 "/tmp/agent-logs/agent-$agent_id.log"
            fi
        else
            print_warning "Agent $agent_id is not running"
            rm -f "$pid_file"
        fi
    else
        print_warning "Agent $agent_id is not running"
    fi
}

# Function to show agent metrics
show_agent_metrics() {
    local agent_id="$1"
    local db_path="/tmp/agent-$agent_id-loop.db"
    
    if [ -f "$db_path" ]; then
        print_status "Agent $agent_id metrics:"
        
        # Show recent task history
        echo "Recent tasks:"
        sqlite3 "$db_path" "SELECT task_id, task_title, status, duration, start_time FROM task_history WHERE agent_id = '$agent_id' ORDER BY start_time DESC LIMIT 5;"
        
        # Show today's metrics
        echo "Today's metrics:"
        sqlite3 "$db_path" "SELECT tasks_completed, tasks_failed, avg_duration, escalations FROM agent_metrics WHERE agent_id = '$agent_id' AND date = date('now');"
    else
        print_warning "No metrics database found for Agent $agent_id"
    fi
}

# Function to display help
show_help() {
    echo "Agent Auto-Loop Management Script"
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  start [CC01|CC02|CC03|all] [max_iterations] [cooldown]  - Start agent(s)"
    echo "  stop [CC01|CC02|CC03|all]                               - Stop agent(s)"
    echo "  status [CC01|CC02|CC03|all]                            - Check agent status"
    echo "  metrics [CC01|CC02|CC03|all]                           - Show agent metrics"
    echo "  restart [CC01|CC02|CC03|all]                           - Restart agent(s)"
    echo "  logs [CC01|CC02|CC03]                                  - Show agent logs"
    echo "  cleanup                                                - Clean up PID files and logs"
    echo "  help                                                   - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 start CC01                    # Start CC01 indefinitely"
    echo "  $0 start CC01 10 30             # Start CC01 for 10 iterations, 30s cooldown"
    echo "  $0 start all                    # Start all agents"
    echo "  $0 stop CC02                    # Stop CC02"
    echo "  $0 status all                   # Check status of all agents"
    echo "  $0 metrics CC01                 # Show CC01 metrics"
}

# Main script logic
main() {
    local command="$1"
    local target="$2"
    local max_iterations="$3"
    local cooldown="${4:-60}"
    
    case "$command" in
        "start")
            check_prerequisites
            
            if [ "$target" = "all" ]; then
                start_agent "CC01" "$max_iterations" "$cooldown"
                sleep 2
                start_agent "CC02" "$max_iterations" "$cooldown"
                sleep 2
                start_agent "CC03" "$max_iterations" "$cooldown"
            elif [ "$target" = "CC01" ] || [ "$target" = "CC02" ] || [ "$target" = "CC03" ]; then
                start_agent "$target" "$max_iterations" "$cooldown"
            else
                print_error "Invalid target: $target"
                show_help
                exit 1
            fi
            ;;
        
        "stop")
            if [ "$target" = "all" ]; then
                stop_agent "CC01"
                stop_agent "CC02"
                stop_agent "CC03"
            elif [ "$target" = "CC01" ] || [ "$target" = "CC02" ] || [ "$target" = "CC03" ]; then
                stop_agent "$target"
            else
                print_error "Invalid target: $target"
                show_help
                exit 1
            fi
            ;;
        
        "status")
            if [ "$target" = "all" ]; then
                check_agent_status "CC01"
                echo ""
                check_agent_status "CC02"
                echo ""
                check_agent_status "CC03"
            elif [ "$target" = "CC01" ] || [ "$target" = "CC02" ] || [ "$target" = "CC03" ]; then
                check_agent_status "$target"
            else
                print_error "Invalid target: $target"
                show_help
                exit 1
            fi
            ;;
        
        "metrics")
            if [ "$target" = "all" ]; then
                show_agent_metrics "CC01"
                echo ""
                show_agent_metrics "CC02"
                echo ""
                show_agent_metrics "CC03"
            elif [ "$target" = "CC01" ] || [ "$target" = "CC02" ] || [ "$target" = "CC03" ]; then
                show_agent_metrics "$target"
            else
                print_error "Invalid target: $target"
                show_help
                exit 1
            fi
            ;;
        
        "restart")
            if [ "$target" = "all" ]; then
                stop_agent "CC01"
                stop_agent "CC02"
                stop_agent "CC03"
                sleep 2
                start_agent "CC01" "$max_iterations" "$cooldown"
                sleep 2
                start_agent "CC02" "$max_iterations" "$cooldown"
                sleep 2
                start_agent "CC03" "$max_iterations" "$cooldown"
            elif [ "$target" = "CC01" ] || [ "$target" = "CC02" ] || [ "$target" = "CC03" ]; then
                stop_agent "$target"
                sleep 2
                start_agent "$target" "$max_iterations" "$cooldown"
            else
                print_error "Invalid target: $target"
                show_help
                exit 1
            fi
            ;;
        
        "logs")
            if [ "$target" = "CC01" ] || [ "$target" = "CC02" ] || [ "$target" = "CC03" ]; then
                local log_file="/tmp/agent-logs/agent-$target.log"
                if [ -f "$log_file" ]; then
                    tail -f "$log_file"
                else
                    print_error "Log file not found: $log_file"
                fi
            else
                print_error "Invalid target: $target"
                show_help
                exit 1
            fi
            ;;
        
        "cleanup")
            print_status "Cleaning up PID files and logs..."
            rm -f /tmp/agent-*.pid
            rm -rf /tmp/agent-logs
            rm -f /tmp/agent-*-loop.db
            rm -f /tmp/agent-*-loop.log
            print_status "Cleanup completed"
            ;;
        
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
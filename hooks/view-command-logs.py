#!/usr/bin/env python3
"""
Command Log Viewer for Claude Code Hook System
Utility to view and analyze command execution logs
"""

import sqlite3
import json
import argparse
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict, Any
import sys

# Add project root to path
sys.path.append(str(Path(__file__).parent.parent))

from hooks.command_logger import CommandLogger

def format_duration(duration_ms: Optional[int]) -> str:
    """Format duration in milliseconds to human readable format"""
    if duration_ms is None:
        return "N/A"
    
    if duration_ms < 1000:
        return f"{duration_ms}ms"
    elif duration_ms < 60000:
        return f"{duration_ms/1000:.1f}s"
    else:
        return f"{duration_ms/60000:.1f}m"

def print_command_history(commands: List[Dict[str, Any]], verbose: bool = False):
    """Pretty print command history"""
    if not commands:
        print("No commands found.")
        return
    
    print(f"\n{'='*120}")
    print(f"{'Timestamp':<20} {'Type':<10} {'Command':<40} {'Status':<10} {'Duration':<10}")
    print(f"{'-'*120}")
    
    for cmd in commands:
        timestamp = datetime.fromisoformat(cmd['timestamp']).strftime('%Y-%m-%d %H:%M:%S')
        command = cmd['command'][:37] + "..." if len(cmd['command']) > 40 else cmd['command']
        status = cmd.get('status', 'N/A')
        duration = format_duration(cmd.get('duration_ms'))
        
        # Color code status
        if status == 'SUCCESS':
            status_color = '\033[92m'  # Green
        elif status == 'ERROR':
            status_color = '\033[91m'  # Red
        elif status == 'IN_PROGRESS':
            status_color = '\033[93m'  # Yellow
        else:
            status_color = '\033[0m'   # Default
        
        print(f"{timestamp:<20} {cmd['command_type']:<10} {command:<40} {status_color}{status:<10}\033[0m {duration:<10}")
        
        if verbose:
            if cmd.get('parameters'):
                params = json.loads(cmd['parameters'])
                if params:
                    print(f"  Parameters: {json.dumps(params, indent=2)}")
            if cmd.get('error_message'):
                print(f"  Error: {cmd['error_message']}")
            print()
    
    print(f"{'='*120}\n")

def print_issue_history(issues: List[Dict[str, Any]]):
    """Pretty print issue processing history"""
    if not issues:
        print("No issue processing events found.")
        return
    
    print(f"\n{'='*120}")
    print(f"{'Timestamp':<20} {'Issue #':<10} {'Action':<25} {'Status':<10} {'Title':<35}")
    print(f"{'-'*120}")
    
    for issue in issues:
        timestamp = datetime.fromisoformat(issue['timestamp']).strftime('%Y-%m-%d %H:%M:%S')
        issue_number = issue['issue_number']
        action = issue['action_type'][:25]
        status = issue.get('status', 'N/A')
        title = issue.get('issue_title', '')[:32] + "..." if len(issue.get('issue_title', '')) > 35 else issue.get('issue_title', '')
        
        # Color code status
        if status == 'SUCCESS':
            status_color = '\033[92m'  # Green
        elif status == 'ERROR':
            status_color = '\033[91m'  # Red
        else:
            status_color = '\033[93m'  # Yellow
        
        print(f"{timestamp:<20} {issue_number:<10} {action:<25} {status_color}{status:<10}\033[0m {title:<35}")
    
    print(f"{'='*120}\n")

def print_statistics(stats: Dict[str, Any]):
    """Pretty print command statistics"""
    if not stats:
        print("No statistics available.")
        return
    
    print(f"\n{'='*80}")
    print("Command Execution Statistics")
    print(f"{'-'*80}")
    print(f"{'Command Type':<20} {'Count':<10} {'Success %':<12} {'Avg Time':<12} {'Max Time':<12}")
    print(f"{'-'*80}")
    
    for cmd_type, cmd_stats in stats.items():
        count = cmd_stats['count']
        success_rate = cmd_stats['success_rate']
        avg_duration = format_duration(int(cmd_stats['avg_duration_ms']))
        max_duration = format_duration(cmd_stats.get('max_duration_ms'))
        
        print(f"{cmd_type:<20} {count:<10} {success_rate:<12.1f} {avg_duration:<12} {max_duration:<12}")
    
    print(f"{'='*80}\n")

def view_logs(log_dir: str, agent_id: Optional[str] = None, 
              command_type: Optional[str] = None, 
              limit: int = 20, verbose: bool = False,
              show_stats: bool = False, export_file: Optional[str] = None):
    """View command logs with various filters"""
    
    # Determine log directory
    if agent_id:
        log_path = f"{log_dir}/agent-{agent_id}"
    else:
        log_path = log_dir
    
    logger = CommandLogger(log_path)
    
    # Display statistics if requested
    if show_stats:
        stats = logger.get_command_stats()
        print_statistics(stats)
        return
    
    # Export logs if requested
    if export_file:
        export_path = logger.export_logs_to_json(export_file)
        print(f"Logs exported to: {export_path}")
        return
    
    # Get recent commands
    print(f"\nShowing recent commands from: {log_path}")
    commands = logger.get_recent_commands(limit=limit, command_type=command_type)
    print_command_history(commands, verbose=verbose)
    
    # Get recent issue processing events
    with logger.get_db_connection() as conn:
        cursor = conn.execute('''
            SELECT * FROM issue_processing_log 
            ORDER BY timestamp DESC 
            LIMIT ?
        ''', (limit,))
        issues = [dict(row) for row in cursor.fetchall()]
    
    if issues:
        print("\nRecent Issue Processing Events:")
        print_issue_history(issues)

def follow_logs(log_dir: str, agent_id: Optional[str] = None, interval: int = 5):
    """Follow logs in real-time (tail -f style)"""
    import time
    
    # Determine log directory
    if agent_id:
        log_path = f"{log_dir}/agent-{agent_id}"
    else:
        log_path = log_dir
    
    logger = CommandLogger(log_path)
    
    print(f"Following logs from: {log_path}")
    print("Press Ctrl+C to stop...\n")
    
    last_command_id = 0
    last_issue_id = 0
    
    try:
        while True:
            # Get new commands
            with logger.get_db_connection() as conn:
                cursor = conn.execute('''
                    SELECT * FROM command_history 
                    WHERE id > ? 
                    ORDER BY id
                ''', (last_command_id,))
                new_commands = [dict(row) for row in cursor.fetchall()]
                
                if new_commands:
                    print_command_history(new_commands)
                    last_command_id = new_commands[-1]['id']
                
                # Get new issue events
                cursor = conn.execute('''
                    SELECT * FROM issue_processing_log 
                    WHERE id > ? 
                    ORDER BY id
                ''', (last_issue_id,))
                new_issues = [dict(row) for row in cursor.fetchall()]
                
                if new_issues:
                    print_issue_history(new_issues)
                    last_issue_id = new_issues[-1]['id']
            
            time.sleep(interval)
            
    except KeyboardInterrupt:
        print("\nStopped following logs.")

def main():
    parser = argparse.ArgumentParser(description='View Claude Code command execution logs')
    parser.add_argument('--log-dir', default='/tmp/claude-code-logs',
                       help='Base directory for logs (default: /tmp/claude-code-logs)')
    parser.add_argument('--agent', help='Filter logs by agent ID (e.g., CC01)')
    parser.add_argument('--type', help='Filter commands by type (e.g., SHELL, API, GH_API)')
    parser.add_argument('--limit', type=int, default=20,
                       help='Number of recent entries to show (default: 20)')
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Show detailed information including parameters and errors')
    parser.add_argument('--stats', action='store_true',
                       help='Show command execution statistics')
    parser.add_argument('--export', help='Export logs to JSON file')
    parser.add_argument('--follow', action='store_true',
                       help='Follow logs in real-time (like tail -f)')
    parser.add_argument('--interval', type=int, default=5,
                       help='Update interval for follow mode in seconds (default: 5)')
    
    args = parser.parse_args()
    
    if args.follow:
        follow_logs(args.log_dir, args.agent, args.interval)
    else:
        view_logs(
            args.log_dir,
            agent_id=args.agent,
            command_type=args.type,
            limit=args.limit,
            verbose=args.verbose,
            show_stats=args.stats,
            export_file=args.export
        )

if __name__ == '__main__':
    main()
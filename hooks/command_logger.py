#!/usr/bin/env python3
"""
Command Logger for Claude Code Hook System
Records all command executions, API calls, and issue processing events

Based on: https://github.com/ootakazuhiko/claude-code-cluster/blob/main/docs/tmp/claude-code-hook-system-doc.md
"""

import sqlite3
import json
import time
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional, List, Union
from contextlib import contextmanager
from dataclasses import dataclass, asdict
import traceback
import os

@dataclass
class CommandRecord:
    """Record for command execution"""
    timestamp: str
    command_type: str
    command: str
    parameters: Dict[str, Any]
    result: Optional[str] = None
    status: str = "IN_PROGRESS"
    duration_ms: Optional[int] = None
    error_message: Optional[str] = None

@dataclass
class IssueProcessingRecord:
    """Record for issue processing events"""
    timestamp: str
    issue_number: str
    issue_title: str
    action_type: str
    details: Dict[str, Any]
    status: str = "IN_PROGRESS"

class CommandLogger:
    """
    Logger for all command executions and issue processing events
    Provides both SQLite database and file-based logging
    """
    
    def __init__(self, log_dir: str = "/tmp/claude-code-logs"):
        """Initialize command logger with database and file logging"""
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(exist_ok=True)
        
        # Database path
        self.db_path = self.log_dir / "command_history.db"
        
        # File-based logs
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.command_log_file = self.log_dir / f"commands_{timestamp}.log"
        self.issue_log_file = self.log_dir / f"issues_{timestamp}.log"
        
        # Setup database
        self.setup_database()
        
        # Setup file logging
        self.setup_file_logging()
        
    def setup_database(self):
        """Setup SQLite database with required tables"""
        with self.get_db_connection() as conn:
            # Command history table
            conn.execute('''
                CREATE TABLE IF NOT EXISTS command_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    command_type TEXT NOT NULL,
                    command TEXT NOT NULL,
                    parameters TEXT,
                    result TEXT,
                    status TEXT NOT NULL,
                    duration_ms INTEGER,
                    error_message TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Issue processing log table
            conn.execute('''
                CREATE TABLE IF NOT EXISTS issue_processing_log (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    issue_number TEXT NOT NULL,
                    issue_title TEXT,
                    action_type TEXT NOT NULL,
                    details TEXT,
                    status TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Create indexes for better performance
            conn.execute('''
                CREATE INDEX IF NOT EXISTS idx_command_timestamp 
                ON command_history(timestamp DESC)
            ''')
            
            conn.execute('''
                CREATE INDEX IF NOT EXISTS idx_command_type 
                ON command_history(command_type)
            ''')
            
            conn.execute('''
                CREATE INDEX IF NOT EXISTS idx_issue_number 
                ON issue_processing_log(issue_number)
            ''')
            
            conn.execute('''
                CREATE INDEX IF NOT EXISTS idx_issue_timestamp 
                ON issue_processing_log(timestamp DESC)
            ''')
            
            conn.commit()
    
    def setup_file_logging(self):
        """Setup file-based logging handlers"""
        # Command logger
        self.command_file_logger = logging.getLogger('command_file_logger')
        self.command_file_logger.setLevel(logging.INFO)
        command_handler = logging.FileHandler(self.command_log_file)
        command_handler.setFormatter(
            logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        )
        self.command_file_logger.addHandler(command_handler)
        
        # Issue logger
        self.issue_file_logger = logging.getLogger('issue_file_logger')
        self.issue_file_logger.setLevel(logging.INFO)
        issue_handler = logging.FileHandler(self.issue_log_file)
        issue_handler.setFormatter(
            logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        )
        self.issue_file_logger.addHandler(issue_handler)
    
    @contextmanager
    def get_db_connection(self):
        """Context manager for database connections"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()
    
    def log_command_start(self, command_type: str, command: str, 
                         parameters: Optional[Dict[str, Any]] = None) -> int:
        """
        Log the start of a command execution
        Returns the command ID for later update
        """
        timestamp = datetime.now().isoformat()
        record = CommandRecord(
            timestamp=timestamp,
            command_type=command_type,
            command=command,
            parameters=parameters or {},
            status="IN_PROGRESS"
        )
        
        # Log to file
        self.command_file_logger.info(
            f"START - Type: {command_type} - Command: {command} - Params: {json.dumps(parameters)}"
        )
        
        # Log to database
        with self.get_db_connection() as conn:
            cursor = conn.execute('''
                INSERT INTO command_history 
                (timestamp, command_type, command, parameters, status)
                VALUES (?, ?, ?, ?, ?)
            ''', (
                record.timestamp,
                record.command_type,
                record.command,
                json.dumps(record.parameters),
                record.status
            ))
            conn.commit()
            return cursor.lastrowid
    
    def log_command_complete(self, command_id: int, result: str, 
                           duration_ms: int, status: str = "SUCCESS"):
        """Log successful command completion"""
        # Log to file
        self.command_file_logger.info(
            f"COMPLETE - ID: {command_id} - Status: {status} - Duration: {duration_ms}ms - Result: {result[:100]}..."
        )
        
        # Update database
        with self.get_db_connection() as conn:
            conn.execute('''
                UPDATE command_history 
                SET result = ?, status = ?, duration_ms = ?
                WHERE id = ?
            ''', (result, status, duration_ms, command_id))
            conn.commit()
    
    def log_command_error(self, command_id: int, error_message: str, 
                         duration_ms: int):
        """Log command execution error"""
        # Log to file
        self.command_file_logger.error(
            f"ERROR - ID: {command_id} - Duration: {duration_ms}ms - Error: {error_message}"
        )
        
        # Update database
        with self.get_db_connection() as conn:
            conn.execute('''
                UPDATE command_history 
                SET status = ?, error_message = ?, duration_ms = ?
                WHERE id = ?
            ''', ("ERROR", error_message, duration_ms, command_id))
            conn.commit()
    
    @contextmanager
    def log_command(self, command_type: str, command: str, 
                   parameters: Optional[Dict[str, Any]] = None):
        """
        Context manager for logging command execution
        Automatically tracks timing and handles errors
        """
        start_time = time.time()
        command_id = self.log_command_start(command_type, command, parameters)
        
        try:
            yield command_id
            # If we get here, command succeeded
            duration_ms = int((time.time() - start_time) * 1000)
            self.log_command_complete(command_id, "Completed", duration_ms)
        except Exception as e:
            # Log error
            duration_ms = int((time.time() - start_time) * 1000)
            error_msg = f"{type(e).__name__}: {str(e)}\n{traceback.format_exc()}"
            self.log_command_error(command_id, error_msg, duration_ms)
            raise
    
    def log_issue_processing_start(self, issue_number: str, issue_title: str, 
                                  action_type: str, details: Optional[Dict[str, Any]] = None):
        """Log the start of issue processing"""
        timestamp = datetime.now().isoformat()
        record = IssueProcessingRecord(
            timestamp=timestamp,
            issue_number=issue_number,
            issue_title=issue_title,
            action_type=action_type,
            details=details or {},
            status="IN_PROGRESS"
        )
        
        # Log to file
        self.issue_file_logger.info(
            f"START - Issue #{issue_number}: {issue_title} - Action: {action_type} - Details: {json.dumps(details)}"
        )
        
        # Log to database
        with self.get_db_connection() as conn:
            conn.execute('''
                INSERT INTO issue_processing_log 
                (timestamp, issue_number, issue_title, action_type, details, status)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (
                record.timestamp,
                record.issue_number,
                record.issue_title,
                record.action_type,
                json.dumps(record.details),
                record.status
            ))
            conn.commit()
    
    def log_issue_processing_complete(self, issue_number: str, action_type: str, 
                                    details: Optional[Dict[str, Any]] = None):
        """Log successful issue processing completion"""
        timestamp = datetime.now().isoformat()
        
        # Log to file
        self.issue_file_logger.info(
            f"COMPLETE - Issue #{issue_number} - Action: {action_type} - Details: {json.dumps(details)}"
        )
        
        # Log to database
        with self.get_db_connection() as conn:
            conn.execute('''
                INSERT INTO issue_processing_log 
                (timestamp, issue_number, issue_title, action_type, details, status)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (
                timestamp,
                issue_number,
                "",  # Title might not be available here
                f"{action_type}_COMPLETE",
                json.dumps(details or {}),
                "SUCCESS"
            ))
            conn.commit()
    
    def log_issue_processing_error(self, issue_number: str, action_type: str, 
                                 error_message: str, details: Optional[Dict[str, Any]] = None):
        """Log issue processing error"""
        timestamp = datetime.now().isoformat()
        
        # Log to file
        self.issue_file_logger.error(
            f"ERROR - Issue #{issue_number} - Action: {action_type} - Error: {error_message} - Details: {json.dumps(details)}"
        )
        
        # Log to database
        with self.get_db_connection() as conn:
            conn.execute('''
                INSERT INTO issue_processing_log 
                (timestamp, issue_number, issue_title, action_type, details, status)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (
                timestamp,
                issue_number,
                "",  # Title might not be available here
                f"{action_type}_ERROR",
                json.dumps({**(details or {}), "error": error_message}),
                "ERROR"
            ))
            conn.commit()
    
    def get_recent_commands(self, limit: int = 10, 
                          command_type: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get recent command executions"""
        with self.get_db_connection() as conn:
            if command_type:
                query = '''
                    SELECT * FROM command_history 
                    WHERE command_type = ?
                    ORDER BY timestamp DESC 
                    LIMIT ?
                '''
                cursor = conn.execute(query, (command_type, limit))
            else:
                query = '''
                    SELECT * FROM command_history 
                    ORDER BY timestamp DESC 
                    LIMIT ?
                '''
                cursor = conn.execute(query, (limit,))
            
            return [dict(row) for row in cursor.fetchall()]
    
    def get_issue_history(self, issue_number: str) -> List[Dict[str, Any]]:
        """Get processing history for a specific issue"""
        with self.get_db_connection() as conn:
            cursor = conn.execute('''
                SELECT * FROM issue_processing_log 
                WHERE issue_number = ?
                ORDER BY timestamp DESC
            ''', (issue_number,))
            
            return [dict(row) for row in cursor.fetchall()]
    
    def get_command_stats(self, since_timestamp: Optional[str] = None) -> Dict[str, Any]:
        """Get command execution statistics"""
        with self.get_db_connection() as conn:
            if since_timestamp:
                # Stats since specific time
                cursor = conn.execute('''
                    SELECT 
                        command_type,
                        COUNT(*) as count,
                        AVG(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) * 100 as success_rate,
                        AVG(duration_ms) as avg_duration_ms,
                        MAX(duration_ms) as max_duration_ms,
                        MIN(duration_ms) as min_duration_ms
                    FROM command_history
                    WHERE timestamp >= ?
                    GROUP BY command_type
                ''', (since_timestamp,))
            else:
                # All-time stats
                cursor = conn.execute('''
                    SELECT 
                        command_type,
                        COUNT(*) as count,
                        AVG(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) * 100 as success_rate,
                        AVG(duration_ms) as avg_duration_ms,
                        MAX(duration_ms) as max_duration_ms,
                        MIN(duration_ms) as min_duration_ms
                    FROM command_history
                    GROUP BY command_type
                ''')
            
            stats = {}
            for row in cursor.fetchall():
                stats[row['command_type']] = {
                    'count': row['count'],
                    'success_rate': round(row['success_rate'], 2),
                    'avg_duration_ms': round(row['avg_duration_ms'] or 0, 2),
                    'max_duration_ms': row['max_duration_ms'],
                    'min_duration_ms': row['min_duration_ms']
                }
            
            return stats
    
    def export_logs_to_json(self, output_file: str, 
                          since_timestamp: Optional[str] = None):
        """Export logs to JSON file for analysis"""
        data = {
            'export_timestamp': datetime.now().isoformat(),
            'command_history': [],
            'issue_processing_log': []
        }
        
        with self.get_db_connection() as conn:
            # Export commands
            if since_timestamp:
                cursor = conn.execute(
                    'SELECT * FROM command_history WHERE timestamp >= ? ORDER BY timestamp',
                    (since_timestamp,)
                )
            else:
                cursor = conn.execute('SELECT * FROM command_history ORDER BY timestamp')
            
            data['command_history'] = [dict(row) for row in cursor.fetchall()]
            
            # Export issue logs
            if since_timestamp:
                cursor = conn.execute(
                    'SELECT * FROM issue_processing_log WHERE timestamp >= ? ORDER BY timestamp',
                    (since_timestamp,)
                )
            else:
                cursor = conn.execute('SELECT * FROM issue_processing_log ORDER BY timestamp')
            
            data['issue_processing_log'] = [dict(row) for row in cursor.fetchall()]
        
        # Write to file
        output_path = Path(output_file)
        with open(output_path, 'w') as f:
            json.dump(data, f, indent=2)
        
        return output_path

# Singleton instance for easy access
_logger_instance = None

def get_logger(log_dir: str = "/tmp/claude-code-logs") -> CommandLogger:
    """Get or create the singleton logger instance"""
    global _logger_instance
    if _logger_instance is None:
        _logger_instance = CommandLogger(log_dir)
    return _logger_instance

# Example usage functions
def log_shell_command(command: str, cwd: str = None) -> int:
    """Helper function to log shell command execution"""
    logger = get_logger()
    parameters = {"cwd": cwd or os.getcwd()}
    return logger.log_command_start("SHELL", command, parameters)

def log_api_call(endpoint: str, method: str = "GET", params: Dict[str, Any] = None) -> int:
    """Helper function to log API calls"""
    logger = get_logger()
    parameters = {"method": method, "params": params or {}}
    return logger.log_command_start("API", endpoint, parameters)

if __name__ == "__main__":
    # Example usage
    logger = CommandLogger()
    
    # Log a shell command
    with logger.log_command("SHELL", "ls -la", {"cwd": "/tmp"}):
        print("Executing ls command...")
        time.sleep(0.1)  # Simulate command execution
    
    # Log an API call
    cmd_id = logger.log_command_start("API", "gh issue list", {"repo": "owner/repo"})
    time.sleep(0.2)  # Simulate API call
    logger.log_command_complete(cmd_id, '{"issues": []}', 200)
    
    # Log issue processing
    logger.log_issue_processing_start("123", "Test Issue", "ANALYZE", {"labels": ["bug"]})
    time.sleep(0.1)
    logger.log_issue_processing_complete("123", "ANALYZE", {"result": "processed"})
    
    # Get stats
    stats = logger.get_command_stats()
    print("\nCommand Statistics:")
    print(json.dumps(stats, indent=2))
    
    # Export logs
    export_path = logger.export_logs_to_json("/tmp/command_logs_export.json")
    print(f"\nLogs exported to: {export_path}")
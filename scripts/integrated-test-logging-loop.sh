#!/bin/bash

# Integrated Test Script for Command Logging + Auto-Loop System
# コマンドロギングと自動ループシステムの統合テスト

set -e

echo "🚀 Integrated Test: Command Logging + Auto-Loop System"
echo "====================================================="

# 設定
TEST_DIR="/tmp/integrated-test-$(date +%Y%m%d_%H%M%S)"
CLUSTER_DIR="$TEST_DIR/claude-code-cluster"
HOOKS_DIR="/mnt/c/work/ITDO_ERP2/hooks"
LOG_DIR="/tmp/claude-code-logs"

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ステップ表示関数
step() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# エラーハンドラ
trap 'error "Error occurred at line $LINENO"' ERR

# 作業ディレクトリの準備
step "Setting up test environment"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# 必要なファイルのコピー
step "Copying required files"
mkdir -p "$TEST_DIR/hooks"

# コマンドロギングシステムのファイルをコピー
if [ -f "$HOOKS_DIR/command_logger.py" ]; then
    cp "$HOOKS_DIR/command_logger.py" "$TEST_DIR/hooks/"
    success "Copied command_logger.py"
else
    error "command_logger.py not found"
    exit 1
fi

if [ -f "$HOOKS_DIR/view-command-logs.py" ]; then
    cp "$HOOKS_DIR/view-command-logs.py" "$TEST_DIR/hooks/"
    success "Copied view-command-logs.py"
else
    error "view-command-logs.py not found"
    exit 1
fi

# 統合テスト用のミニエージェントを作成
step "Creating test agent with logging"
cat > "$TEST_DIR/hooks/test-agent-with-logging.py" << 'EOF'
#!/usr/bin/env python3
"""
Test Agent with Integrated Command Logging
統合テスト用のエージェント（ロギング機能付き）
"""

import sys
import time
import json
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, List, Optional
import random

# Add hooks directory to path
sys.path.append(str(Path(__file__).parent))

from command_logger import CommandLogger

class TestAgentWithLogging:
    """Test agent that demonstrates command logging integration"""
    
    def __init__(self, agent_id: str = "TEST01"):
        self.agent_id = agent_id
        self.log_dir = f"/tmp/claude-code-logs/agent-{agent_id}"
        self.logger = CommandLogger(self.log_dir)
        self.tasks_completed = 0
        
    def log_session_start(self):
        """Log session start"""
        self.logger.log_issue_processing_start(
            "SESSION",
            f"Test Agent {self.agent_id} Session",
            "SESSION_START",
            {"agent_id": self.agent_id, "start_time": datetime.now().isoformat()}
        )
        print(f"📝 Session started for Agent {self.agent_id}")
        
    def simulate_github_api_call(self, endpoint: str) -> Dict[str, Any]:
        """Simulate GitHub API call with logging"""
        cmd = f"gh api {endpoint}"
        
        with self.logger.log_command("GH_API", cmd, {"endpoint": endpoint}):
            print(f"   🌐 Calling GitHub API: {endpoint}")
            time.sleep(random.uniform(0.1, 0.3))  # Simulate network delay
            
            # Simulate response
            if "issues" in endpoint:
                return {"issues": [{"number": 1, "title": "Test Issue"}]}
            elif "user" in endpoint:
                return {"login": "testuser", "name": "Test User"}
            else:
                return {"status": "ok"}
    
    def execute_shell_command(self, command: str) -> str:
        """Execute shell command with logging"""
        with self.logger.log_command("SHELL", command, {"cwd": Path.cwd()}):
            print(f"   💻 Executing: {command}")
            try:
                result = subprocess.run(
                    command, 
                    shell=True, 
                    capture_output=True, 
                    text=True,
                    timeout=5
                )
                if result.returncode != 0:
                    raise Exception(f"Command failed: {result.stderr}")
                return result.stdout
            except Exception as e:
                print(f"   ⚠️  Error: {str(e)}")
                raise
    
    def process_task(self, task_id: str, task_title: str):
        """Process a task with full logging"""
        print(f"\n📋 Processing Task #{task_id}: {task_title}")
        
        # Log task start
        self.logger.log_issue_processing_start(
            task_id,
            task_title,
            "TASK_EXECUTION",
            {"agent": self.agent_id, "priority": "normal"}
        )
        
        try:
            # Simulate task steps
            steps = [
                ("Analyzing task requirements", 0.5),
                ("Fetching related information", 0.3),
                ("Implementing solution", 1.0),
                ("Running tests", 0.8),
                ("Finalizing", 0.2)
            ]
            
            for step_name, duration in steps:
                print(f"   ⏳ {step_name}...")
                time.sleep(duration)
            
            # Simulate some commands during task
            self.execute_shell_command("echo 'Task processing'")
            self.simulate_github_api_call(f"/repos/test/repo/issues/{task_id}")
            
            # Log task completion
            self.logger.log_issue_processing_complete(
                task_id,
                "TASK_EXECUTION",
                {"result": "success", "duration": sum(d for _, d in steps)}
            )
            
            self.tasks_completed += 1
            print(f"   ✅ Task #{task_id} completed successfully")
            
        except Exception as e:
            # Log task error
            self.logger.log_issue_processing_error(
                task_id,
                "TASK_EXECUTION",
                str(e),
                {"agent": self.agent_id}
            )
            print(f"   ❌ Task #{task_id} failed: {str(e)}")
    
    def run_test_loop(self, iterations: int = 3):
        """Run test loop with multiple tasks"""
        print(f"\n🔄 Starting test loop with {iterations} iterations")
        
        self.log_session_start()
        
        # Simulate initial setup
        print("\n📦 Initial setup")
        self.simulate_github_api_call("/user")
        self.execute_shell_command("pwd")
        
        # Process test tasks
        test_tasks = [
            ("101", "Implement feature A"),
            ("102", "Fix bug in module B"),
            ("103", "Add unit tests"),
            ("104", "Update documentation"),
            ("105", "Optimize performance")
        ]
        
        for i in range(min(iterations, len(test_tasks))):
            task_id, task_title = test_tasks[i]
            self.process_task(task_id, task_title)
            
            # Cooldown between tasks
            if i < iterations - 1:
                print("\n⏸️  Cooldown period...")
                time.sleep(1)
        
        # Log session end
        self.logger.log_issue_processing_complete(
            "SESSION",
            "SESSION_END",
            {"tasks_completed": self.tasks_completed, "agent": self.agent_id}
        )
        
        # Display statistics
        self.display_statistics()
        
        # Export logs
        export_path = self.logger.export_logs_to_json(
            f"/tmp/test-agent-{self.agent_id}-export-{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        )
        print(f"\n💾 Logs exported to: {export_path}")
    
    def display_statistics(self):
        """Display command execution statistics"""
        print("\n📊 Command Execution Statistics")
        print("=" * 50)
        
        stats = self.logger.get_command_stats()
        for cmd_type, cmd_stats in stats.items():
            print(f"{cmd_type}:")
            print(f"  - Count: {cmd_stats['count']}")
            print(f"  - Success Rate: {cmd_stats['success_rate']}%")
            print(f"  - Avg Duration: {cmd_stats['avg_duration_ms']:.0f}ms")
            print()

def main():
    """Main test function"""
    print("🧪 Integrated Test: Command Logging + Auto-Loop")
    print("=" * 60)
    print()
    print("This test demonstrates:")
    print("  ✓ Command logging with context managers")
    print("  ✓ Issue processing lifecycle tracking")
    print("  ✓ Automatic error handling and logging")
    print("  ✓ Statistics collection and reporting")
    print("  ✓ Log export functionality")
    print()
    
    # Create and run test agent
    agent = TestAgentWithLogging("TEST01")
    agent.run_test_loop(iterations=3)
    
    print("\n✅ Integrated test completed successfully!")

if __name__ == "__main__":
    main()
EOF

chmod +x "$TEST_DIR/hooks/test-agent-with-logging.py"

# ログビューアスクリプトの作成
step "Creating log viewer script"
cat > "$TEST_DIR/view-logs.sh" << 'EOF'
#!/bin/bash

# Log Viewer Helper Script
echo "📊 Command Logging Viewer"
echo "========================"
echo ""
echo "Select an option:"
echo "1) View recent commands"
echo "2) Follow logs in real-time"
echo "3) Show statistics"
echo "4) View specific agent logs"
echo "5) Export logs to JSON"
echo ""
read -p "Enter option (1-5): " option

HOOKS_DIR="$(dirname "$0")/hooks"
AGENT_ID="TEST01"

case $option in
    1)
        echo "Recent commands:"
        python3 "$HOOKS_DIR/view-command-logs.py" --limit 20
        ;;
    2)
        echo "Following logs (Ctrl+C to stop)..."
        python3 "$HOOKS_DIR/view-command-logs.py" --follow
        ;;
    3)
        echo "Command statistics:"
        python3 "$HOOKS_DIR/view-command-logs.py" --stats
        ;;
    4)
        echo "Agent $AGENT_ID logs:"
        python3 "$HOOKS_DIR/view-command-logs.py" --agent $AGENT_ID -v
        ;;
    5)
        EXPORT_FILE="/tmp/logs-export-$(date +%Y%m%d_%H%M%S).json"
        python3 "$HOOKS_DIR/view-command-logs.py" --export "$EXPORT_FILE"
        echo "Logs exported to: $EXPORT_FILE"
        ;;
    *)
        echo "Invalid option"
        ;;
esac
EOF

chmod +x "$TEST_DIR/view-logs.sh"

# テストの実行
step "Running integrated test"
echo ""
info "Starting test agent with command logging..."
echo ""

cd "$TEST_DIR"
python3 hooks/test-agent-with-logging.py

# 結果の確認
step "Verifying test results"

# ログディレクトリの確認
if [ -d "$LOG_DIR/agent-TEST01" ]; then
    success "Log directory created"
    echo "   Contents:"
    ls -la "$LOG_DIR/agent-TEST01/" | sed 's/^/   /'
else
    error "Log directory not found"
fi

# データベースの確認
if [ -f "$LOG_DIR/agent-TEST01/command_history.db" ]; then
    success "SQLite database created"
    
    # レコード数の確認
    echo ""
    info "Database statistics:"
    sqlite3 "$LOG_DIR/agent-TEST01/command_history.db" << SQL
.headers on
.mode column
SELECT command_type, COUNT(*) as count, 
       ROUND(AVG(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) * 100, 1) as success_rate
FROM command_history
GROUP BY command_type;
SQL
fi

# 完了メッセージ
echo ""
printf '=%.0s' {1..60}; echo
success "Integrated test completed!"
echo ""
echo "📁 Test location: $TEST_DIR"
echo "📊 Log location: $LOG_DIR/agent-TEST01"
echo ""
echo "🔍 To explore the results:"
echo "   1. View logs: $TEST_DIR/view-logs.sh"
echo "   2. Check database: sqlite3 $LOG_DIR/agent-TEST01/command_history.db"
echo "   3. Read exported JSON: cat /tmp/test-agent-*.json"
echo ""
echo "📚 Next steps:"
echo "   - Try the universal agent: python3 /tmp/claude-code-cluster/hooks/universal-agent-auto-loop-with-logging.py"
echo "   - Read the guide: /mnt/c/work/ITDO_ERP2/COMMAND_LOGGING_SETUP_GUIDE.md"
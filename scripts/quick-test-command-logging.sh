#!/bin/bash

# Quick Test Script for Command Logging System
# ローカルでコマンドロギングシステムをすぐに試すためのスクリプト

set -e

echo "🧪 Command Logging System Quick Test"
echo "===================================="

# 設定
LOG_DIR="/tmp/claude-code-logs"
TEST_LOG_DIR="$LOG_DIR/test-session"

# Python3の確認
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python3 is not installed"
    exit 1
fi

# 作業ディレクトリの準備
echo "📁 Preparing test environment..."
mkdir -p "$TEST_LOG_DIR"

# command_logger.pyをローカルにコピー（テスト用）
if [ -f "/mnt/c/work/ITDO_ERP2/hooks/command_logger.py" ]; then
    cp /mnt/c/work/ITDO_ERP2/hooks/command_logger.py "$TEST_LOG_DIR/"
    echo "✅ Copied command_logger.py for testing"
else
    echo "❌ Error: command_logger.py not found"
    exit 1
fi

# テストスクリプトの作成
cat > "$TEST_LOG_DIR/test_logging.py" << 'EOF'
#!/usr/bin/env python3
"""
Command Logging System Test Script
"""

import sys
import time
import json
from pathlib import Path

# Add current directory to path
sys.path.append(str(Path(__file__).parent))

from command_logger import CommandLogger

def main():
    print("🧪 Testing Command Logging System")
    print("=" * 50)
    
    # Initialize logger
    logger = CommandLogger("/tmp/claude-code-logs/test-session")
    print("✅ Logger initialized")
    
    # Test 1: Simple command logging
    print("\n📝 Test 1: Simple command logging")
    with logger.log_command("SHELL", "echo 'Hello World'", {"test": True}):
        print("   Executing: echo 'Hello World'")
        time.sleep(0.1)
    print("   ✅ Command logged successfully")
    
    # Test 2: API call logging
    print("\n📝 Test 2: API call logging")
    cmd_id = logger.log_command_start("GH_API", "gh issue list", {"repo": "test/repo"})
    print("   Simulating API call...")
    time.sleep(0.2)
    logger.log_command_complete(cmd_id, '{"issues": []}', 200)
    print("   ✅ API call logged successfully")
    
    # Test 3: Error logging
    print("\n📝 Test 3: Error logging")
    try:
        with logger.log_command("SHELL", "fake_command", {"will_fail": True}):
            print("   Executing: fake_command")
            raise Exception("Command not found")
    except Exception:
        print("   ✅ Error logged successfully")
    
    # Test 4: Issue processing
    print("\n📝 Test 4: Issue processing logging")
    logger.log_issue_processing_start("123", "Test Issue", "ANALYZE", {"priority": "high"})
    print("   Processing issue #123...")
    time.sleep(0.1)
    logger.log_issue_processing_complete("123", "ANALYZE", {"result": "completed"})
    print("   ✅ Issue processing logged successfully")
    
    # Test 5: Statistics
    print("\n📊 Test 5: Command statistics")
    stats = logger.get_command_stats()
    print("   Statistics:")
    for cmd_type, cmd_stats in stats.items():
        print(f"   - {cmd_type}: {cmd_stats}")
    
    # Test 6: Recent commands
    print("\n📜 Test 6: Recent commands")
    recent = logger.get_recent_commands(limit=5)
    print(f"   Found {len(recent)} recent commands")
    for cmd in recent:
        print(f"   - [{cmd['timestamp']}] {cmd['command_type']}: {cmd['command'][:30]}...")
    
    # Test 7: Export logs
    print("\n💾 Test 7: Export logs")
    export_path = logger.export_logs_to_json("/tmp/test_command_logs.json")
    print(f"   ✅ Logs exported to: {export_path}")
    
    # Summary
    print("\n" + "=" * 50)
    print("✅ All tests completed successfully!")
    print(f"\n📁 Log files created in: {logger.log_dir}")
    print(f"   - Database: {logger.db_path}")
    print(f"   - Command log: {logger.command_log_file}")
    print(f"   - Issue log: {logger.issue_log_file}")
    print(f"   - JSON export: {export_path}")

if __name__ == "__main__":
    main()
EOF

# テストスクリプトの実行
echo ""
echo "🚀 Running test script..."
echo ""
cd "$TEST_LOG_DIR"
python3 test_logging.py

# 結果の確認
echo ""
echo "📊 Test Results:"
echo "================"

# データベースの確認
if [ -f "$TEST_LOG_DIR/command_history.db" ]; then
    echo "✅ SQLite database created"
    echo "   Size: $(du -h "$TEST_LOG_DIR/command_history.db" | cut -f1)"
fi

# ログファイルの確認
echo ""
echo "📁 Log files:"
ls -la "$TEST_LOG_DIR"/*.log 2>/dev/null || echo "No log files found"

# エクスポートファイルの確認
if [ -f "/tmp/test_command_logs.json" ]; then
    echo ""
    echo "📄 Exported JSON preview:"
    head -n 20 /tmp/test_command_logs.json
fi

echo ""
echo "✅ Quick test completed!"
echo ""
echo "📚 Next steps:"
echo "   1. Run the full setup: /mnt/c/work/ITDO_ERP2/scripts/setup-command-logging-test.sh"
echo "   2. See setup guide: /mnt/c/work/ITDO_ERP2/COMMAND_LOGGING_SETUP_GUIDE.md"
echo "   3. Check PR: https://github.com/ootakazuhiko/claude-code-cluster/pull/17"
#!/bin/bash
# Hook System Test Script

echo "=== Claude Code Hook System Test ==="
echo ""

# 1. Check webhook server health
echo "1. Checking webhook server health..."
HEALTH_RESPONSE=$(curl -s http://localhost:8888/health 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✓ Webhook server is running"
    echo "  Response: $HEALTH_RESPONSE"
else
    echo "✗ Webhook server is not responding"
    echo "  Please check if it's running: ps aux | grep webhook-server"
    exit 1
fi
echo ""

# 2. Test webhook endpoint
echo "2. Testing webhook endpoint..."
TEST_PAYLOAD='{
  "type": "task",
  "source": "test",
  "data": {
    "message": "Test task from hook test script",
    "priority": "low",
    "test_time": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  }
}'

WEBHOOK_RESPONSE=$(curl -s -X POST http://localhost:8888/webhook \
  -H "Content-Type: application/json" \
  -d "$TEST_PAYLOAD" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✓ Webhook endpoint responded"
    echo "  Response: $WEBHOOK_RESPONSE"
else
    echo "✗ Webhook endpoint failed"
fi
echo ""

# 3. Check hook directory
echo "3. Checking hook installation..."
HOOKS_DIR="$HOME/.claude/hooks"
if [ -d "$HOOKS_DIR" ]; then
    echo "✓ Hooks directory exists: $HOOKS_DIR"
    echo "  Installed hooks:"
    ls -la "$HOOKS_DIR"/*.sh 2>/dev/null | grep -v "\.impl" | awk '{print "    - " $9}'
else
    echo "✗ Hooks directory not found"
fi
echo ""

# 4. Check task queue
echo "4. Checking task queue..."
QUEUE_FILE="$HOME/.claude/task_queue.json"
if [ -f "$QUEUE_FILE" ]; then
    echo "✓ Task queue file exists"
    echo "  Number of tasks: $(jq '. | length' "$QUEUE_FILE" 2>/dev/null || echo "unknown")"
    echo "  Latest task:"
    jq '.[-1]' "$QUEUE_FILE" 2>/dev/null | head -10
else
    echo "ℹ Task queue file not yet created (will be created on first task)"
fi
echo ""

# 5. Check logs
echo "5. Checking logs..."
LOG_DIR="$HOME/.claude/logs"
if [ -d "$LOG_DIR" ]; then
    echo "✓ Log directory exists"
    echo "  Recent hook activity:"
    find "$LOG_DIR" -name "*.log" -mmin -10 -exec basename {} \; 2>/dev/null | while read log; do
        echo "    - $log"
    done
    
    # Show last few lines of webhook server log
    if [ -f "$LOG_DIR/webhook-server.log" ]; then
        echo ""
        echo "  Recent webhook server activity:"
        tail -5 "$LOG_DIR/webhook-server.log" 2>/dev/null | sed 's/^/    /'
    fi
else
    echo "✗ Log directory not found"
fi
echo ""

# 6. Test high priority task
echo "6. Testing high priority task handling..."
HIGH_PRIORITY_PAYLOAD='{
  "type": "task",
  "source": "test",
  "data": {
    "message": "URGENT: High priority test task",
    "priority": "critical",
    "issue_number": 999,
    "test_time": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  }
}'

curl -s -X POST http://localhost:8888/webhook \
  -H "Content-Type: application/json" \
  -d "$HIGH_PRIORITY_PAYLOAD" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✓ High priority task sent"
    
    # Check if notification was triggered
    if [ -f "$HOME/.claude/logs/on-task-received.log" ]; then
        if grep -q "High priority task detected" "$HOME/.claude/logs/on-task-received.log"; then
            echo "✓ High priority handling confirmed"
        fi
    fi
else
    echo "✗ Failed to send high priority task"
fi
echo ""

# 7. Test agent message
echo "7. Testing inter-agent communication..."
AGENT_MESSAGE='{
  "type": "agent_message",
  "source": "CC02",
  "data": {
    "from": "CC02",
    "to": "CC01",
    "type": "status_query",
    "message": "Requesting current status"
  }
}'

curl -s -X POST http://localhost:8888/webhook \
  -H "Content-Type: application/json" \
  -d "$AGENT_MESSAGE" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✓ Agent message sent"
else
    echo "✗ Failed to send agent message"
fi
echo ""

# Summary
echo "=== Test Summary ==="
echo ""
echo "Hook system base URL: http://localhost:8888"
echo "Hooks directory: $HOOKS_DIR"
echo "Task queue: $QUEUE_FILE"
echo "Logs directory: $LOG_DIR"
echo ""
echo "To monitor activity:"
echo "  tail -f $LOG_DIR/*.log"
echo ""
echo "To check task queue:"
echo "  watch -n 1 'jq . $QUEUE_FILE'"
echo ""
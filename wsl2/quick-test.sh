#!/bin/bash
# Quick test script for Claude Code Cluster

echo "=== Claude Code Cluster Quick Test ==="
echo ""

# Check if installed
if ! command -v claude-cluster &> /dev/null; then
    echo "❌ claude-cluster command not found"
    echo "Run ./install-claude-cluster.sh first"
    exit 1
fi

echo "✅ claude-cluster command found"

# Start cluster
echo ""
echo "Starting cluster..."
claude-cluster start

# Wait for services to start
echo "Waiting for services to start..."
sleep 5

# Check status
echo ""
echo "Checking status..."
claude-cluster status

# Test router
echo ""
echo "Testing central router..."
curl -s http://localhost:8888/health | jq .

# Test task submission
echo ""
echo "Testing task submission..."
cat > /tmp/test-task.json << EOF
{
    "type": "frontend_development",
    "priority": "normal",
    "description": "Test task from quick test script"
}
EOF

claude-cluster task /tmp/test-task.json

echo ""
echo "=== Test Complete ==="
echo ""
echo "To view logs: claude-cluster logs"
echo "To stop cluster: claude-cluster stop"
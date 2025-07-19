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
response=$(curl -s -w "\n%{http_code}" http://localhost:8888/health 2>/dev/null)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [[ "$http_code" -ne 200 ]]; then
    echo "❌ Health endpoint returned HTTP status $http_code"
    echo "$body"
else
    # Try to parse as JSON
    if echo "$body" | python3 -m json.tool > /dev/null 2>&1; then
        echo "✅ Health endpoint returned valid JSON:"
        echo "$body" | python3 -m json.tool
    else
        echo "❌ Health endpoint returned invalid JSON:"
        echo "$body"
    fi
fi

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
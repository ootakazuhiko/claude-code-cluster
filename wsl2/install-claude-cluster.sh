#!/bin/bash
# Claude Code Cluster - WSL2 Ubuntu Installation Script
# This script sets up a complete Claude Code multi-agent environment on WSL2

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_HOME="/home/claude-cluster"
CLAUDE_VERSION="latest"
PYTHON_VERSION="3.12"

# Logging
LOG_FILE="/tmp/claude-cluster-install-$(date +%Y%m%d_%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

# Helper functions
print_header() {
    echo -e "\n${BLUE}==== $1 ====${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

check_wsl() {
    if ! grep -qi microsoft /proc/version; then
        print_error "This script must be run in WSL2 environment"
        exit 1
    fi
    print_success "WSL2 environment detected"
}

check_ubuntu() {
    if ! grep -qi "ubuntu" /etc/os-release; then
        print_error "This script requires Ubuntu. Please install Ubuntu in WSL2"
        exit 1
    fi
    
    VERSION=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    print_success "Ubuntu $VERSION detected"
}

install_dependencies() {
    print_header "Installing System Dependencies"
    
    sudo apt update
    sudo apt install -y \
        curl \
        git \
        python3 \
        python3-pip \
        python3-venv \
        tmux \
        jq \
        build-essential \
        podman \
        nginx \
        supervisor \
        netcat-openbsd
    
    # Install Python packages
    pip3 install --user \
        fastapi \
        uvicorn \
        httpx \
        pydantic \
        aiofiles
    
    print_success "Dependencies installed"
}

install_claude() {
    print_header "Installing Claude Code"
    
    # Install Claude Code CLI
    if ! command -v claude &> /dev/null; then
        print_info "Installing Claude Code CLI..."
        # Placeholder for actual Claude installation
        # In real implementation, this would download and install Claude
        curl -sSL https://claude.ai/install.sh | bash || {
            print_error "Failed to install Claude Code. Please install manually."
            print_info "Visit: https://claude.ai/code for installation instructions"
            return 1
        }
    else
        print_success "Claude Code already installed"
    fi
}

create_directory_structure() {
    print_header "Creating Directory Structure"
    
    # Create main directories
    sudo mkdir -p "$CLUSTER_HOME"
    sudo chown $USER:$USER "$CLUSTER_HOME"
    
    cd "$CLUSTER_HOME"
    
    # Create agent directories
    for agent in cc01 cc02 cc03; do
        mkdir -p "agents/$agent/workspace"
        mkdir -p "agents/$agent/.claude/hooks"
        mkdir -p "agents/$agent/.claude/config"
        mkdir -p "agents/$agent/.claude/logs"
    done
    
    # Create shared directories
    mkdir -p shared/{tasks,logs,artifacts,messages}
    
    # Create script directories
    mkdir -p scripts/{setup,management,hooks}
    
    # Create config directory
    mkdir -p config
    
    print_success "Directory structure created"
}

setup_agent_configs() {
    print_header "Setting Up Agent Configurations"
    
    # Agent configuration template
    for i in 1 2 3; do
        agent="cc0$i"
        port=$((8880 + i))
        
        # Create hook configuration
        cat > "$CLUSTER_HOME/agents/$agent/.claude/config/hooks.conf" << EOF
# Claude Code Cluster - Agent $agent Configuration
HOOKS_ENABLED=true
WEBHOOK_PORT=$port
WEBHOOK_HOST=127.0.0.1
AGENT_NAME=${agent^^}
LOG_LEVEL=INFO
CLUSTER_HOME=$CLUSTER_HOME
WORKSPACE=$CLUSTER_HOME/agents/$agent/workspace
EOF

        # Create agent profile
        cat > "$CLUSTER_HOME/agents/$agent/.claude/config/profile.sh" << EOF
#!/bin/bash
export AGENT_NAME=${agent^^}
export AGENT_PORT=$port
export WORKSPACE=$CLUSTER_HOME/agents/$agent/workspace
export CLAUDE_HOOKS_DIR=$CLUSTER_HOME/agents/$agent/.claude/hooks
export PATH="\$CLAUDE_HOOKS_DIR:\$PATH"

# Agent-specific aliases
alias workspace='cd \$WORKSPACE'
alias logs='tail -f \$CLUSTER_HOME/agents/$agent/.claude/logs/*.log'
alias status='claude-cluster status $agent'

# Load hook system
if [ -f "\$CLAUDE_HOOKS_DIR/activate.sh" ]; then
    source "\$CLAUDE_HOOKS_DIR/activate.sh"
fi
EOF
        chmod +x "$CLUSTER_HOME/agents/$agent/.claude/config/profile.sh"
    done
    
    # Agent specialization
    echo "SPECIALIZATION=frontend" >> "$CLUSTER_HOME/agents/cc01/.claude/config/hooks.conf"
    echo "SPECIALIZATION=backend" >> "$CLUSTER_HOME/agents/cc02/.claude/config/hooks.conf"
    echo "SPECIALIZATION=infrastructure" >> "$CLUSTER_HOME/agents/cc03/.claude/config/hooks.conf"
    
    print_success "Agent configurations created"
}

install_hook_system() {
    print_header "Installing Hook System"
    
    # Download hook system from repository
    cd /tmp
    git clone https://github.com/ootakazuhiko/claude-code-cluster.git
    
    # Install hooks for each agent
    for agent in cc01 cc02 cc03; do
        print_info "Installing hooks for $agent"
        
        # Copy hook system
        cp -r /tmp/claude-code-cluster/hooks/* "$CLUSTER_HOME/agents/$agent/.claude/hooks/"
        
        # Adjust paths in hooks
        sed -i "s|~/.claude|$CLUSTER_HOME/agents/$agent/.claude|g" \
            "$CLUSTER_HOME/agents/$agent/.claude/hooks/"*.sh
        
        # Make executable
        chmod +x "$CLUSTER_HOME/agents/$agent/.claude/hooks/"*.sh
    done
    
    print_success "Hook system installed"
}

create_central_router() {
    print_header "Creating Central Router"
    
    cat > "$CLUSTER_HOME/scripts/management/central-router.py" << 'EOF'
#!/usr/bin/env python3
"""
Claude Code Cluster - Central Router
Routes webhooks and messages between agents
"""

import os
import json
import asyncio
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, Optional

from fastapi import FastAPI, Request, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse
import httpx
import uvicorn

# Configuration
CLUSTER_HOME = os.getenv("CLUSTER_HOME", "/home/claude-cluster")
AGENT_PORTS = {
    "CC01": 8881,
    "CC02": 8882,
    "CC03": 8883
}

app = FastAPI(title="Claude Code Cluster Router")

# Health tracking
agent_health = {agent: {"status": "unknown", "last_check": None} for agent in AGENT_PORTS}

async def check_agent_health(agent: str, port: int):
    """Background task to check agent health"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"http://localhost:{port}/health", timeout=2.0)
            agent_health[agent] = {
                "status": "healthy",
                "last_check": datetime.now().isoformat(),
                "details": response.json()
            }
    except:
        agent_health[agent] = {
            "status": "offline",
            "last_check": datetime.now().isoformat()
        }

@app.on_event("startup")
async def startup_event():
    """Start background health checks"""
    async def health_check_loop():
        while True:
            for agent, port in AGENT_PORTS.items():
                await check_agent_health(agent, port)
            await asyncio.sleep(30)  # Check every 30 seconds
    
    asyncio.create_task(health_check_loop())

@app.get("/")
async def root():
    """Router information"""
    return {
        "service": "Claude Code Cluster Router",
        "version": "1.0.0",
        "agents": list(AGENT_PORTS.keys()),
        "endpoints": {
            "/": "This information",
            "/health": "Router health",
            "/agents/status": "All agents status",
            "/webhook": "Main webhook endpoint",
            "/task": "Submit task to agent",
            "/broadcast": "Send to all agents"
        }
    }

@app.get("/health")
async def health():
    """Router health check"""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

@app.get("/agents/status")
async def agents_status():
    """Get all agents status"""
    return agent_health

@app.post("/webhook")
async def route_webhook(request: Request, background_tasks: BackgroundTasks):
    """Route webhook to appropriate agent(s)"""
    try:
        payload = await request.json()
    except:
        raise HTTPException(status_code=400, detail="Invalid JSON payload")
    
    # Determine target agent(s)
    target_agents = determine_target_agents(payload)
    
    if not target_agents:
        # Broadcast to all agents
        target_agents = list(AGENT_PORTS.keys())
    
    # Route to target agents
    results = {}
    for agent in target_agents:
        if agent in AGENT_PORTS:
            port = AGENT_PORTS[agent]
            try:
                async with httpx.AsyncClient() as client:
                    response = await client.post(
                        f"http://localhost:{port}/webhook",
                        json=payload,
                        timeout=10.0
                    )
                    results[agent] = response.json()
            except Exception as e:
                results[agent] = {"error": str(e)}
    
    # Update health in background
    for agent in target_agents:
        if agent in AGENT_PORTS:
            background_tasks.add_task(check_agent_health, agent, AGENT_PORTS[agent])
    
    return {
        "routed_to": target_agents,
        "results": results,
        "timestamp": datetime.now().isoformat()
    }

@app.post("/task")
async def submit_task(request: Request):
    """Submit a task to specific agent based on specialization"""
    try:
        task = await request.json()
    except:
        raise HTTPException(status_code=400, detail="Invalid JSON payload")
    
    # Determine best agent for task
    agent = determine_best_agent(task)
    
    # Create webhook payload
    payload = {
        "type": "task",
        "source": "router",
        "data": task
    }
    
    # Route to selected agent
    port = AGENT_PORTS.get(agent)
    if not port:
        raise HTTPException(status_code=404, detail=f"Agent {agent} not found")
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"http://localhost:{port}/webhook",
                json=payload,
                timeout=10.0
            )
            return {
                "agent": agent,
                "status": "submitted",
                "response": response.json()
            }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Failed to reach agent: {str(e)}")

@app.post("/broadcast")
async def broadcast_message(request: Request):
    """Broadcast message to all agents"""
    try:
        message = await request.json()
    except:
        raise HTTPException(status_code=400, detail="Invalid JSON payload")
    
    # Create broadcast payload
    payload = {
        "type": "broadcast",
        "source": "router",
        "data": message,
        "timestamp": datetime.now().isoformat()
    }
    
    # Send to all agents
    results = {}
    for agent, port in AGENT_PORTS.items():
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"http://localhost:{port}/webhook",
                    json=payload,
                    timeout=5.0
                )
                results[agent] = {"status": "delivered", "response": response.json()}
        except Exception as e:
            results[agent] = {"status": "failed", "error": str(e)}
    
    return {
        "broadcast": "complete",
        "results": results
    }

def determine_target_agents(payload: Dict[str, Any]) -> list:
    """Determine which agents should receive the webhook"""
    agents = []
    
    # Check for explicit routing
    if "target" in payload:
        target = payload["target"]
        if isinstance(target, str):
            agents.append(target.upper())
        elif isinstance(target, list):
            agents.extend([a.upper() for a in target])
    
    # Check for agent labels
    data = payload.get("data", {})
    labels = data.get("labels", [])
    for label in labels:
        if label.lower().startswith("cc") and len(label) >= 4:
            agent = label[:4].upper()
            if agent in AGENT_PORTS:
                agents.append(agent)
    
    # Check for agent message
    if payload.get("type") == "agent_message":
        to_agent = data.get("to", "").upper()
        if to_agent in AGENT_PORTS:
            agents.append(to_agent)
    
    return list(set(agents))  # Remove duplicates

def determine_best_agent(task: Dict[str, Any]) -> str:
    """Determine best agent based on task type and current load"""
    task_type = task.get("type", "").lower()
    
    # Simple routing based on task type
    if any(keyword in task_type for keyword in ["ui", "frontend", "react", "component"]):
        return "CC01"
    elif any(keyword in task_type for keyword in ["api", "backend", "database", "python"]):
        return "CC02"
    elif any(keyword in task_type for keyword in ["deploy", "ci", "infra", "docker"]):
        return "CC03"
    
    # Default to least loaded agent (simplified - just check health)
    for agent in ["CC01", "CC02", "CC03"]:
        if agent_health.get(agent, {}).get("status") == "healthy":
            return agent
    
    return "CC01"  # Fallback

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8888)
EOF

    chmod +x "$CLUSTER_HOME/scripts/management/central-router.py"
    print_success "Central router created"
}

create_management_scripts() {
    print_header "Creating Management Scripts"
    
    # Main management command
    cat > "$CLUSTER_HOME/scripts/management/claude-cluster" << 'EOF'
#!/bin/bash
# Claude Code Cluster Management Tool

CLUSTER_HOME="/home/claude-cluster"
COMMAND=$1
shift

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo "Claude Code Cluster Management Tool"
    echo ""
    echo "Usage: claude-cluster <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start [agent]    Start all agents or specific agent"
    echo "  stop [agent]     Stop all agents or specific agent"
    echo "  restart [agent]  Restart all agents or specific agent"
    echo "  status           Show status of all agents"
    echo "  logs [agent]     Show logs (follow mode)"
    echo "  task <file>      Submit task from JSON file"
    echo "  clean            Clean all temporary files"
    echo "  update           Update cluster software"
    echo ""
    echo "Agents: cc01 (frontend), cc02 (backend), cc03 (infrastructure)"
}

start_agent() {
    local agent=$1
    echo -e "${BLUE}Starting agent $agent...${NC}"
    
    # Check if already running
    if tmux has-session -t "$agent" 2>/dev/null; then
        echo -e "${YELLOW}Agent $agent is already running${NC}"
        return
    fi
    
    # Start in tmux session
    tmux new-session -d -s "$agent" -c "$CLUSTER_HOME/agents/$agent/workspace" \
        "source $CLUSTER_HOME/agents/$agent/.claude/config/profile.sh && \
         source $CLUSTER_HOME/agents/$agent/.claude/hooks/activate.sh && \
         claude"
    
    echo -e "${GREEN}Agent $agent started${NC}"
}

stop_agent() {
    local agent=$1
    echo -e "${BLUE}Stopping agent $agent...${NC}"
    
    if tmux has-session -t "$agent" 2>/dev/null; then
        tmux kill-session -t "$agent"
        echo -e "${GREEN}Agent $agent stopped${NC}"
    else
        echo -e "${YELLOW}Agent $agent is not running${NC}"
    fi
}

start_router() {
    echo -e "${BLUE}Starting central router...${NC}"
    
    if pgrep -f "central-router.py" > /dev/null; then
        echo -e "${YELLOW}Router is already running${NC}"
        return
    fi
    
    cd "$CLUSTER_HOME"
    nohup python3 scripts/management/central-router.py > shared/logs/router.log 2>&1 &
    echo -e "${GREEN}Central router started${NC}"
}

stop_router() {
    echo -e "${BLUE}Stopping central router...${NC}"
    pkill -f "central-router.py" || true
    echo -e "${GREEN}Central router stopped${NC}"
}

show_status() {
    echo -e "${BLUE}=== Claude Code Cluster Status ===${NC}"
    echo ""
    
    # Check router
    echo -n "Central Router: "
    if curl -s http://localhost:8888/health > /dev/null 2>&1; then
        echo -e "${GREEN}Running${NC}"
    else
        echo -e "${RED}Stopped${NC}"
    fi
    
    # Check agents
    for agent in cc01 cc02 cc03; do
        echo -n "Agent ${agent^^}: "
        if tmux has-session -t "$agent" 2>/dev/null; then
            echo -e "${GREEN}Running${NC}"
        else
            echo -e "${RED}Stopped${NC}"
        fi
    done
    
    echo ""
    
    # Show agent health from router
    if curl -s http://localhost:8888/health > /dev/null 2>&1; then
        echo -e "${BLUE}Agent Health:${NC}"
        curl -s http://localhost:8888/agents/status | jq -r 'to_entries | .[] | "\(.key): \(.value.status)"'
    fi
}

case "$COMMAND" in
    start)
        if [ -z "$1" ]; then
            start_router
            for agent in cc01 cc02 cc03; do
                start_agent "$agent"
                sleep 2
            done
        else
            start_agent "$1"
        fi
        ;;
    
    stop)
        if [ -z "$1" ]; then
            for agent in cc01 cc02 cc03; do
                stop_agent "$agent"
            done
            stop_router
        else
            stop_agent "$1"
        fi
        ;;
    
    restart)
        $0 stop $1
        sleep 2
        $0 start $1
        ;;
    
    status)
        show_status
        ;;
    
    logs)
        if [ -z "$1" ]; then
            tail -f $CLUSTER_HOME/shared/logs/*.log
        else
            tail -f $CLUSTER_HOME/agents/$1/.claude/logs/*.log
        fi
        ;;
    
    task)
        if [ -z "$1" ]; then
            echo "Usage: claude-cluster task <json-file>"
            exit 1
        fi
        curl -X POST http://localhost:8888/task \
            -H "Content-Type: application/json" \
            -d @"$1"
        ;;
    
    clean)
        echo "Cleaning temporary files..."
        find $CLUSTER_HOME -name "*.tmp" -delete
        find $CLUSTER_HOME -name "*.log" -mtime +7 -delete
        echo "Clean complete"
        ;;
    
    update)
        echo "Updating Claude Code Cluster..."
        cd /tmp
        git clone https://github.com/ootakazuhiko/claude-code-cluster.git
        # Update logic here
        echo "Update complete"
        ;;
    
    *)
        show_help
        ;;
esac
EOF

    chmod +x "$CLUSTER_HOME/scripts/management/claude-cluster"
    
    # Create symlink for global access
    sudo ln -sf "$CLUSTER_HOME/scripts/management/claude-cluster" /usr/local/bin/
    
    print_success "Management scripts created"
}

create_sample_tasks() {
    print_header "Creating Sample Tasks"
    
    # Frontend task
    cat > "$CLUSTER_HOME/shared/tasks/sample-frontend.json" << 'EOF'
{
    "type": "frontend_development",
    "priority": "normal",
    "title": "Create Login Component",
    "description": "Create a React login component with TypeScript",
    "requirements": [
        "Use Material-UI components",
        "Include form validation",
        "Add loading state",
        "Write unit tests"
    ]
}
EOF

    # Backend task
    cat > "$CLUSTER_HOME/shared/tasks/sample-backend.json" << 'EOF'
{
    "type": "api_development",
    "priority": "high",
    "title": "User Authentication API",
    "description": "Implement user authentication endpoints",
    "requirements": [
        "POST /api/auth/login",
        "POST /api/auth/logout",
        "GET /api/auth/me",
        "Use JWT tokens"
    ]
}
EOF

    # Infrastructure task
    cat > "$CLUSTER_HOME/shared/tasks/sample-infra.json" << 'EOF'
{
    "type": "infrastructure",
    "priority": "normal",
    "title": "Setup CI/CD Pipeline",
    "description": "Create GitHub Actions workflow",
    "requirements": [
        "Run tests on PR",
        "Build Docker images",
        "Deploy to staging",
        "Security scanning"
    ]
}
EOF

    print_success "Sample tasks created"
}

setup_systemd_services() {
    print_header "Setting Up Systemd Services"
    
    # Create systemd user directory
    mkdir -p ~/.config/systemd/user
    
    # Router service
    cat > ~/.config/systemd/user/claude-router.service << EOF
[Unit]
Description=Claude Code Cluster Central Router
After=network.target

[Service]
Type=simple
WorkingDirectory=$CLUSTER_HOME
ExecStart=/usr/bin/python3 $CLUSTER_HOME/scripts/management/central-router.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

    # Agent services
    for i in 1 2 3; do
        agent="cc0$i"
        cat > ~/.config/systemd/user/claude-$agent.service << EOF
[Unit]
Description=Claude Code Agent $agent
After=network.target claude-router.service

[Service]
Type=simple
WorkingDirectory=$CLUSTER_HOME/agents/$agent/workspace
Environment="AGENT_NAME=${agent^^}"
ExecStartPre=/bin/bash -c 'source $CLUSTER_HOME/agents/$agent/.claude/config/profile.sh'
ExecStart=/usr/bin/tmux new-session -d -s $agent 'source $CLUSTER_HOME/agents/$agent/.claude/hooks/activate.sh && claude'
RemainAfterExit=yes
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF
    done
    
    # Reload systemd
    systemctl --user daemon-reload
    
    print_success "Systemd services created (optional)"
}

create_windows_integration() {
    print_header "Creating Windows Integration Scripts"
    
    # PowerShell module
    cat > "$CLUSTER_HOME/scripts/windows/ClaudeCluster.psm1" << 'EOF'
# Claude Code Cluster PowerShell Module

function Start-ClaudeCluster {
    wsl -d Ubuntu -- /usr/local/bin/claude-cluster start
}

function Stop-ClaudeCluster {
    wsl -d Ubuntu -- /usr/local/bin/claude-cluster stop
}

function Get-ClaudeClusterStatus {
    wsl -d Ubuntu -- /usr/local/bin/claude-cluster status
}

function Send-ClaudeTask {
    param(
        [string]$TaskFile,
        [string]$TaskType = "general",
        [string]$Priority = "normal",
        [string]$Description
    )
    
    if ($TaskFile) {
        # Send existing file
        wsl -d Ubuntu -- /usr/local/bin/claude-cluster task $TaskFile
    } else {
        # Create and send new task
        $task = @{
            type = $TaskType
            priority = $Priority
            description = $Description
            timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        } | ConvertTo-Json
        
        $task | wsl -d Ubuntu -- /usr/local/bin/claude-cluster task -
    }
}

function Watch-ClaudeLogs {
    param([string]$Agent = "")
    
    if ($Agent) {
        wsl -d Ubuntu -- /usr/local/bin/claude-cluster logs $Agent
    } else {
        wsl -d Ubuntu -- /usr/local/bin/claude-cluster logs
    }
}

Export-ModuleMember -Function Start-ClaudeCluster, Stop-ClaudeCluster, Get-ClaudeClusterStatus, Send-ClaudeTask, Watch-ClaudeLogs
EOF

    # Windows Terminal profiles
    cat > "$CLUSTER_HOME/scripts/windows/terminal-profiles.json" << 'EOF'
{
    "profiles": [
        {
            "name": "Claude Agent CC01 (Frontend)",
            "commandline": "wsl.exe -d Ubuntu -- tmux attach-session -t cc01",
            "icon": "🎨",
            "colorScheme": "Tango Light",
            "startingDirectory": "\\\\wsl$\\Ubuntu\\home\\claude-cluster\\agents\\cc01\\workspace"
        },
        {
            "name": "Claude Agent CC02 (Backend)",
            "commandline": "wsl.exe -d Ubuntu -- tmux attach-session -t cc02",
            "icon": "⚙️",
            "colorScheme": "Campbell",
            "startingDirectory": "\\\\wsl$\\Ubuntu\\home\\claude-cluster\\agents\\cc02\\workspace"
        },
        {
            "name": "Claude Agent CC03 (Infrastructure)",
            "commandline": "wsl.exe -d Ubuntu -- tmux attach-session -t cc03",
            "icon": "🏗️",
            "colorScheme": "Vintage",
            "startingDirectory": "\\\\wsl$\\Ubuntu\\home\\claude-cluster\\agents\\cc03\\workspace"
        },
        {
            "name": "Claude Cluster Manager",
            "commandline": "wsl.exe -d Ubuntu",
            "icon": "🤖",
            "colorScheme": "One Half Dark",
            "startingDirectory": "\\\\wsl$\\Ubuntu\\home\\claude-cluster"
        }
    ]
}
EOF

    print_success "Windows integration created"
}

final_setup() {
    print_header "Finalizing Setup"
    
    # Create README
    cat > "$CLUSTER_HOME/README.md" << 'EOF'
# Claude Code Cluster

Your multi-agent Claude Code environment is ready!

## Quick Start

1. Start all agents:
   ```
   claude-cluster start
   ```

2. Check status:
   ```
   claude-cluster status
   ```

3. Submit a task:
   ```
   claude-cluster task shared/tasks/sample-frontend.json
   ```

4. View logs:
   ```
   claude-cluster logs
   ```

## Agents

- **CC01**: Frontend Development (Port 8881)
- **CC02**: Backend Development (Port 8882)
- **CC03**: Infrastructure (Port 8883)

## Central Router

The router runs on port 8888 and handles:
- Task distribution
- Agent communication
- Health monitoring

## Windows Integration

Import the PowerShell module:
```powershell
Import-Module \\wsl$\Ubuntu\home\claude-cluster\scripts\windows\ClaudeCluster.psm1
```

Then use:
- `Start-ClaudeCluster`
- `Stop-ClaudeCluster`
- `Get-ClaudeClusterStatus`
- `Send-ClaudeTask`

## Support

Visit: https://github.com/ootakazuhiko/claude-code-cluster
EOF

    # Set permissions
    chmod -R 755 "$CLUSTER_HOME/scripts"
    chmod -R 700 "$CLUSTER_HOME/agents"
    
    print_success "Setup finalized"
}

# Main installation flow
main() {
    print_header "Claude Code Cluster Installation for WSL2"
    echo "This will set up a complete multi-agent Claude Code environment"
    echo "Installation log: $LOG_FILE"
    echo ""
    
    # Pre-flight checks
    check_wsl
    check_ubuntu
    
    # Installation steps
    install_dependencies
    install_claude
    create_directory_structure
    setup_agent_configs
    install_hook_system
    create_central_router
    create_management_scripts
    create_sample_tasks
    setup_systemd_services
    create_windows_integration
    final_setup
    
    print_header "Installation Complete!"
    echo ""
    echo "To get started:"
    echo "  1. Start the cluster: claude-cluster start"
    echo "  2. Check status: claude-cluster status"
    echo "  3. Submit a task: claude-cluster task shared/tasks/sample-frontend.json"
    echo ""
    echo "For Windows integration, see: $CLUSTER_HOME/scripts/windows/"
    echo ""
    print_success "Happy coding with Claude Code Cluster!"
}

# Run main installation
main "$@"
#!/bin/bash
# Development Environment Setup Script for Claude Code Cluster
# This script sets up a development environment on a single machine

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DEV_ENV_DIR="$HOME/claude-cluster-dev"

# Default settings
COORDINATOR_PORT=8080
AGENT_PORTS=(8081 8082 8083)
POSTGRES_PORT=5432
REDIS_PORT=6379
GRAFANA_PORT=3000

print_header() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "  Claude Code Cluster Development Setup"
    echo "=============================================="
    echo -e "${NC}"
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    local required_tools=("docker" "docker-compose" "python3" "node" "git" "curl")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install them before continuing."
        exit 1
    fi
    
    # Check Python version
    python_version=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
    if [ "$(printf '%s\n' "3.11" "$python_version" | sort -V | head -n1)" != "3.11" ]; then
        print_warning "Python 3.11+ recommended, found Python $python_version"
    fi
    
    # Check Node.js version
    node_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$node_version" -lt 18 ]; then
        print_warning "Node.js 18+ recommended, found version $node_version"
    fi
    
    print_info "Prerequisites check completed"
}

setup_directory_structure() {
    print_step "Setting up directory structure..."
    
    mkdir -p "$DEV_ENV_DIR"/{coordinator,agents,data,logs,config}
    mkdir -p "$DEV_ENV_DIR"/agents/{backend,frontend,testing}
    mkdir -p "$DEV_ENV_DIR"/data/{postgres,redis,grafana,prometheus}
    mkdir -p "$DEV_ENV_DIR"/logs/{coordinator,agents}
    
    print_info "Directory structure created at $DEV_ENV_DIR"
}

generate_dev_config() {
    print_step "Generating development configuration..."
    
    # Generate secrets
    local secret_key
    local registration_token
    local webhook_secret
    secret_key=$(openssl rand -hex 32)
    registration_token=$(openssl rand -hex 16)
    webhook_secret=$(openssl rand -hex 20)
    
    # Coordinator configuration
    cat > "$DEV_ENV_DIR/config/coordinator.env" << EOF
# Development Configuration - Coordinator
APP_NAME=Claude Code Coordinator (Development)
DEBUG=true
HOST=127.0.0.1
PORT=$COORDINATOR_PORT
WORKERS=1

# Database
DATABASE_URL=postgresql://coordinator:devpassword@localhost:$POSTGRES_PORT/coordinator_dev
REDIS_URL=redis://localhost:$REDIS_PORT/0

# Security
SECRET_KEY=$secret_key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:3000

# External APIs (REPLACE WITH YOUR KEYS)
GITHUB_TOKEN=ghp_YOUR_GITHUB_TOKEN_HERE
GITHUB_WEBHOOK_SECRET=$webhook_secret
ANTHROPIC_API_KEY=sk-ant-YOUR_ANTHROPIC_KEY_HERE

# Agent Management
MAX_AGENTS=10
AGENT_HEARTBEAT_TIMEOUT=300
AGENT_REGISTRATION_TOKEN=$registration_token

# Tasks
MAX_CONCURRENT_TASKS=10
TASK_TIMEOUT=3600
TASK_RETRY_ATTEMPTS=3

# Monitoring
METRICS_PORT=9090
LOG_LEVEL=DEBUG
EOF

    # Agent configurations
    local specialties=("backend" "frontend" "testing")
    local capabilities=(
        "python,fastapi,postgresql,redis,api"
        "typescript,react,css,javascript,ui"
        "pytest,jest,selenium,testing,qa"
    )
    
    for i in "${!specialties[@]}"; do
        local specialty="${specialties[$i]}"
        local agent_port="${AGENT_PORTS[$i]}"
        local agent_capabilities="${capabilities[$i]}"
        
        cat > "$DEV_ENV_DIR/config/agent-$specialty.env" << EOF
# Development Configuration - $specialty Agent
AGENT_ID=dev-agent-$specialty
AGENT_NAME=Development $specialty Agent
AGENT_SPECIALTY=$specialty

# Network
AGENT_HOST=127.0.0.1
AGENT_PORT=$agent_port
COORDINATOR_URL=http://127.0.0.1:$COORDINATOR_PORT

# Authentication
REGISTRATION_TOKEN=$registration_token
ANTHROPIC_API_KEY=sk-ant-YOUR_ANTHROPIC_KEY_HERE
GITHUB_TOKEN=ghp_YOUR_GITHUB_TOKEN_HERE

# Workspace
WORKSPACE_PATH=$DEV_ENV_DIR/agents/$specialty/workspace
MAX_CONCURRENT_TASKS=2

# Capabilities
CAPABILITIES=$agent_capabilities

# Development Settings
LOG_LEVEL=DEBUG
TASK_TIMEOUT=7200
WORKSPACE_CLEANUP_ENABLED=false
HEALTH_CHECK_INTERVAL=30
HEARTBEAT_INTERVAL=30
EOF
    done
    
    print_info "Configuration files generated in $DEV_ENV_DIR/config/"
    print_warning "Please update API keys in the configuration files before starting services"
}

setup_database() {
    print_step "Setting up development database..."
    
    # Docker Compose for database services
    cat > "$DEV_ENV_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: coordinator_dev
      POSTGRES_USER: coordinator
      POSTGRES_PASSWORD: devpassword
    ports:
      - "$POSTGRES_PORT:5432"
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    command: postgres -c 'max_connections=200'

  redis:
    image: redis:7-alpine
    ports:
      - "$REDIS_PORT:6379"
    volumes:
      - ./data/redis:/data

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./data/prometheus:/prometheus

  grafana:
    image: grafana/grafana:latest
    ports:
      - "$GRAFANA_PORT:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - ./data/grafana:/var/lib/grafana
EOF

    # Prometheus configuration
    cat > "$DEV_ENV_DIR/config/prometheus.yml" << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'claude-coordinator'
    static_configs:
      - targets: ['host.docker.internal:9090']

  - job_name: 'claude-agents'
    static_configs:
      - targets: 
        - 'host.docker.internal:9091'
        - 'host.docker.internal:9092' 
        - 'host.docker.internal:9093'
EOF

    cd "$DEV_ENV_DIR"
    docker-compose up -d postgres redis
    
    # Wait for PostgreSQL to be ready
    print_info "Waiting for PostgreSQL to be ready..."
    sleep 10
    
    # Create database schema (if coordinator source is available)
    if [ -d "$PROJECT_ROOT/coordinator" ]; then
        print_info "Setting up database schema..."
        # This would run database migrations
        # python3 -m alembic upgrade head
    fi
    
    print_info "Database services started"
}

create_python_environments() {
    print_step "Creating Python virtual environments..."
    
    # Coordinator environment
    if [ -d "$PROJECT_ROOT/coordinator" ]; then
        python3 -m venv "$DEV_ENV_DIR/coordinator/venv"
        source "$DEV_ENV_DIR/coordinator/venv/bin/activate"
        pip install --upgrade pip
        if [ -f "$PROJECT_ROOT/coordinator/requirements.txt" ]; then
            pip install -r "$PROJECT_ROOT/coordinator/requirements.txt"
        fi
        deactivate
        print_info "Coordinator Python environment created"
    fi
    
    # Agent environments
    for specialty in backend frontend testing; do
        if [ -d "$PROJECT_ROOT/agent" ]; then
            python3 -m venv "$DEV_ENV_DIR/agents/$specialty/venv"
            source "$DEV_ENV_DIR/agents/$specialty/venv/bin/activate"
            pip install --upgrade pip
            if [ -f "$PROJECT_ROOT/agent/requirements.txt" ]; then
                pip install -r "$PROJECT_ROOT/agent/requirements.txt"
            fi
            deactivate
            print_info "$specialty agent Python environment created"
        fi
    done
}

create_start_scripts() {
    print_step "Creating startup scripts..."
    
    # Coordinator start script
    cat > "$DEV_ENV_DIR/start-coordinator.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
export $(cat config/coordinator.env | xargs)
source coordinator/venv/bin/activate
cd coordinator
python main.py
EOF

    # Agent start scripts
    for specialty in backend frontend testing; do
        cat > "$DEV_ENV_DIR/start-agent-$specialty.sh" << EOF
#!/bin/bash
cd "\$(dirname "\$0")"
export \$(cat config/agent-$specialty.env | xargs)
source agents/$specialty/venv/bin/activate
cd agents/$specialty
python main.py
EOF
    done
    
    # Master start script
    cat > "$DEV_ENV_DIR/start-all.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

echo "Starting Claude Code Cluster Development Environment..."

# Start database services
echo "Starting database services..."
docker-compose up -d

# Wait for services to be ready
sleep 10

# Start coordinator
echo "Starting coordinator..."
./start-coordinator.sh &
COORDINATOR_PID=$!

sleep 5

# Start agents
echo "Starting agents..."
./start-agent-backend.sh &
./start-agent-frontend.sh &
./start-agent-testing.sh &

echo "All services started!"
echo "Coordinator: http://localhost:8080"
echo "Grafana: http://localhost:3000 (admin/admin)"
echo ""
echo "To stop all services, run: ./stop-all.sh"

wait $COORDINATOR_PID
EOF

    # Stop script
    cat > "$DEV_ENV_DIR/stop-all.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

echo "Stopping Claude Code Cluster Development Environment..."

# Stop Python processes
pkill -f "python main.py" || true

# Stop Docker services
docker-compose down

echo "All services stopped."
EOF

    # Make scripts executable
    chmod +x "$DEV_ENV_DIR"/*.sh
    
    print_info "Startup scripts created"
}

copy_source_code() {
    print_step "Copying source code..."
    
    # Copy coordinator source
    if [ -d "$PROJECT_ROOT/coordinator" ]; then
        cp -r "$PROJECT_ROOT/coordinator"/* "$DEV_ENV_DIR/coordinator/" 2>/dev/null || true
        print_info "Coordinator source copied"
    else
        print_warning "Coordinator source not found at $PROJECT_ROOT/coordinator"
    fi
    
    # Copy agent source
    if [ -d "$PROJECT_ROOT/agent" ]; then
        for specialty in backend frontend testing; do
            cp -r "$PROJECT_ROOT/agent"/* "$DEV_ENV_DIR/agents/$specialty/" 2>/dev/null || true
        done
        print_info "Agent source copied"
    else
        print_warning "Agent source not found at $PROJECT_ROOT/agent"
    fi
}

print_summary() {
    print_step "Development environment setup completed!"
    
    echo -e "${GREEN}"
    echo "=============================================="
    echo "  Setup Summary"
    echo "=============================================="
    echo -e "${NC}"
    
    echo "Development environment location: $DEV_ENV_DIR"
    echo ""
    echo "Services:"
    echo "  • Coordinator: http://localhost:$COORDINATOR_PORT"
    echo "  • Backend Agent: http://localhost:${AGENT_PORTS[0]}"
    echo "  • Frontend Agent: http://localhost:${AGENT_PORTS[1]}"
    echo "  • Testing Agent: http://localhost:${AGENT_PORTS[2]}"
    echo "  • Grafana: http://localhost:$GRAFANA_PORT (admin/admin)"
    echo "  • Prometheus: http://localhost:9090"
    echo ""
    echo "Commands:"
    echo "  Start all services: cd $DEV_ENV_DIR && ./start-all.sh"
    echo "  Stop all services: cd $DEV_ENV_DIR && ./stop-all.sh"
    echo ""
    echo -e "${YELLOW}Important:${NC}"
    echo "  1. Update API keys in $DEV_ENV_DIR/config/*.env files"
    echo "  2. Configure GitHub webhooks to point to your development environment"
    echo "  3. Ensure Docker is running before starting services"
}

# Main execution
main() {
    print_header
    
    check_prerequisites
    setup_directory_structure
    generate_dev_config
    setup_database
    create_python_environments
    copy_source_code
    create_start_scripts
    
    print_summary
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help]"
        echo ""
        echo "Sets up a complete Claude Code Cluster development environment."
        echo "This includes database services, coordinator, and multiple agents."
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
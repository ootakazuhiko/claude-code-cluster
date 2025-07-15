#!/bin/bash

# ITDO ERP System - Comprehensive Test Script
# This script runs all tests and quality checks

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running in container or local environment
check_environment() {
    if [ -f /.dockerenv ]; then
        ENVIRONMENT="container"
        print_status "Running in container environment"
    else
        ENVIRONMENT="local"
        print_status "Running in local environment"
    fi
}

# Setup environment variables
setup_environment() {
    export PATH="$HOME/.local/bin:$PATH"
    export DATABASE_URL="postgresql://itdo_user:itdo_password@localhost:5432/itdo_erp_test"
    export REDIS_URL="redis://localhost:6379"
    export SECRET_KEY="test-secret-key-do-not-use-in-production"
    export DEBUG="true"
}

# Check if data layer services are running
check_services() {
    print_status "Checking data layer services..."
    
    # Check PostgreSQL
    if nc -z localhost 5432; then
        print_success "PostgreSQL is running"
    else
        print_error "PostgreSQL is not running. Please start data layer with: podman-compose -f infra/compose-data.yaml up -d"
        exit 1
    fi
    
    # Check Redis
    if nc -z localhost 6379; then
        print_success "Redis is running"
    else
        print_error "Redis is not running. Please start data layer with: podman-compose -f infra/compose-data.yaml up -d"
        exit 1
    fi
}

# Backend tests
run_backend_tests() {
    print_status "Running backend tests..."
    
    cd backend
    
    # Check if uv is available
    if ! command -v uv &> /dev/null; then
        print_error "uv is not installed. Please install it first."
        exit 1
    fi
    
    # Install dependencies if needed
    if [ ! -d ".venv" ]; then
        print_status "Creating Python virtual environment..."
        uv venv
    fi
    
    print_status "Syncing Python dependencies..."
    uv pip sync requirements-dev.txt
    
    # Type checking
    print_status "Running mypy type checking..."
    if uv run mypy --strict app/; then
        print_success "Type checking passed"
    else
        print_error "Type checking failed"
        exit 1
    fi
    
    # Linting
    print_status "Running ruff linting..."
    if uv run ruff check app/; then
        print_success "Linting passed"
    else
        print_error "Linting failed"
        exit 1
    fi
    
    # Formatting check
    print_status "Checking code formatting..."
    if uv run ruff format --check app/; then
        print_success "Code formatting is correct"
    else
        print_error "Code formatting issues found. Run: cd backend && uv run ruff format app/"
        exit 1
    fi
    
    # Unit tests
    print_status "Running unit tests..."
    if uv run pytest tests/ -v --cov=app --cov-report=term-missing --cov-report=html; then
        print_success "Unit tests passed"
    else
        print_error "Unit tests failed"
        exit 1
    fi
    
    # Security check
    print_status "Running security checks..."
    uv pip install bandit[toml] safety
    
    if uv run bandit -r app/ -f txt; then
        print_success "Security check passed"
    else
        print_warning "Security issues found. Please review."
    fi
    
    if uv run safety check; then
        print_success "Dependency security check passed"
    else
        print_warning "Dependency security issues found. Please review."
    fi
    
    cd ..
}

# Frontend tests
run_frontend_tests() {
    print_status "Running frontend tests..."
    
    cd frontend
    
    # Check if Node.js is available
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install it first."
        exit 1
    fi
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        print_status "Installing Node.js dependencies..."
        npm ci
    fi
    
    # Type checking
    print_status "Running TypeScript type checking..."
    if npm run typecheck; then
        print_success "TypeScript type checking passed"
    else
        print_error "TypeScript type checking failed"
        exit 1
    fi
    
    # Linting
    print_status "Running ESLint..."
    if npm run lint; then
        print_success "ESLint passed"
    else
        print_error "ESLint failed"
        exit 1
    fi
    
    # Unit tests
    print_status "Running unit tests..."
    if npm run coverage; then
        print_success "Frontend unit tests passed"
    else
        print_error "Frontend unit tests failed"
        exit 1
    fi
    
    # Security audit
    print_status "Running npm security audit..."
    if npm audit --audit-level=moderate; then
        print_success "npm security audit passed"
    else
        print_warning "npm security audit found issues. Please review."
    fi
    
    cd ..
}

# E2E tests
run_e2e_tests() {
    print_status "Running E2E tests..."
    
    if [ ! -d "e2e" ]; then
        print_warning "E2E tests directory not found. Skipping E2E tests."
        return 0
    fi
    
    cd e2e
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        print_status "Installing E2E test dependencies..."
        npm ci
        npx playwright install --with-deps
    fi
    
    # Start application services in background for E2E tests
    print_status "Starting application services for E2E tests..."
    
    # Start backend
    cd ../backend
    uv run uvicorn app.main:app --host 0.0.0.0 --port 8000 &
    BACKEND_PID=$!
    sleep 5
    
    # Start frontend
    cd ../frontend
    npm run preview -- --port 3000 &
    FRONTEND_PID=$!
    sleep 5
    
    # Run E2E tests
    cd ../e2e
    if npx playwright test; then
        print_success "E2E tests passed"
        E2E_SUCCESS=true
    else
        print_error "E2E tests failed"
        E2E_SUCCESS=false
    fi
    
    # Cleanup
    print_status "Stopping application services..."
    kill $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
    wait $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
    
    cd ..
    
    if [ "$E2E_SUCCESS" != "true" ]; then
        exit 1
    fi
}

# Generate test reports
generate_reports() {
    print_status "Generating test reports..."
    
    mkdir -p test-reports
    
    # Copy coverage reports
    if [ -f "backend/htmlcov/index.html" ]; then
        cp -r backend/htmlcov test-reports/backend-coverage
        print_success "Backend coverage report available at: test-reports/backend-coverage/index.html"
    fi
    
    if [ -f "frontend/coverage/index.html" ]; then
        cp -r frontend/coverage test-reports/frontend-coverage
        print_success "Frontend coverage report available at: test-reports/frontend-coverage/index.html"
    fi
    
    # Copy E2E reports
    if [ -d "e2e/test-results" ]; then
        cp -r e2e/test-results test-reports/e2e-results
        print_success "E2E test results available at: test-reports/e2e-results/"
    fi
    
    if [ -d "e2e/playwright-report" ]; then
        cp -r e2e/playwright-report test-reports/e2e-report
        print_success "E2E test report available at: test-reports/e2e-report/index.html"
    fi
}

# Main execution
main() {
    print_status "Starting comprehensive test suite..."
    
    # Parse command line arguments
    RUN_BACKEND=true
    RUN_FRONTEND=true
    RUN_E2E=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --backend-only)
                RUN_FRONTEND=false
                RUN_E2E=false
                shift
                ;;
            --frontend-only)
                RUN_BACKEND=false
                RUN_E2E=false
                shift
                ;;
            --e2e-only)
                RUN_BACKEND=false
                RUN_FRONTEND=false
                shift
                ;;
            --no-e2e)
                RUN_E2E=false
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --backend-only   Run only backend tests"
                echo "  --frontend-only  Run only frontend tests"
                echo "  --e2e-only       Run only E2E tests"
                echo "  --no-e2e         Skip E2E tests"
                echo "  --help           Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    check_environment
    setup_environment
    
    if [ "$RUN_BACKEND" == "true" ] || [ "$RUN_E2E" == "true" ]; then
        check_services
    fi
    
    START_TIME=$(date +%s)
    
    if [ "$RUN_BACKEND" == "true" ]; then
        run_backend_tests
    fi
    
    if [ "$RUN_FRONTEND" == "true" ]; then
        run_frontend_tests
    fi
    
    if [ "$RUN_E2E" == "true" ]; then
        run_e2e_tests
    fi
    
    generate_reports
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    print_success "All tests completed successfully in ${DURATION} seconds!"
    print_status "Test reports generated in test-reports/ directory"
}

# Run main function with all arguments
main "$@"
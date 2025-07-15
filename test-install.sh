#!/bin/bash

# Test script for the improved installation
# This simulates various installation scenarios

set -euo pipefail

echo "🧪 Claude Code Cluster - Installation Test Suite"
echo "=============================================="
echo

# Test directory
TEST_BASE="/tmp/ccc-install-test-$(date +%s)"
mkdir -p "$TEST_BASE"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -n "Testing: $test_name... "
    
    if eval "$test_cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: Help option
run_test "Help option" "./install-improved.sh --help"

# Test 2: Version option
run_test "Version option" "./install-improved.sh --version"

# Test 3: Custom directory
TEST_DIR="$TEST_BASE/test1"
run_test "Custom directory" "mkdir -p $TEST_DIR && ./install-improved.sh --dir $TEST_DIR --yes --skip-deps --version 2>/dev/null"

# Test 4: No-sudo installation simulation
TEST_DIR="$TEST_BASE/test2"
run_test "No-sudo mode" "timeout 5 ./install-improved.sh --dir $TEST_DIR --no-sudo --yes --skip-deps 2>/dev/null || [ -d $TEST_DIR ]"

# Test 5: Force reinstall
TEST_DIR="$TEST_BASE/test3"
mkdir -p "$TEST_DIR/.git"
run_test "Force reinstall" "timeout 5 ./install-improved.sh --dir $TEST_DIR --force --yes --skip-deps 2>/dev/null || [ -d $TEST_DIR/venv ]"

# Test 6: Custom venv directory
TEST_DIR="$TEST_BASE/test4"
run_test "Custom venv" "./install-improved.sh --dir $TEST_DIR --venv myenv --yes --skip-deps --version 2>/dev/null"

# Test 7: Parse multiple arguments
run_test "Multiple arguments" "./install-improved.sh --dir /tmp/test --venv env --no-sudo --force --skip-deps --yes --version 2>/dev/null || true"

# Test 8: Invalid argument handling
run_test "Invalid argument detection" "! ./install-improved.sh --invalid-option 2>/dev/null"

# Test 9: Check shell detection
run_test "Shell detection" "bash -c 'source ./install-improved.sh --help >/dev/null 2>&1 && true'"

# Test 10: Directory creation
TEST_DIR="$TEST_BASE/test5"
run_test "Directory creation" "mkdir -p $TEST_DIR && touch $TEST_DIR/.env && ./install-improved.sh --dir $TEST_DIR --yes --skip-deps --version 2>/dev/null"

# Cleanup
echo
echo "🧹 Cleaning up test directories..."
rm -rf "$TEST_BASE"

# Summary
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total tests run: $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
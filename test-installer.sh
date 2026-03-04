#!/bin/bash
# Test script for the shell installer
# This script performs basic validation of the installer

set -euo pipefail

echo "=== Tool Installer Test Suite ==="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"

    echo -n "Testing: $test_name... "

    if eval "$test_command" 2>/dev/null; then
        echo -e "${GREEN}✓ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 1: Check if installer script exists
run_test "Installer script exists" "[[ -f install-tools.sh ]]"

# Test 2: Check if installer script is executable
run_test "Installer script is executable" "[[ -x install-tools.sh ]]"

# Test 3: Check if tools.yaml exists
run_test "Tools configuration exists" "[[ -f config/tools.yaml ]]"

# Test 4: Check if Ansible playbook exists
run_test "Ansible playbook exists" "[[ -f config/ansible/playbook.yml ]]"

# Test 5: Check if at least one Ansible role exists
run_test "Ansible roles directory exists" "[[ -d config/ansible/roles ]]"

# Test 6: Verify script has proper shebang
run_test "Script has bash shebang" "head -n1 install-tools.sh | grep -q '^#!/bin/bash'"

# Test 7: Check for required functions in script
run_test "Script contains check_and_install_dependencies" "grep -q 'check_and_install_dependencies()' install-tools.sh"
run_test "Script contains show_tool_selection" "grep -q 'show_tool_selection()' install-tools.sh"
run_test "Script contains run_installation" "grep -q 'run_installation()' install-tools.sh"
run_test "Script contains main function" "grep -q 'main()' install-tools.sh"

# Test 8: Verify YAML structure
if command -v yq &>/dev/null; then
    run_test "YAML has tools section" "yq '.tools' config/tools.yaml | grep -q 'git:'"
else
    run_test "YAML has tools section" "grep -q '^tools:' config/tools.yaml"
fi

# Test 9: Check for macOS platform check
run_test "Script includes macOS check" "grep -q 'uname.*Darwin' install-tools.sh"

# Test 10: Check for log file creation
run_test "Script creates log file" "grep -q 'LOG_FILE=' install-tools.sh"

echo ""
echo "=== Test Results ==="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
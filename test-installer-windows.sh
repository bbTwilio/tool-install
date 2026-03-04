#!/bin/bash
# Test script for validating the installer on Windows
# This performs static analysis and structural validation

set -euo pipefail

echo "=== Tool Installer Validation Suite (Windows) ==="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"

    echo -n "Testing: $test_name... "

    if eval "$test_command" 2>/dev/null; then
        echo -e "${GREEN}✓ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to skip a test
skip_test() {
    local test_name="$1"
    echo -e "Testing: $test_name... ${YELLOW}⊘ SKIPPED (Windows environment)${NC}"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

echo "=== File Structure Tests ==="

# Test 1: Check if installer script exists
run_test "Installer script exists" "[[ -f install-tools.sh ]]"

# Test 2: Check if installer script has correct permissions
if [[ "$(uname -s)" == *"NT"* ]] || [[ "$(uname -s)" == "MINGW"* ]]; then
    skip_test "Installer script is executable"
else
    run_test "Installer script is executable" "[[ -x install-tools.sh ]]"
fi

# Test 3: Check if tools.yaml exists
run_test "Tools configuration exists" "[[ -f config/tools.yaml ]]"

# Test 4: Check if Ansible playbook exists
run_test "Ansible playbook exists" "[[ -f config/ansible/playbook.yml ]]"

# Test 5: Check if Ansible roles directory exists
run_test "Ansible roles directory exists" "[[ -d config/ansible/roles ]]"

# Test 6: Count Ansible roles
ROLE_COUNT=$(ls -d config/ansible/roles/*/ 2>/dev/null | wc -l)
run_test "Has at least 3 Ansible roles" "[[ $ROLE_COUNT -ge 3 ]]"
echo "  → Found $ROLE_COUNT roles"

echo ""
echo "=== Script Structure Tests ==="

# Test 7: Verify script has proper shebang
run_test "Script has bash shebang" "head -n1 install-tools.sh | grep -q '^#!/bin/bash'"

# Test 8: Check for required functions
run_test "Has check_and_install_dependencies function" "grep -q 'check_and_install_dependencies()' install-tools.sh"
run_test "Has load_tool_data function" "grep -q 'load_tool_data()' install-tools.sh"
run_test "Has detect_installed_tools function" "grep -q 'detect_installed_tools()' install-tools.sh"
run_test "Has show_tool_selection function" "grep -q 'show_tool_selection()' install-tools.sh"
run_test "Has run_installation function" "grep -q 'run_installation()' install-tools.sh"
run_test "Has main function" "grep -q 'main()' install-tools.sh"

echo ""
echo "=== Configuration Tests ==="

# Test 9: Verify YAML structure
run_test "YAML has tools section" "grep -q '^tools:' config/tools.yaml"
run_test "YAML has git tool" "grep -q '  git:' config/tools.yaml"
run_test "YAML has aws_cli tool" "grep -q '  aws_cli:' config/tools.yaml"
run_test "YAML has nodejs tool" "grep -q '  nodejs:' config/tools.yaml"

# Test 10: Check Ansible playbook structure
run_test "Playbook has localhost host" "grep -q 'hosts: localhost' config/ansible/playbook.yml"
run_test "Playbook includes tool roles" "grep -q 'include_role:' config/ansible/playbook.yml"

echo ""
echo "=== Script Safety Tests ==="

# Test 11: Check for safety features
run_test "Script uses set -euo pipefail" "grep -q 'set -euo pipefail' install-tools.sh"
run_test "Script has macOS platform check" "grep -q 'uname.*Darwin' install-tools.sh"
run_test "Script has trap for Ctrl+C" "grep -q 'trap.*INT' install-tools.sh"
run_test "Script creates log file" "grep -q 'LOG_FILE=' install-tools.sh"

echo ""
echo "=== Dependency Handling Tests ==="

# Test 12: Check for dependency installations
run_test "Checks for Homebrew" "grep -q 'command -v brew' install-tools.sh"
run_test "Checks for gum" "grep -q 'command -v gum' install-tools.sh"
run_test "Checks for Ansible" "grep -q 'command -v ansible-playbook' install-tools.sh"
run_test "Has Homebrew installation command" "grep -q 'Homebrew/install/HEAD/install.sh' install-tools.sh"

echo ""
echo "=== UI Component Tests ==="

# Test 13: Check for gum UI components
run_test "Uses gum confirm" "grep -q 'gum confirm' install-tools.sh"
run_test "Uses gum choose" "grep -q 'gum choose' install-tools.sh"
run_test "Uses gum style" "grep -q 'gum style' install-tools.sh"
run_test "Uses gum spin" "grep -q 'gum spin' install-tools.sh"

echo ""
echo "=== Function Logic Tests ==="

# Test 14: Extract and test individual functions
echo "Testing function extraction and syntax..."

# Extract get_tool_ids function
sed -n '/^get_tool_ids()/,/^}/p' install-tools.sh > /tmp/test_func.sh
run_test "get_tool_ids function is valid bash" "bash -n /tmp/test_func.sh"

# Extract main function
sed -n '/^main()/,/^}$/p' install-tools.sh > /tmp/test_main.sh
run_test "main function is valid bash" "bash -n /tmp/test_main.sh"

echo ""
echo "=== Script Size and Complexity ==="

# Test 15: Check script metrics
LINE_COUNT=$(wc -l < install-tools.sh)
echo "Script lines: $LINE_COUNT"
run_test "Script is reasonable size (<500 lines)" "[[ $LINE_COUNT -lt 500 ]]"

FUNCTION_COUNT=$(grep -c '() {$' install-tools.sh || true)
echo "Function count: $FUNCTION_COUNT"
run_test "Has adequate functions (>8)" "[[ $FUNCTION_COUNT -gt 8 ]]"

echo ""
echo "=== Documentation Tests ==="

# Test 16: Check for documentation
run_test "README exists" "[[ -f README.md ]]"
run_test "README mentions gum" "grep -qi 'gum' README.md"
run_test "README mentions Ansible" "grep -qi 'ansible' README.md"
run_test "README has usage section" "grep -q '## Usage' README.md"

echo ""
echo "=== YAML Parsing Test ==="

# Test 17: Simulate YAML parsing with awk (since yq may not be available)
echo "Testing YAML parsing logic..."

# Test the awk-based tool extraction
TOOLS_EXTRACTED=$(awk '/^tools:/{flag=1; next} flag && /^  [a-z_]+:/{gsub(/:/, "", $1); print $1}' config/tools.yaml | wc -l)
run_test "Can extract tools from YAML (found $TOOLS_EXTRACTED)" "[[ $TOOLS_EXTRACTED -gt 5 ]]"

# Test property extraction
TEST_TOOL="git"
TEST_PROP=$(awk -v tool="$TEST_TOOL" -v prop="name" '
    $0 ~ "^  " tool ":$" {in_tool=1; next}
    in_tool && /^  [a-z_]+:$/ {exit}
    in_tool && $0 ~ "^    " prop ":" {
        sub(/^[[:space:]]+/, "")
        sub(prop ":[[:space:]]*", "")
        gsub(/["'"'"']/, "")
        print
        exit
    }
' config/tools.yaml)

run_test "Can extract tool properties (git name: '$TEST_PROP')" "[[ '$TEST_PROP' == 'Git' ]]"

echo ""
echo "=== Syntax Validation ==="

# Test 18: Bash syntax check
run_test "Script passes bash syntax check" "bash -n install-tools.sh"

# Test 19: Check for common shell scripting issues
echo "Checking for common issues..."
run_test "No use of deprecated backticks" "! grep -q '\`' install-tools.sh"
run_test "Uses [[ instead of [" "grep -q '\[\[' install-tools.sh"
run_test "Quotes variables properly" "grep -q '\"\$' install-tools.sh"

echo ""
echo "==================================="
echo "=== Final Test Results Summary ==="
echo "==================================="
echo -e "Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:  ${RED}$TESTS_FAILED${NC}"
echo -e "Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ All tests passed! The installer script is valid and well-structured.${NC}"
    echo ""
    echo "Note: This validation was performed on Windows."
    echo "The script will only run fully on macOS due to platform-specific features."
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Please review the issues above.${NC}"
    exit 1
fi
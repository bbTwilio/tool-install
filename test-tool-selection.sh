#!/bin/bash
# Test script for tool selection bug fix
# This script helps verify that the tool selection is working correctly
#
# Usage: chmod +x test-tool-selection.sh && ./test-tool-selection.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}    Tool Selection Bug Fix Test Script${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: This test requires macOS${NC}"
    exit 1
fi

# Check bash version
echo "Bash version: ${BASH_VERSION}"
echo ""

# Test 1: Array passing in subshells
echo -e "${YELLOW}Test 1: Array passing in subshells${NC}"
test_array=("item1" "item2" "item3")
echo "Original array: ${test_array[*]}"

# Test with here-string (problematic in Bash 3.2 with local)
result1=$(while read -r item; do
    echo "Processing: $item"
done <<< "${test_array[*]}")
echo "Here-string result: Works"

# Test with temp file (our fix approach)
temp_file="/tmp/test-$$"
printf '%s\n' "${test_array[@]}" > "$temp_file"
result2=$(while read -r item; do
    echo "Processing: $item"
done < "$temp_file")
rm -f "$temp_file"
echo "Temp file result: Works"
echo ""

# Test 2: Function array access
echo -e "${YELLOW}Test 2: Function array access${NC}"
global_array=("tool1" "tool2" "tool3")

test_function() {
    echo "Inside function - array size: ${#global_array[@]}"
    echo "Inside function - array contents: ${global_array[*]}"

    if [[ ${#global_array[@]} -eq 0 ]]; then
        echo "ERROR: Array is empty inside function!"
        return 1
    fi

    local json="["
    local first=true
    for item in "${global_array[@]}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            json+=","
        fi
        json+="\"$item\""
    done
    json+="]"
    echo "Generated JSON: $json"
}

test_function
echo ""

# Test 3: Check log file
echo -e "${YELLOW}Test 3: Checking debug logs${NC}"
LOG_FILE="/tmp/tool-installer-test-$(date +%Y%m%d-%H%M%S).log"

# Create a test log entry
echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST: Debug logging is working" > "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: tools_to_install: tool1 tool2 tool3" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: build_tool_actions called" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: Final JSON array: [{\"name\":\"tool1\",\"action\":\"install\"}]" >> "$LOG_FILE"

if [[ -f "$LOG_FILE" ]]; then
    echo "Log file created successfully: $LOG_FILE"
    echo "Sample log entries:"
    tail -n 3 "$LOG_FILE"
else
    echo -e "${RED}ERROR: Could not create log file${NC}"
fi
echo ""

# Test 4: Run the actual installer in dry-run mode
echo -e "${YELLOW}Test 4: Running installer in dry-run mode${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/install-tools.sh" ]]; then
    echo "Found install-tools.sh"
    echo "You can run: ./install-tools.sh --dry-run"
    echo "Then check the log file for DEBUG entries"
else
    echo -e "${RED}install-tools.sh not found in current directory${NC}"
fi
echo ""

echo -e "${GREEN}✓ Basic tests completed${NC}"
echo ""
echo "To fully test the fix:"
echo "1. Run: ./install-tools.sh"
echo "2. Select one or more tools"
echo "3. Check the log file (shown at the end) for DEBUG entries"
echo "4. Look for these key debug messages:"
echo "   - 'DEBUG: Processing selected item:'"
echo "   - 'DEBUG: Adding tool to install list:'"
echo "   - 'DEBUG: build_tool_actions called'"
echo "   - 'DEBUG: Final JSON array:'"
echo ""
echo "The bug is FIXED if:"
echo "  ✓ Tools appear in 'Final tools_to_install:' debug message"
echo "  ✓ build_tool_actions shows non-empty array in debug"
echo "  ✓ JSON passed to Ansible contains your selected tools"
echo ""
echo "The bug is STILL PRESENT if:"
echo "  ✗ 'Final tools_to_install:' shows empty"
echo "  ✗ build_tool_actions returns '[]'"
echo "  ✗ Ansible receives empty selected_tools"
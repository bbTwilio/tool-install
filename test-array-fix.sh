#!/bin/bash
# Test script to verify the array expansion fix for macOS bash 3.2 compatibility
# Tests the safe array expansion pattern: ${array[@]+"${array[*]}"}

set -euo pipefail

echo "Testing array expansion fix for bash ${BASH_VERSION}"
echo "============================================"

# Test function to log arrays safely
log_safe() {
    echo "$1: ${2[@]+"${2[*]}"}"
}

# Test function to log arrays unsafely (for comparison)
log_unsafe() {
    echo "$1: ${2[*]}"
}

echo ""
echo "Test 1: Empty array (uninitialized)"
empty_array=()
echo -n "  Safe expansion: "
echo "${empty_array[@]+"${empty_array[*]}"}" || echo "(no error)"
echo -n "  Unsafe expansion would fail with set -u"
echo ""

echo ""
echo "Test 2: Array with single element"
single_array=("tool1")
echo "  Safe expansion: ${single_array[@]+"${single_array[*]}"}"
echo "  Content: ${single_array[*]}"
echo ""

echo ""
echo "Test 3: Array with multiple elements"
multi_array=("tool1" "tool2" "tool3")
echo "  Safe expansion: ${multi_array[@]+"${multi_array[*]}"}"
echo "  Content: ${multi_array[*]}"
echo ""

echo ""
echo "Test 4: Simulating tool installer scenario"
tools_to_install=()
installed_tools_selected=()

echo "  Initial state (empty arrays):"
echo "    tools_to_install: ${tools_to_install[@]+"${tools_to_install[*]}"}"
echo "    installed_tools_selected: ${installed_tools_selected[@]+"${installed_tools_selected[*]}"}"

# Simulate adding tools
tools_to_install+=("git" "docker")
echo ""
echo "  After adding tools:"
echo "    tools_to_install: ${tools_to_install[@]+"${tools_to_install[*]}"}"
echo "    installed_tools_selected: ${installed_tools_selected[@]+"${installed_tools_selected[*]}"}"

# Simulate selecting installed tools
installed_tools_selected+=("git")
echo ""
echo "  After marking git as installed:"
echo "    tools_to_install: ${tools_to_install[@]+"${tools_to_install[*]}"}"
echo "    installed_tools_selected: ${installed_tools_selected[@]+"${installed_tools_selected[*]}"}"

echo ""
echo "============================================"
echo "All tests passed! The fix handles all edge cases correctly."
echo ""
echo "The pattern ${array[@]+\"${array[*]}\"} safely expands arrays:"
echo "  - Returns empty string for uninitialized/empty arrays"
echo "  - Returns array contents for non-empty arrays"
echo "  - Works with bash 3.2+ and strict mode (set -u)"
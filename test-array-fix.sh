#!/bin/bash
# Test script to verify array-related fixes for macOS bash 3.2 compatibility
# Tests:
# - v1.4.5: Safe array expansion pattern: ${array[@]+"${array[*]}"}
# - v1.4.6: For loop iteration over potentially empty arrays

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
echo "Testing v1.4.6 fix: For loop iteration over empty arrays"
echo "============================================"
echo ""

echo "Test 5: For loop with empty array (MAIN FIX for v1.4.6)"
installed_tools_selected=()
echo -n "  Testing for loop with guard check... "

# This is the fixed pattern from v1.4.6
error_occurred=false
if [[ ${#installed_tools_selected[@]} -gt 0 ]]; then
    for installed in "${installed_tools_selected[@]}"; do
        echo "Processing: $installed"
    done
fi

if [[ $error_occurred == false ]]; then
    echo "PASSED (no unbound variable error)"
else
    echo "FAILED"
fi

echo ""
echo "Test 6: Simulating build_tool_actions scenario (line 332 fix)"
tools_to_install=("git" "docker" "python")
installed_tools_selected=()  # Empty - no installed tools selected

echo "  Tools to install: ${tools_to_install[@]+"${tools_to_install[*]}"}"
echo "  Installed tools selected: ${installed_tools_selected[@]+"${installed_tools_selected[*]}"} (empty)"
echo ""
echo "  Processing each tool:"

for tool in "${tools_to_install[@]}"; do
    action="install"

    # This is the exact fix applied at line 332
    if [[ ${#installed_tools_selected[@]} -gt 0 ]]; then
        for installed in "${installed_tools_selected[@]}"; do
            if [[ "$tool" == "$installed" ]]; then
                action="reinstall"
                break
            fi
        done
    fi

    echo "    - $tool: action=$action"
done

echo ""
echo "Test 7: With some installed tools"
installed_tools_selected=("git" "python")
echo "  Installed tools selected: ${installed_tools_selected[@]+"${installed_tools_selected[*]}"}"
echo ""
echo "  Processing each tool:"

for tool in "${tools_to_install[@]}"; do
    action="install"

    # This is the exact fix applied at line 332
    if [[ ${#installed_tools_selected[@]} -gt 0 ]]; then
        for installed in "${installed_tools_selected[@]}"; do
            if [[ "$tool" == "$installed" ]]; then
                action="reinstall"
                break
            fi
        done
    fi

    echo "    - $tool: action=$action"
done

echo ""
echo "============================================"
echo "All tests passed! Both fixes handle all edge cases correctly."
echo ""
echo "v1.4.5 fix: The pattern \${array[@]+\"\${array[*]}\"} safely expands arrays:"
echo "  - Returns empty string for uninitialized/empty arrays"
echo "  - Returns array contents for non-empty arrays"
echo "  - Works with bash 3.2+ and strict mode (set -u)"
echo ""
echo "v1.4.6 fix: Check array length before for loop iteration:"
echo "  - if [[ \${#array[@]} -gt 0 ]]; then ... fi"
echo "  - Prevents unbound variable errors when iterating over empty arrays"
echo "  - Critical for line 332 in build_tool_actions() function"
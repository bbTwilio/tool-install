#!/bin/bash
# Test script for reinstall feature

set -euo pipefail

echo "Testing Tool Reinstall Feature"
echo "==============================="

# Test 1: Check if installed tools are selectable
echo "Test 1: Checking if git (installed) appears in selection..."
# Check if we're on macOS first
if [[ "$(uname)" != "Darwin" ]]; then
    echo "! Not running on macOS, skipping UI test"
    echo "  (Script would show installed tools with ✓ prefix on macOS)"
else
    # Run in non-interactive mode to test the UI building
    output=$(timeout 1 ./install-tools.sh 2>&1 || true)
    if echo "$output" | grep -q "✓.*Git.*installed"; then
        echo "✓ Installed tools shown correctly"
    else
        # Check if git is actually installed first
        if command -v git &>/dev/null; then
            echo "✗ Failed to show installed Git with checkmark"
            echo "Output received:"
            echo "$output" | head -n 20
            exit 1
        else
            echo "! Git is not installed, skipping this test"
        fi
    fi
fi

# Test 2: Check build_tool_actions function exists
echo ""
echo "Test 2: Checking if build_tool_actions function is defined..."
if grep -q "build_tool_actions()" install-tools.sh; then
    echo "✓ build_tool_actions function found"
else
    echo "✗ build_tool_actions function not found"
    exit 1
fi

# Test 3: Check prompt_reinstall_action function exists
echo ""
echo "Test 3: Checking if prompt_reinstall_action function is defined..."
if grep -q "prompt_reinstall_action()" install-tools.sh; then
    echo "✓ prompt_reinstall_action function found"
else
    echo "✗ prompt_reinstall_action function not found"
    exit 1
fi

# Test 4: Check if playbook handles tool_action variable
echo ""
echo "Test 4: Checking if playbook supports tool actions..."
if grep -q "tool_action:" config/ansible/playbook.yml; then
    echo "✓ Playbook supports tool_action variable"
else
    echo "✗ Playbook does not support tool_action variable"
    exit 1
fi

# Test 5: Check if roles support reinstall
echo ""
echo "Test 5: Checking if roles support reinstall action..."
roles_with_reinstall=0
for role_file in config/ansible/roles/*/tasks/main.yml; do
    if grep -q "tool_action.*reinstall" "$role_file"; then
        roles_with_reinstall=$((roles_with_reinstall + 1))
    fi
done

if [[ $roles_with_reinstall -gt 0 ]]; then
    echo "✓ $roles_with_reinstall roles support reinstall action"
else
    echo "✗ No roles support reinstall action"
    exit 1
fi

# Test 6: Syntax check
echo ""
echo "Test 6: Checking shell script syntax..."
if bash -n install-tools.sh; then
    echo "✓ Shell script syntax is valid"
else
    echo "✗ Shell script has syntax errors"
    exit 1
fi

echo ""
echo "==============================="
echo "All tests passed!"
echo ""
echo "Manual test instructions:"
echo "1. Run: ./install-tools.sh"
echo "2. Select an installed tool (should show with ✓ prefix)"
echo "3. Confirm you get prompted to choose between 'Upgrade' and 'Force reinstall'"
echo "4. Test both options work correctly"
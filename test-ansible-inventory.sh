#!/bin/bash

# Test script to verify Ansible inventory configuration fix
# This tests that the inventory parsing warnings are resolved

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="${SCRIPT_DIR}/config/ansible"

echo "Testing Ansible inventory configuration..."
echo "==========================================="
echo ""

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Error: Ansible is not installed. Please install Ansible first."
    echo "   You can use: brew install ansible"
    exit 1
fi

# Test the Ansible configuration
cd "$ANSIBLE_DIR"
echo "Running Ansible test with new inventory configuration..."
echo ""

# Run a simple Ansible ping test with verbose output to catch any warnings
ANSIBLE_CONFIG=./ansible.cfg ansible -m ping localhost -vv 2>&1 | tee /tmp/ansible-test.log

echo ""
echo "Checking for inventory parsing warnings..."
echo ""

# Check if there are any inventory parsing warnings in the output
if grep -q "WARNING.*Unable to parse.*as an inventory source" /tmp/ansible-test.log; then
    echo "❌ FAILED: Inventory parsing warnings detected!"
    echo ""
    echo "Warnings found:"
    grep "WARNING.*Unable to parse" /tmp/ansible-test.log
    exit 1
else
    echo "✅ SUCCESS: No inventory parsing warnings detected!"
fi

echo ""
echo "Testing playbook execution..."
echo ""

# Test running the actual playbook with a dummy tool selection
ANSIBLE_CONFIG=./ansible.cfg ansible-playbook playbook.yml \
    -e '{"selected_tools": [{"name": "claude_code", "role": "claude", "action": "install"}]}' \
    --check -vv 2>&1 | tee /tmp/ansible-playbook-test.log

echo ""
echo "Checking playbook for inventory warnings..."
echo ""

if grep -q "WARNING.*Unable to parse.*as an inventory source" /tmp/ansible-playbook-test.log; then
    echo "❌ FAILED: Inventory parsing warnings detected in playbook run!"
    echo ""
    echo "Warnings found:"
    grep "WARNING.*Unable to parse" /tmp/ansible-playbook-test.log
    exit 1
else
    echo "✅ SUCCESS: Playbook runs without inventory parsing warnings!"
fi

echo ""
echo "==========================================="
echo "✅ All tests passed! The inventory configuration is working correctly."
echo ""
echo "Configuration details:"
echo "  - Inventory file: ${ANSIBLE_DIR}/inventory"
echo "  - Config file: ${ANSIBLE_DIR}/ansible.cfg"
echo "  - Inventory setting: inventory = ./inventory"

# Clean up temp files
rm -f /tmp/ansible-test.log /tmp/ansible-playbook-test.log
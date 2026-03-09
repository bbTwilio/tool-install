#!/bin/bash

# Test script for automated Zscaler certificate configuration
# This script verifies that the Zscaler certificate automation works correctly

set -e

echo "================================================"
echo "Zscaler Certificate Automation Test"
echo "================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test 1: Check if certificate directory exists or can be created
echo "Test 1: Checking certificate directory..."
if [ -d "$HOME/cert" ]; then
    echo -e "${GREEN}✓${NC} Certificate directory exists: $HOME/cert"
else
    echo -e "${YELLOW}→${NC} Certificate directory will be created by Ansible"
fi
echo ""

# Test 2: Search for Zscaler certificate in keychains
echo "Test 2: Searching for Zscaler Root CA in system keychains..."
CERT_FOUND=false
CERT_CONTENT=""

# Try SystemRootCertificates keychain
if security find-certificate -c "Zscaler Root CA" /System/Library/Keychains/SystemRootCertificates.keychain 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Found in SystemRootCertificates.keychain"
    CERT_FOUND=true
    CERT_CONTENT=$(security find-certificate -c "Zscaler Root CA" -p /System/Library/Keychains/SystemRootCertificates.keychain 2>/dev/null)
# Try System keychain
elif security find-certificate -c "Zscaler Root CA" /Library/Keychains/System.keychain 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Found in System.keychain"
    CERT_FOUND=true
    CERT_CONTENT=$(security find-certificate -c "Zscaler Root CA" -p /Library/Keychains/System.keychain 2>/dev/null)
# Try login keychain
elif security find-certificate -c "Zscaler Root CA" ~/Library/Keychains/login.keychain-db 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Found in login.keychain"
    CERT_FOUND=true
    CERT_CONTENT=$(security find-certificate -c "Zscaler Root CA" -p ~/Library/Keychains/login.keychain-db 2>/dev/null)
else
    echo -e "${RED}✗${NC} Zscaler Root CA certificate not found in any keychain"
    echo -e "${YELLOW}ℹ${NC} This is expected if you're not behind a Zscaler proxy"
fi
echo ""

# Test 3: Check if we can export the certificate
if [ "$CERT_FOUND" = true ]; then
    echo "Test 3: Testing certificate export..."
    TEMP_CERT="/tmp/test_zscaler_cert.pem"
    echo "$CERT_CONTENT" > "$TEMP_CERT"

    if [ -f "$TEMP_CERT" ] && [ -s "$TEMP_CERT" ]; then
        echo -e "${GREEN}✓${NC} Certificate can be exported to PEM format"

        # Test 4: Validate certificate format
        echo ""
        echo "Test 4: Validating certificate format..."
        if openssl x509 -in "$TEMP_CERT" -text -noout >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Certificate is valid PEM format"

            # Show certificate details
            echo ""
            echo "Certificate Details:"
            openssl x509 -in "$TEMP_CERT" -noout -subject -issuer -dates | sed 's/^/  /'
        else
            echo -e "${RED}✗${NC} Certificate validation failed"
        fi

        # Clean up temp file
        rm -f "$TEMP_CERT"
    else
        echo -e "${RED}✗${NC} Failed to export certificate"
    fi
else
    echo "Test 3: Skipping certificate export test (no certificate found)"
fi
echo ""

# Test 5: Check if AWS CLI is installed
echo "Test 5: Checking AWS CLI installation..."
if command -v aws >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} AWS CLI is installed: $(aws --version 2>&1)"
else
    echo -e "${YELLOW}→${NC} AWS CLI not installed (will be installed by Ansible)"
fi
echo ""

# Test 6: Check current shell configuration
echo "Test 6: Checking shell configuration..."
SHELL_CONFIGS=("$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.bash_profile")
CONFIG_FOUND=false

for config in "${SHELL_CONFIGS[@]}"; do
    if [ -f "$config" ]; then
        if grep -q "AWS_CA_BUNDLE" "$config" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} AWS_CA_BUNDLE found in $config"
            CONFIG_FOUND=true
        else
            echo -e "${YELLOW}→${NC} AWS_CA_BUNDLE not in $config (will be added by Ansible)"
        fi
    fi
done

if [ "$CONFIG_FOUND" = false ]; then
    echo -e "${YELLOW}ℹ${NC} AWS_CA_BUNDLE not configured yet (will be configured by Ansible)"
fi
echo ""

# Test 7: Simulate the Ansible automation
echo "Test 7: Simulating Ansible automation..."
echo "The Ansible playbook will:"
echo "  1. Create ~/cert directory if it doesn't exist"
echo "  2. Search for 'Zscaler Root CA' in system keychains"
if [ "$CERT_FOUND" = true ]; then
    echo "  3. Export the certificate to ~/cert/zscaler_root.pem"
    echo "  4. Add 'export AWS_CA_BUNDLE=~/cert/zscaler_root.pem' to shell profiles"
    echo "  5. Test AWS CLI connectivity"
    echo -e "${GREEN}✓${NC} Automation should work successfully"
else
    echo "  3. Skip certificate configuration (no Zscaler certificate found)"
    echo -e "${YELLOW}ℹ${NC} AWS CLI will work without certificate configuration"
fi
echo ""

# Summary
echo "================================================"
echo "Test Summary"
echo "================================================"
if [ "$CERT_FOUND" = true ]; then
    echo -e "${GREEN}✓${NC} Zscaler certificate found and can be automated"
    echo ""
    echo "Next steps:"
    echo "1. Run the installer: ./install-tools.sh"
    echo "2. Select 'AWS CLI' from the menu"
    echo "3. The certificate will be automatically configured"
    echo "4. Run 'source ~/.zshrc' to apply changes"
    echo "5. Test with: aws sts get-caller-identity"
else
    echo -e "${YELLOW}ℹ${NC} No Zscaler certificate found (not behind Zscaler proxy)"
    echo ""
    echo "The AWS CLI will be installed without certificate configuration."
    echo "This is normal if you're not using Zscaler proxy."
fi
echo "================================================"
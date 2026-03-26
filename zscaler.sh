#!/bin/bash
#
# Zscaler Developer Environment Configuration Script (macOS)
#
# This script configures a macOS developer environment to trust the
# organization's central Zscaler CA bundle.
#
# It MUST be run with sudo, as it modifies the System Keychain and
# potentially system-level config files (like php.ini).
#
# This script is idempotent and can be re-run safely.
#

# --- Configuration ---
# This is the single source of truth for the certificate bundle path.
CA_BUNDLE_PATH="/etc/ssl/certs/ca-bundle.pem"

# --- Script Start ---

# 1. Check for Root Permissions
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run this script with sudo."
  echo "Usage: sudo ./zscaler.sh"
  exit 1
fi

cp zscalerrootcerts/* /etc/ssl/certs

# 2. Check if the CA Bundle Exists
if [ ! -f "$CA_BUNDLE_PATH" ]; then
  echo "ERROR: The CA bundle was not found at the expected location:"
  echo "$CA_BUNDLE_PATH"
  echo "Please ensure the bundle is in place before running this script."
  exit 1
fi

# 3. Find the currently logged-in user (not 'root')
CURRENT_USER=$(stat -f "%Su" /dev/console)
USER_HOME=$(eval echo "~$CURRENT_USER")

if [ -z "$CURRENT_USER" ] || [ -z "$USER_HOME" ]; then
    echo "ERROR: Could not determine a logged-in user. Exiting."
    exit 1
fi

echo "Configuring system for user: $CURRENT_USER (Home: $USER_HOME)"

# 4. Add Certificate to macOS System Keychain
echo "Configuring macOS System Keychain..."
# This makes the cert trusted for all apps that use the native trust store [1, 2]
security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CA_BUNDLE_PATH"

# 5. Configure Shell Environment Variables
echo "Configuring shell environments (.zshrc,.bash_profile)..."

# Define the target shell configuration files
TARGET_SHELL_FILES=("$USER_HOME/.zshrc" "$USER_HOME/.bash_profile")

# Create files if they don't exist and set correct ownership
for profile in "${TARGET_SHELL_FILES[@]}"; do
    touch "$profile"
    chown "$CURRENT_USER" "$profile"
done

# This helper function removes old entries and adds the new one.
add_to_shell_configs() {
  local line_to_add="$1"
  local variable_name="$2"

  echo "-> Setting $variable_name..."
  for profile in "${TARGET_SHELL_FILES[@]}"; do
    # Remove any old entries for this variable
    sed -i '' "/export $variable_name=/d" "$profile"
    # Add the new, correct entry
    echo "$line_to_add" >> "$profile"
  done
}

# Add all required environment variables
add_to_shell_configs "export SSL_CERT_FILE=$CA_BUNDLE_PATH" "SSL_CERT_FILE"
add_to_shell_configs "export REQUESTS_CA_BUNDLE=$CA_BUNDLE_PATH" "REQUESTS_CA_BUNDLE"
add_to_shell_configs "export NODE_EXTRA_CA_CERTS=$CA_BUNDLE_PATH" "NODE_EXTRA_CA_CERTS"
add_to_shell_configs "export CURL_CA_BUNDLE=$CA_BUNDLE_PATH" "CURL_CA_BUNDLE"
add_to_shell_configs "export AWS_CA_BUNDLE=$CA_BUNDLE_PATH" "AWS_CA_BUNDLE"

# 6. Configure Git
echo "Configuring Git..."
# This command must be run as the user, not as root
sudo -u "$CURRENT_USER" git config --global http.sslCAInfo "$CA_BUNDLE_PATH"

# 7. Configure PHP (Composer, cURL, etc.)
echo "Configuring PHP..."
# Find the active php.ini file, running the command as the user
PHP_INI_PATH=$(sudo -u "$CURRENT_USER" php --ini | grep "Loaded Configuration File:" | awk '{print $4}')

if [ -n "$PHP_INI_PATH" ] && [ -f "$PHP_INI_PATH" ]; then
  echo "-> Found php.ini at: $PHP_INI_PATH"
  
  # 1. Remove existing (commented or uncommented)
  sed -i '' -e "/^openssl.cafile=/d" -e "/^;openssl.cafile=/d" "$PHP_INI_PATH"
  
  # 2. Add the correct new line.
  echo "openssl.cafile = $CA_BUNDLE_PATH" >> "$PHP_INI_PATH"
  
  echo "-> Successfully set openssl.cafile."
else
  echo "-> WARNING: 'php --ini' did not report a loaded config file. Skipping PHP."
fi

# 8. Configure Xcode Simulator
echo "Configuring Xcode Simulator..."
# This adds the cert to the keychain of the *currently booted* simulator.
# It will fail silently if no simulator is booted, which is acceptable.
sudo -u "$CURRENT_USER" xcrun simctl keychain booted add-root-cert "$CA_BUNDLE_PATH" 2>/dev/null
echo "-> Xcode Simulator configuration attempted."
echo "-> If no simulator was booted, run this command after booting one:"
echo "   xcrun simctl keychain booted add-root-cert $CA_BUNDLE_PATH"

echo -e "\n---"
echo "Zscaler Developer Configuration Complete."
echo "Please restart your terminal sessions for changes to take effect."
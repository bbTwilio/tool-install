#!/bin/bash
# macOS Tool Installer with Gum UI
# This script provides an interactive interface for installing development tools on macOS
# using gum for the UI and Ansible for the backend installation logic
# Compatible with bash 3.2+ (default macOS bash)

set -euo pipefail

# Version information
SCRIPT_VERSION="1.5.4"
SCRIPT_DATE="2026-03-23"

# Configuration paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_YAML="${SCRIPT_DIR}/config/tools.yaml"
ANSIBLE_DIR="${SCRIPT_DIR}/config/ansible"
PLAYBOOK="${ANSIBLE_DIR}/playbook.yml"
LOG_FILE="/tmp/tool-installer-$(date +%Y%m%d-%H%M%S).log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Arrays for tool data (using parallel arrays for bash 3.2 compatibility)
ALL_TOOLS=()
TOOL_NAMES=()
TOOL_DESCRIPTIONS=()
TOOL_CATEGORIES=()
TOOL_COMMANDS=()
TOOL_INSTALLED=()
TOOL_DOCS=()
TOOL_ROLES=()  # Array for Ansible role names

# Arrays for tracking user selections
tools_to_install=()
installed_tools_selected=()

# Function to find array index of a tool
get_tool_index() {
    local tool_id="$1"
    local i
    for i in "${!ALL_TOOLS[@]}"; do
        if [[ "${ALL_TOOLS[$i]}" == "$tool_id" ]]; then
            echo "$i"
            return 0
        fi
    done
    return 1
}

# Function to get tool role by index
get_tool_role() {
    local tool=$1
    local idx=$(get_tool_index "$tool")
    if [[ $idx -ge 0 ]]; then
        echo "${TOOL_ROLES[$idx]}"
    else
        echo "$tool"  # Fallback to tool ID
    fi
}

# Function to get tool property by index
get_tool_prop() {
    local tool_id="$1"
    local prop="$2"
    local idx=$(get_tool_index "$tool_id")

    case "$prop" in
        name) echo "${TOOL_NAMES[$idx]}" ;;
        description) echo "${TOOL_DESCRIPTIONS[$idx]}" ;;
        category) echo "${TOOL_CATEGORIES[$idx]}" ;;
        command) echo "${TOOL_COMMANDS[$idx]}" ;;
        installed) echo "${TOOL_INSTALLED[$idx]}" ;;
        docs) echo "${TOOL_DOCS[$idx]}" ;;
    esac
}

# Function to set tool as installed
set_tool_installed() {
    local tool_id="$1"
    local idx=$(get_tool_index "$tool_id")
    TOOL_INSTALLED[$idx]=1
}

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Function to open tool documentation in browser
open_tool_docs() {
    local tool_name=$1
    local tool_url=$2

    if [[ -n "$tool_url" ]]; then
        if gum confirm "Open $tool_name documentation in browser?"; then
            open "$tool_url" 2>/dev/null || {
                echo "Could not open browser automatically"
                echo "Documentation URL: $tool_url"
            }
        fi
    fi
}

# Function to check and install dependencies
check_and_install_dependencies() {
    local deps_installed=false

    # Check for Homebrew
    if ! command -v brew &>/dev/null; then
        echo "Homebrew is not installed."
        if gum confirm "Install Homebrew?"; then
            gum spin --spinner dot --title "Installing Homebrew..." -- \
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

            # Add Homebrew to PATH for this session (for Apple Silicon Macs)
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
            deps_installed=true
        else
            echo -e "${RED}Error: Homebrew is required to proceed.${NC}"
            exit 1
        fi
    fi

    # Check for gum
    if ! command -v gum &>/dev/null; then
        echo "Installing gum (terminal UI toolkit)..."
        brew install gum
        deps_installed=true
    fi

    # Check for Ansible
    if ! command -v ansible-playbook &>/dev/null; then
        echo "Installing Ansible..."
        brew install ansible
        deps_installed=true
    fi

    # Check for yq (YAML processor)
    if ! command -v yq &>/dev/null; then
        echo "Installing yq (YAML processor)..."
        brew install yq
        deps_installed=true
    fi

    if [[ "$deps_installed" == true ]]; then
        echo -e "${GREEN}Dependencies installed successfully!${NC}"
    fi
}

# Function to get tool property from YAML
get_tool_property() {
    local tool=$1
    local property=$2
    local value
    value=$(yq eval ".tools.${tool}.${property}" "$TOOLS_YAML" 2>/dev/null || echo "")
    # Handle yq returning the literal string "null" for non-existent fields
    if [[ "$value" == "null" ]]; then
        echo ""
    else
        echo "$value"
    fi
}

# Function to load tools from YAML
load_tools() {
    local tools_list tools_array

    # Get list of tools, filtering out metadata groups
    tools_list=$(yq eval '.tools | keys | .[]' "$TOOLS_YAML" 2>/dev/null | \
                 grep -v -E '^(essential|cloud|full|ansible|homebrew|ui|logging)$')

    # Convert to array
    IFS=$'\n' read -d '' -r -a tools_array <<< "$tools_list" || true

    for tool in "${tools_array[@]}"; do
        # Skip empty lines
        [[ -z "$tool" ]] && continue

        # Get tool properties
        local tool_name="$(get_tool_property "$tool" "name")"
        local tool_desc="$(get_tool_property "$tool" "description")"
        local tool_cat="$(get_tool_property "$tool" "category")"
        local tool_cmd="$(get_tool_property "$tool" "command")"

        # Get role name (default to tool ID if not specified)
        local tool_role="$(get_tool_property "$tool" "install_methods[0].role")"
        # Check for both empty string and literal "null" from yq
        if [[ -z "$tool_role" ]] || [[ "$tool_role" == "null" ]]; then
            tool_role="$tool"  # Fallback to tool ID for backward compatibility
        fi

        # Add to arrays
        ALL_TOOLS+=("$tool")
        TOOL_NAMES+=("$tool_name")
        TOOL_DESCRIPTIONS+=("$tool_desc")
        TOOL_CATEGORIES+=("$tool_cat")
        TOOL_COMMANDS+=("$tool_cmd")
        TOOL_INSTALLED+=(0)
        TOOL_ROLES+=("$tool_role")

        # Set documentation URLs
        local doc_url=""
        case "$tool" in
            github_ssh) doc_url="https://docs.github.com/en/authentication/connecting-to-github-with-ssh" ;;
            aws_configure_sso) doc_url="https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html" ;;
            claude_code) doc_url="https://code.claude.com/docs/en/quickstart" ;;
            zscaler_cert) doc_url="https://help.zscaler.com/zia/certificate-pinning" ;;
        esac
        TOOL_DOCS+=("$doc_url")

        log_message "Loaded tool: $tool - $tool_name"
    done
}

# Function to detect installed tools
detect_installed_tools() {
    local i
    for i in "${!ALL_TOOLS[@]}"; do
        local cmd="${TOOL_COMMANDS[$i]}"
        if [[ -n "$cmd" ]] && command -v "$cmd" &>/dev/null; then
            TOOL_INSTALLED[$i]=1
            log_message "Detected installed: ${ALL_TOOLS[$i]}"
        fi
    done
}

# Function to build tool selection list
build_tool_list() {
    local tool_list=()
    local preselected=()

    local i
    for i in "${!ALL_TOOLS[@]}"; do
        local tool="${ALL_TOOLS[$i]}"
        local name="${TOOL_NAMES[$i]}"
        local desc="${TOOL_DESCRIPTIONS[$i]}"
        local category="${TOOL_CATEGORIES[$i]}"

        # Build display string
        local display="[$category] $name - $desc"

        if [[ "${TOOL_INSTALLED[$i]}" == "1" ]]; then
            # Show installed tools with checkmark but still selectable
            display="✓ $display (installed)"
        else
            # Pre-select uninstalled tools by default
            preselected+=("$display")
        fi

        tool_list+=("$display")
    done

    # Build the gum command with proper --selected flags
    local gum_cmd=(gum choose --no-limit --header "Select tools to install/re-install (Space to toggle, Enter to confirm):")

    # Add each preselected item as a separate --selected flag
    for item in "${preselected[@]}"; do
        gum_cmd+=(--selected "$item")
    done

    # Output tool list and execute gum command
    printf "%s\n" "${tool_list[@]}" | "${gum_cmd[@]}"
}

# Function to extract tool ID from display string
extract_tool_id() {
    local display_string="$1"
    log_message "DEBUG: extract_tool_id called with: $display_string"

    # Remove checkmark if present
    display_string="${display_string#✓ }"
    # Extract the name part between [] and -
    local name_part="${display_string#*] }"
    name_part="${name_part%% -*}"

    log_message "DEBUG: Extracted name part: $name_part"

    # Find matching tool
    local i
    for i in "${!TOOL_NAMES[@]}"; do
        if [[ "${TOOL_NAMES[$i]}" == "$name_part" ]]; then
            log_message "DEBUG: Found matching tool: ${ALL_TOOLS[$i]} at index $i"
            echo "${ALL_TOOLS[$i]}"
            return 0
        fi
    done

    log_message "WARNING: No matching tool found for name: $name_part"
    return 1
}

# Function to prompt for reinstall action
prompt_reinstall_action() {
    local tool_id="$1"
    local idx=$(get_tool_index "$tool_id")
    local tool_name="${TOOL_NAMES[$idx]}"

    echo ""
    echo "Tool '$tool_name' is already installed."
    local action=$(gum choose \
        --header "Choose action for $tool_name:" \
        "Upgrade to latest version" \
        "Force reinstall (remove and reinstall)")

    if [[ "$action" == "Upgrade to latest version" ]]; then
        echo "upgrade"
    else
        echo "reinstall"
    fi
}

# Function to build tool action array for Ansible
build_tool_actions() {
    # Debug: Log entry to function and array size
    log_message "DEBUG: build_tool_actions called"
    log_message "DEBUG: tools_to_install size: ${#tools_to_install[@]}"
    log_message "DEBUG: tools_to_install contents: ${tools_to_install[@]+"${tools_to_install[*]}"}"
    log_message "DEBUG: installed_tools_selected size: ${#installed_tools_selected[@]}"
    log_message "DEBUG: installed_tools_selected contents: ${installed_tools_selected[@]+"${installed_tools_selected[*]}"}"

    local json_array="["
    local first=true
    local tool_count=0

    # Explicitly check if array is empty
    if [[ ${#tools_to_install[@]} -eq 0 ]]; then
        log_message "WARNING: tools_to_install is empty in build_tool_actions"
        echo "[]"
        return
    fi

    for tool in "${tools_to_install[@]}"; do
        log_message "DEBUG: Processing tool: $tool"
        tool_count=$((tool_count + 1))
        local action="install"

        # Check if this tool is installed
        if [[ ${#installed_tools_selected[@]} -gt 0 ]]; then
            for installed in "${installed_tools_selected[@]}"; do
                if [[ "$tool" == "$installed" ]]; then
                    log_message "DEBUG: Tool $tool is installed, prompting for action"
                    action=$(prompt_reinstall_action "$tool")
                    log_message "DEBUG: Selected action for $tool: $action"
                    break
                fi
            done
        fi

        if [[ "$first" == true ]]; then
            first=false
        else
            json_array+=","
        fi

        # Get the role name for this tool
        local role=$(get_tool_role "$tool")
        json_array+="{\"name\":\"$tool\",\"role\":\"$role\",\"action\":\"$action\"}"
        log_message "DEBUG: Added to JSON: {\"name\":\"$tool\",\"role\":\"$role\",\"action\":\"$action\"}"
    done

    json_array+="]"
    log_message "DEBUG: Final JSON array: $json_array"
    log_message "DEBUG: Processed $tool_count tools"
    echo "$json_array"
}

# Function to install tools using Ansible
install_tools() {
    # Uses global arrays: tools_to_install and installed_tools_selected

    log_message "DEBUG: install_tools called"
    log_message "DEBUG: tools_to_install at start: ${#tools_to_install[@]} items"
    log_message "DEBUG: tools_to_install contents: ${tools_to_install[@]+"${tools_to_install[*]}"}"
    log_message "DEBUG: installed_tools_selected at start: ${#installed_tools_selected[@]} items"

    if [[ ${#tools_to_install[@]} -eq 0 ]]; then
        echo "No tools selected for installation."
        log_message "DEBUG: Exiting install_tools - no tools selected"
        return 0
    fi

    # Show reinstall/upgrade notifications
    if [[ ${#installed_tools_selected[@]} -gt 0 ]]; then
        echo ""
        echo "The following installed tools will be processed:"
        for tool in "${installed_tools_selected[@]}"; do
            local idx=$(get_tool_index "$tool")
            local name="${TOOL_NAMES[$idx]}"
            echo "  • $name (action will be selected)"
        done
        echo ""
    fi

    echo -e "${BLUE}Installing selected tools using Ansible...${NC}"
    log_message "Starting Ansible installation for: ${tools_to_install[@]+"${tools_to_install[*]}"}"

    # Debug: Print arrays right before calling build_tool_actions
    log_message "DEBUG: Right before build_tool_actions - tools_to_install: ${tools_to_install[@]+"${tools_to_install[*]}"}"
    log_message "DEBUG: Right before build_tool_actions - array size: ${#tools_to_install[@]}"

    # Build tool actions JSON
    local tools_json=$(build_tool_actions)

    log_message "DEBUG: build_tool_actions returned: $tools_json"

    # Ensure tools_json is valid, default to empty array if not
    if [[ -z "$tools_json" ]] || [[ "$tools_json" == "" ]]; then
        log_message "Warning: build_tool_actions returned empty, using default empty array"
        tools_json="[]"
    fi

    # Additional validation - ensure it starts with [ and ends with ]
    if [[ ! "$tools_json" =~ ^\[.*\]$ ]]; then
        log_message "Warning: Invalid JSON from build_tool_actions: $tools_json"
        tools_json="[]"
    fi

    # Create the extra vars JSON object
    local extra_vars="{\"selected_tools\": $tools_json}"

    # Log the JSON being passed to Ansible for debugging
    log_message "Passing to Ansible: $extra_vars"

    # Install Ansible collections if requirements file exists
    if [[ -f "${ANSIBLE_DIR}/requirements.yml" ]]; then
        log_message "Installing Ansible collections..."
        ansible-galaxy collection install --ignore-certs -r "${ANSIBLE_DIR}/requirements.yml" --force >> "$LOG_FILE" 2>&1
    fi

    # Run Ansible playbook with spinner (set ANSIBLE_CONFIG to use our config file)
    ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" gum spin --spinner dot --title "Running Ansible playbook..." -- \
        ansible-playbook "$PLAYBOOK" \
        -e "$extra_vars" \
        -vv >> "$LOG_FILE" 2>&1

    local result=$?

    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✓ Installation completed successfully!${NC}"
        log_message "Ansible installation completed successfully"
        return 0
    else
        echo -e "${RED}✗ Installation failed. Check the log for details: $LOG_FILE${NC}"
        log_message "Ansible installation failed with exit code: $result"
        return 1
    fi
}

# Function to show post-installation instructions
show_post_install_instructions() {
    local tools_installed=("$@")

    if [[ ${#tools_installed[@]} -eq 0 ]]; then
        return
    fi

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}Post-Installation Instructions${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"

    for tool in "${tools_installed[@]}"; do
        local idx=$(get_tool_index "$tool")
        local name="${TOOL_NAMES[$idx]}"

        case "$tool" in
            github_ssh)
                echo -e "${YELLOW}GitHub SSH:${NC}"
                echo "  To complete GitHub SSH setup:"
                echo "    1. Your SSH key has been generated (if needed)"
                echo "    2. Run: gh auth login"
                echo "    3. Choose SSH authentication when prompted"
                ;;
            aws_configure_sso)
                echo -e "${YELLOW}AWS SSO Configuration:${NC}"
                echo "  To test AWS SSO configuration:"
                echo "    1. Run: aws sso login"
                ;;
            claude_code)
                echo -e "${YELLOW}Claude Code:${NC}"
                echo "  Update Claude:"
                echo "    claude update"
                ;;
            zscaler_cert)
                echo -e "${YELLOW}ZScaler Certificate:${NC}"
                echo "  Your ZScaler certificate has been configured for AWS CLI."
                echo "  To apply the changes:"
                echo "    1. Restart your terminal, OR"
                echo "    2. Run: source ~/.zshrc"
                echo "  To verify:"
                echo "    Run: echo \$AWS_CA_BUNDLE"
                ;;
        esac

        # Offer to open documentation
        local doc_url="${TOOL_DOCS[$idx]}"
        if [[ -n "$doc_url" ]]; then
            open_tool_docs "$name" "$doc_url"
        fi
    done

    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
}

# Function to run installer in dry-run mode
dry_run() {
    echo -e "${YELLOW}Running in DRY-RUN mode (no changes will be made)${NC}"
    log_message "Dry-run mode activated"

    load_tools
    detect_installed_tools

    echo ""
    echo "Available tools:"
    local i
    for i in "${!ALL_TOOLS[@]}"; do
        local status="[ ]"
        if [[ "${TOOL_INSTALLED[$i]}" == "1" ]]; then
            status="[✓]"
        fi
        echo "  $status ${TOOL_NAMES[$i]}"
    done
}

# Setup ZScaler certificate for corporate proxy SSL/TLS trust
setup_zscaler_cert() {
    # Only run on macOS where ZScaler is relevant
    if ! security find-certificate -c "Zscaler Root CA" /Library/Keychains/System.keychain >/dev/null 2>&1 && \
       ! security find-certificate -c "Zscaler Root CA" /System/Library/Keychains/SystemRootCertificates.keychain >/dev/null 2>&1; then
        log_message "No ZScaler Root CA found in keychains, skipping cert setup"
        return 0
    fi

    log_message "ZScaler Root CA detected, configuring certificate trust..."
    mkdir -p ~/certs
    security find-certificate -a -p -c "Zscaler Root CA" > ~/certs/zscaler-root-ca.pem

    # Add env vars to .zshrc if not already present
    local shell_rc="$HOME/.zshrc"
    for var in AWS_CA_BUNDLE SSL_CERT_FILE REQUESTS_CA_BUNDLE; do
        if ! grep -q "export ${var}=~/certs/zscaler-root-ca.pem" "$shell_rc" 2>/dev/null; then
            echo "export ${var}=~/certs/zscaler-root-ca.pem" >> "$shell_rc"
        fi
    done

    # Export for the current session so downstream commands (pip, ansible-galaxy, aws) work
    export AWS_CA_BUNDLE=~/certs/zscaler-root-ca.pem
    export SSL_CERT_FILE=~/certs/zscaler-root-ca.pem
    export REQUESTS_CA_BUNDLE=~/certs/zscaler-root-ca.pem

    log_message "ZScaler certificate exported and environment configured"
}

# Setup standard environment variables for AWS and Claude Code
setup_env_vars() {
    log_message "Configuring environment variables..."
    local shell_rc="$HOME/.zshrc"

    # Define env vars as "KEY=VALUE" pairs
    local env_vars=(
        "AWS_PROFILE=twilio-identity-center"
        "CLAUDE_CODE_USE_BEDROCK=1"
        "AWS_REGION=us-east-1"
    )

    for entry in "${env_vars[@]}"; do
        local key="${entry%%=*}"
        local value="${entry#*=}"
        if ! grep -q "export ${key}=${value}" "$shell_rc" 2>/dev/null; then
            echo "export ${key}=${value}" >> "$shell_rc"
        fi
    done

    # Export for the current session
    export AWS_PROFILE=twilio-identity-center
    export CLAUDE_CODE_USE_BEDROCK=1
    export AWS_REGION=us-east-1

    log_message "Environment variables configured (AWS_PROFILE, CLAUDE_CODE_USE_BEDROCK, AWS_REGION)"
}

# Main installation flow
main() {
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${BLUE}    macOS Development Tools Installer${NC}"
    echo -e "${BLUE}         Version ${SCRIPT_VERSION} (${SCRIPT_DATE})${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo ""

    # Log version information
    log_message "Starting macOS Tool Installer v${SCRIPT_VERSION} (${SCRIPT_DATE})"
    log_message "Script path: $0"
    log_message "Bash version: ${BASH_VERSION}"

    # Check for help flag
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        echo "macOS Development Tools Installer v${SCRIPT_VERSION}"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -h, --help      Show this help message"
        echo "  -v, --version   Show version information"
        echo "  -n, --dry-run   Run in dry-run mode (no changes)"
        echo ""
        echo "Repository: https://github.com/bbTwilio/tool-install"
        exit 0
    fi

    # Check for version flag
    if [[ "${1:-}" == "--version" ]] || [[ "${1:-}" == "-v" ]]; then
        echo "Tool Installer version ${SCRIPT_VERSION} (${SCRIPT_DATE})"
        echo "Bash version: ${BASH_VERSION}"
        exit 0
    fi

    # Check for dry-run mode
    if [[ "${1:-}" == "--dry-run" ]] || [[ "${1:-}" == "-n" ]]; then
        dry_run
        exit 0
    fi

    # Check platform
    if [[ "$(uname)" != "Darwin" ]]; then
        echo -e "${RED}Error: This script requires macOS${NC}"
        exit 1
    fi

    # Setup ZScaler certificate trust (before any network calls)
    setup_zscaler_cert

    # Setup standard environment variables
    setup_env_vars

    # Check and install dependencies
    echo "Checking dependencies..."
    check_and_install_dependencies

    # Load tools from YAML
    echo "Loading tool definitions..."
    load_tools

    # Detect already installed tools
    echo "Detecting installed tools..."
    detect_installed_tools

    # Build and show selection menu
    echo ""
    selected_items=$(build_tool_list)

    if [[ -z "$selected_items" ]]; then
        echo "No tools selected. Exiting."
        exit 0
    fi

    # Parse selected tools (both installed and uninstalled)
    # Clear previous selections
    tools_to_install=()
    installed_tools_selected=()

    # Debug: Log the selected items
    log_message "DEBUG: Raw selected items:"
    log_message "$selected_items"

    # Use a more compatible approach for Bash 3.2
    # Create a temporary file to avoid subshell issues
    local temp_file="/tmp/tool-installer-selections-$$"
    printf '%s\n' "$selected_items" > "$temp_file"

    # Convert selected items to array
    local items_array=()
    if [[ -n "$selected_items" ]]; then
        # Read from temp file to avoid subshell issues in Bash 3.2
        while IFS= read -r line; do
            [[ -n "$line" ]] && items_array+=("$line")
        done < "$temp_file"
    fi

    # Clean up temp file
    rm -f "$temp_file"

    log_message "DEBUG: Number of selected items: ${#items_array[@]}"

    # Process each selected item
    for item in "${items_array[@]}"; do
        # Skip empty lines
        [[ -z "$item" ]] && continue

        log_message "DEBUG: Processing selected item: $item"

        # Check if this is an installed tool
        is_installed=false
        if [[ "$item" == "✓ "* ]]; then
            is_installed=true
            item="${item#✓ }"  # Remove checkmark prefix
            item="${item% (installed)}"  # Remove (installed) suffix
            log_message "DEBUG: Item is marked as installed"
        fi

        # Extract tool ID from display string
        tool_id=$(extract_tool_id "$item")
        if [[ -n "$tool_id" ]]; then
            log_message "DEBUG: Adding tool to install list: $tool_id"
            tools_to_install+=("$tool_id")
            if [[ "$is_installed" == true ]]; then
                log_message "DEBUG: Tool is also in installed list: $tool_id"
                installed_tools_selected+=("$tool_id")
            fi
        else
            log_message "WARNING: Could not extract tool ID from: $item"
        fi
    done

    log_message "DEBUG: Final tools_to_install count: ${#tools_to_install[@]}"
    log_message "DEBUG: Final tools_to_install: ${tools_to_install[@]+"${tools_to_install[*]}"}"
    log_message "DEBUG: Final installed_tools_selected count: ${#installed_tools_selected[@]}"
    log_message "DEBUG: Final installed_tools_selected: ${installed_tools_selected[@]+"${installed_tools_selected[*]}"}"

    # Confirm selection
    if [[ ${#tools_to_install[@]} -gt 0 ]]; then
        echo ""
        echo "Tools to install:"
        for tool in "${tools_to_install[@]}"; do
            local idx=$(get_tool_index "$tool")
            echo "  • ${TOOL_NAMES[$idx]}"
        done
        echo ""

        # Debug: Log arrays before confirmation
        log_message "DEBUG: Before confirmation - tools_to_install: ${tools_to_install[@]+"${tools_to_install[*]}"}"
        log_message "DEBUG: Before confirmation - installed_tools_selected: ${installed_tools_selected[@]+"${installed_tools_selected[*]}"}"

        if gum confirm "Proceed with installation?"; then
            # Debug: Log arrays after confirmation
            log_message "DEBUG: After confirmation - tools_to_install: ${tools_to_install[@]+"${tools_to_install[*]}"}"
            log_message "DEBUG: After confirmation - installed_tools_selected: ${installed_tools_selected[@]+"${installed_tools_selected[*]}"}"

            # Install tools
            if install_tools; then
                # Show post-installation instructions
                show_post_install_instructions "${tools_to_install[@]}"

                echo ""
                echo -e "${GREEN}Installation complete!${NC}"
                echo "Log file: $LOG_FILE"
            fi
        else
            echo "Installation cancelled."
        fi
    else
        echo "All selected tools are already installed."
    fi
}

# Run main function
main "$@"
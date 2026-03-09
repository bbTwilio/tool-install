#!/bin/bash
# macOS Tool Installer with Gum UI
# This script provides an interactive interface for installing development tools on macOS
# using gum for the UI and Ansible for the backend installation logic
# Compatible with bash 3.2+ (default macOS bash)

set -euo pipefail

# Version information
SCRIPT_VERSION="1.4.2"
SCRIPT_DATE="2026-03-09"

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
    yq eval ".tools.${tool}.${property}" "$TOOLS_YAML" 2>/dev/null || echo ""
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

        # Add to arrays
        ALL_TOOLS+=("$tool")
        TOOL_NAMES+=("$tool_name")
        TOOL_DESCRIPTIONS+=("$tool_desc")
        TOOL_CATEGORIES+=("$tool_cat")
        TOOL_COMMANDS+=("$tool_cmd")
        TOOL_INSTALLED+=(0)

        # Set documentation URLs
        local doc_url=""
        case "$tool" in
            git) doc_url="https://git-scm.com/doc" ;;
            github_cli) doc_url="https://cli.github.com/manual/" ;;
            ngrok) doc_url="https://ngrok.com/docs" ;;
            claude_code) doc_url="https://claude.ai/docs" ;;
            aws_cli) doc_url="https://docs.aws.amazon.com/cli/latest/userguide/" ;;
            docker) doc_url="https://docs.docker.com/" ;;
            kubernetes_cli) doc_url="https://kubernetes.io/docs/reference/kubectl/" ;;
            terraform) doc_url="https://developer.hashicorp.com/terraform/docs" ;;
            ansible) doc_url="https://docs.ansible.com/" ;;
            nodejs) doc_url="https://nodejs.org/docs/" ;;
            python) doc_url="https://docs.python.org/3/" ;;
            rust) doc_url="https://www.rust-lang.org/learn" ;;
            go) doc_url="https://go.dev/doc/" ;;
            java) doc_url="https://docs.oracle.com/en/java/" ;;
            vscode) doc_url="https://code.visualstudio.com/docs" ;;
            neovim) doc_url="https://neovim.io/doc/" ;;
            tmux) doc_url="https://github.com/tmux/tmux/wiki" ;;
            jq) doc_url="https://jqlang.github.io/jq/manual/" ;;
            gum) doc_url="https://github.com/charmbracelet/gum" ;;
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
    # Remove checkmark if present
    display_string="${display_string#✓ }"
    # Extract the name part between [] and -
    local name_part="${display_string#*] }"
    name_part="${name_part%% -*}"

    # Find matching tool
    local i
    for i in "${!TOOL_NAMES[@]}"; do
        if [[ "${TOOL_NAMES[$i]}" == "$name_part" ]]; then
            echo "${ALL_TOOLS[$i]}"
            return 0
        fi
    done
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
    local json_array="["
    local first=true

    for tool in "${tools_to_install[@]}"; do
        local action="install"

        # Check if this tool is installed
        for installed in "${installed_tools_selected[@]}"; do
            if [[ "$tool" == "$installed" ]]; then
                action=$(prompt_reinstall_action "$tool")
                break
            fi
        done

        if [[ "$first" == true ]]; then
            first=false
        else
            json_array+=","
        fi

        json_array+="{\"name\":\"$tool\",\"action\":\"$action\"}"
    done

    json_array+="]"
    echo "$json_array"
}

# Function to install tools using Ansible
install_tools() {
    # Uses global arrays: tools_to_install and installed_tools_selected

    if [[ ${#tools_to_install[@]} -eq 0 ]]; then
        echo "No tools selected for installation."
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
    log_message "Starting Ansible installation for: ${tools_to_install[*]}"

    # Build tool actions JSON
    local tools_json=$(build_tool_actions)

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
            git)
                echo -e "${YELLOW}Git:${NC}"
                echo "  Configure your identity:"
                echo "    git config --global user.name \"Your Name\""
                echo "    git config --global user.email \"your.email@example.com\""
                ;;
            github_cli)
                echo -e "${YELLOW}GitHub CLI:${NC}"
                echo "  Authenticate with GitHub:"
                echo "    gh auth login"
                ;;
            ngrok)
                echo -e "${YELLOW}Ngrok:${NC}"
                echo "  Add your auth token:"
                echo "    ngrok config add-authtoken YOUR_TOKEN"
                ;;
            claude_code)
                echo -e "${YELLOW}Claude Code:${NC}"
                echo "  Authenticate with Claude:"
                echo "    claude auth"
                ;;
            aws_cli)
                echo -e "${YELLOW}AWS CLI:${NC}"
                echo "  Configure AWS credentials:"
                echo "    aws configure"
                echo "  Or for SSO:"
                echo "    aws configure sso"
                ;;
            docker)
                echo -e "${YELLOW}Docker:${NC}"
                echo "  Start Docker Desktop application"
                ;;
            vscode)
                echo -e "${YELLOW}VS Code:${NC}"
                echo "  Install from command line:"
                echo "    code ."
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
    while IFS= read -r item; do
        # Skip empty lines
        [[ -z "$item" ]] && continue

        # Check if this is an installed tool
        local is_installed=false
        if [[ "$item" == "✓ "* ]]; then
            is_installed=true
            item="${item#✓ }"  # Remove checkmark prefix
            item="${item% (installed)}"  # Remove (installed) suffix
        fi

        # Extract tool ID from display string
        local tool_id=$(extract_tool_id "$item")
        if [[ -n "$tool_id" ]]; then
            tools_to_install+=("$tool_id")
            if [[ "$is_installed" == true ]]; then
                installed_tools_selected+=("$tool_id")
            fi
        fi
    done <<< "$selected_items"

    # Confirm selection
    if [[ ${#tools_to_install[@]} -gt 0 ]]; then
        echo ""
        echo "Tools to install:"
        for tool in "${tools_to_install[@]}"; do
            local idx=$(get_tool_index "$tool")
            echo "  • ${TOOL_NAMES[$idx]}"
        done
        echo ""

        if gum confirm "Proceed with installation?"; then
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
#!/bin/bash
# macOS Tool Installer with Gum UI
# This script provides an interactive interface for installing development tools on macOS
# using gum for the UI and Ansible for the backend installation logic

set -euo pipefail

# Check bash version (requires bash 4+ for associative arrays)
if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
    echo "Error: This script requires bash version 4 or higher."
    echo "Your current bash version is: ${BASH_VERSION}"
    echo ""
    echo "On macOS, you can install a newer bash with Homebrew:"
    echo "  brew install bash"
    echo ""
    echo "Then run the script with:"
    echo "  /usr/local/bin/bash $0"
    echo "  # or on Apple Silicon Macs:"
    echo "  /opt/homebrew/bin/bash $0"
    echo ""
    echo "Alternatively, use the compatibility launcher:"
    echo "  ./install-tools-compat.sh"
    exit 1
fi

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

# Associative arrays for tool data
declare -A installed_tools
declare -A tool_names
declare -A tool_descriptions
declare -A tool_categories
declare -A tool_commands
declare -A post_install_docs

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
            gum spin --spinner dots --title "Installing Homebrew..." -- \
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

            # Add Homebrew to PATH for this session (for Apple Silicon Macs)
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
            deps_installed=true
        else
            gum style --foreground 196 "Homebrew is required to continue."
            exit 1
        fi
    fi

    # Check for gum
    if ! command -v gum &>/dev/null; then
        gum style --foreground 214 "Installing gum (UI toolkit)..."
        brew install gum
        deps_installed=true
    fi

    # Check for Ansible
    if ! command -v ansible-playbook &>/dev/null; then
        gum spin --spinner dots --title "Installing Ansible..." -- \
            brew install ansible
        deps_installed=true
    fi

    # Check for yq (for better YAML parsing)
    if ! command -v yq &>/dev/null; then
        gum spin --spinner dots --title "Installing yq (YAML processor)..." -- \
            brew install yq
        deps_installed=true
    fi

    if $deps_installed; then
        gum style --foreground 46 "✅ Dependencies installed successfully!"
        sleep 1
    fi
}

# Function to extract tool IDs from YAML
get_tool_ids() {
    if command -v yq &>/dev/null; then
        yq '.tools | keys | .[]' "$TOOLS_YAML" 2>/dev/null
    else
        # Fallback to awk if yq is not available
        awk '/^tools:/{flag=1} /^[a-z]/{flag=0} flag && /^  [a-z_]+:/{gsub(/:/, ""); print $1}' "$TOOLS_YAML"
    fi
}

# Function to get tool property using yq or awk
get_tool_property() {
    local tool="$1"
    local property="$2"

    if command -v yq &>/dev/null; then
        yq ".tools.$tool.$property" "$TOOLS_YAML" 2>/dev/null | sed 's/null//'
    else
        # Fallback to awk
        awk -v tool="$tool" -v prop="$property" '
            $0 ~ "^  " tool ":$" {in_tool=1}
            in_tool && /^  [a-z]/ && !($0 ~ "^    ") {exit}
            in_tool && $0 ~ "^    " prop ":" {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
                gsub(prop ":[[:space:]]*", "", $0)
                gsub(/["'\'']/, "", $0)
                print $0
                exit
            }
        ' "$TOOLS_YAML"
    fi
}

# Function to load tool data
load_tool_data() {
    log_message "Loading tool data from $TOOLS_YAML"

    local tool_ids
    tool_ids=$(get_tool_ids)

    for tool in $tool_ids; do
        tool_names[$tool]=$(get_tool_property "$tool" "name")
        tool_descriptions[$tool]=$(get_tool_property "$tool" "description")
        tool_categories[$tool]=$(get_tool_property "$tool" "category")
        tool_commands[$tool]=$(get_tool_property "$tool" "command")

        # Set documentation URLs for specific tools
        case "$tool" in
            git)
                post_install_docs[$tool]="https://git-scm.com/doc"
                ;;
            github_cli)
                post_install_docs[$tool]="https://cli.github.com/manual/"
                ;;
            ngrok)
                post_install_docs[$tool]="https://ngrok.com/docs"
                ;;
            claude_code)
                post_install_docs[$tool]="https://claude.ai/docs"
                ;;
            aws_cli)
                post_install_docs[$tool]="https://docs.aws.amazon.com/cli/latest/userguide/"
                ;;
            docker)
                post_install_docs[$tool]="https://docs.docker.com/"
                ;;
            kubernetes_cli)
                post_install_docs[$tool]="https://kubernetes.io/docs/reference/kubectl/"
                ;;
            terraform)
                post_install_docs[$tool]="https://developer.hashicorp.com/terraform/docs"
                ;;
            ansible)
                post_install_docs[$tool]="https://docs.ansible.com/"
                ;;
            nodejs)
                post_install_docs[$tool]="https://nodejs.org/docs/"
                ;;
            python)
                post_install_docs[$tool]="https://docs.python.org/3/"
                ;;
            rust)
                post_install_docs[$tool]="https://www.rust-lang.org/learn"
                ;;
            go)
                post_install_docs[$tool]="https://go.dev/doc/"
                ;;
            java)
                post_install_docs[$tool]="https://docs.oracle.com/en/java/"
                ;;
            vscode)
                post_install_docs[$tool]="https://code.visualstudio.com/docs"
                ;;
            neovim)
                post_install_docs[$tool]="https://neovim.io/doc/"
                ;;
            tmux)
                post_install_docs[$tool]="https://github.com/tmux/tmux/wiki"
                ;;
            jq)
                post_install_docs[$tool]="https://jqlang.github.io/jq/manual/"
                ;;
            gum)
                post_install_docs[$tool]="https://github.com/charmbracelet/gum"
                ;;
        esac

        # Debug logging
        log_message "Loaded tool: $tool - ${tool_names[$tool]}"
    done
}

# Function to detect installed tools
detect_installed_tools() {
    log_message "Detecting installed tools..."

    for tool in "${!tool_commands[@]}"; do
        local cmd="${tool_commands[$tool]}"
        if [[ -n "$cmd" ]] && [[ "$cmd" != "null" ]] && command -v "$cmd" &>/dev/null; then
            installed_tools[$tool]=1
            log_message "Tool $tool is installed (command: $cmd found)"
        else
            log_message "Tool $tool is not installed (command: $cmd not found)"
        fi
    done
}

# Function to show tool selection UI
show_tool_selection() {
    local options=()
    local pre_selected=()
    local display_items=()

    # Build options list
    for tool in $(get_tool_ids | sort); do
        # Skip information-only items
        [[ "$tool" == "aws_jit_sso" ]] && continue

        local name="${tool_names[$tool]}"
        local desc="${tool_descriptions[$tool]}"
        local category="${tool_categories[$tool]}"

        # Build display string
        local status=""
        if [[ -n "${installed_tools[$tool]:-}" ]]; then
            status=" $(gum style --foreground 46 '✓')"
        else
            # Add to pre-selected if not installed (based on settings)
            pre_selected+=("$tool")
        fi

        # Format: tool_id|display_string (we'll extract tool_id later)
        local display="[$category] $name$status - $desc"
        options+=("$tool|$display")
        display_items+=("$display")
    done

    # Show multi-select UI
    local selected
    if [[ ${#pre_selected[@]} -gt 0 ]]; then
        # Convert pre_selected tool IDs to display strings
        local pre_selected_display=()
        for tool_id in "${pre_selected[@]}"; do
            for opt in "${options[@]}"; do
                if [[ "${opt%%|*}" == "$tool_id" ]]; then
                    pre_selected_display+=("${opt#*|}")
                    break
                fi
            done
        done

        selected=$(printf '%s\n' "${display_items[@]}" | \
            gum choose --no-limit \
            --header "Select tools to install (Space=toggle, Enter=confirm):" \
            --selected "${pre_selected_display[@]}" \
            --height 15)
    else
        selected=$(printf '%s\n' "${display_items[@]}" | \
            gum choose --no-limit \
            --header "Select tools to install (Space=toggle, Enter=confirm):" \
            --height 15)
    fi

    echo "$selected"
}

# Function to extract tool IDs from selection
extract_tool_ids_from_selection() {
    local selection="$1"
    local extracted_tools=()

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # Extract tool ID by matching against our options
        for tool in $(get_tool_ids); do
            [[ "$tool" == "aws_jit_sso" ]] && continue

            local name="${tool_names[$tool]}"
            if [[ "$line" == *"$name"* ]]; then
                extracted_tools+=("$tool")
                break
            fi
        done
    done <<< "$selection"

    printf '%s\n' "${extracted_tools[@]}"
}

# Function to run Ansible playbook
run_installation() {
    local tools=("$@")

    log_message "Starting installation of tools: ${tools[*]}"

    # Format tools for Ansible JSON array
    local tools_json=""
    for tool in "${tools[@]}"; do
        [[ -n "$tools_json" ]] && tools_json+=","
        tools_json+="\"$tool\""
    done
    tools_json="[$tools_json]"

    # Create temporary inventory
    local temp_inventory="/tmp/ansible-inventory-$$"
    echo "localhost ansible_connection=local" > "$temp_inventory"

    # Run Ansible playbook with progress indicator
    local ansible_output="/tmp/ansible-output-$$"

    gum spin --spinner dots --title "Installing tools via Ansible..." -- \
        ansible-playbook \
            -i "$temp_inventory" \
            "${PLAYBOOK}" \
            --extra-vars "{\"selected_tools\": $tools_json}" \
            --extra-vars "ansible_python_interpreter=$(which python3)" \
            2>&1 | tee "$ansible_output" >> "$LOG_FILE"

    local exit_code=${PIPESTATUS[0]}

    # Clean up
    rm -f "$temp_inventory"

    if [[ $exit_code -eq 0 ]]; then
        log_message "Installation completed successfully"
        return 0
    else
        log_message "Installation failed with exit code: $exit_code"
        gum style --foreground 196 "❌ Installation failed. Check log file: $LOG_FILE"

        # Show last few lines of error
        if [[ -f "$ansible_output" ]]; then
            echo "Last error output:"
            tail -n 10 "$ansible_output"
        fi
        rm -f "$ansible_output"
        return 1
    fi
}

# Function to show post-installation instructions
show_post_install_instructions() {
    local tools=("$@")
    local instructions=""

    for tool in "${tools[@]}"; do
        case "$tool" in
            git)
                instructions+="• Git: Configure user with 'git config --global user.name \"Your Name\"'\n"
                ;;
            github_cli)
                instructions+="• GitHub CLI: Authenticate with 'gh auth login'\n"
                ;;
            ngrok)
                instructions+="• Ngrok: Configure authtoken with 'ngrok config add-authtoken YOUR_TOKEN'\n"
                ;;
            claude_code)
                instructions+="• Claude Code: Authenticate with 'claude auth'\n"
                ;;
            aws_cli)
                instructions+="• AWS CLI: Configure SSO with 'aws configure sso'\n"
                ;;
        esac
    done

    if [[ -n "$instructions" ]]; then
        gum style --border normal --padding "1" --margin "1" \
            --foreground 214 "Post-Installation Steps:"
        echo -e "$instructions"
    fi

    # Open documentation in browser for installed tools
    for tool in "${tools[@]}"; do
        if [[ -n "${post_install_docs[$tool]}" ]]; then
            open_tool_docs "${tool_names[$tool]}" "${post_install_docs[$tool]}"
        fi
    done
}

# Main execution function
main() {
    # Platform check
    if [[ "$(uname)" != "Darwin" ]]; then
        gum style --foreground 196 "❌ This script requires macOS"
        exit 1
    fi

    # Create log file
    touch "$LOG_FILE"
    log_message "Starting macOS Tool Installer"

    # Welcome banner
    gum style \
        --border double \
        --border-foreground 212 \
        --padding "1 2" \
        --margin "1" \
        --foreground 212 \
        --bold \
        "macOS Tool Installer"

    gum style \
        --foreground 245 \
        --margin "0 2 1" \
        "Interactive installer for development tools using Ansible" \
        "" \
        "Log file: $LOG_FILE"

    # Check and install dependencies
    check_and_install_dependencies

    # Load tool data
    gum spin --spinner dots --title "Loading tool configuration..." -- \
        load_tool_data

    # Detect installed tools
    detect_installed_tools

    # Show tool selection UI
    local selected
    selected=$(show_tool_selection)

    # Check if anything was selected
    if [[ -z "$selected" ]]; then
        gum style --foreground 214 "No tools selected for installation."
        exit 0
    fi

    # Extract tool IDs from selection
    local tools_to_install
    tools_to_install=$(extract_tool_ids_from_selection "$selected")

    # Convert to array
    IFS=$'\n' read -d '' -ra tool_array <<< "$tools_to_install" || true

    if [[ ${#tool_array[@]} -eq 0 ]]; then
        gum style --foreground 214 "No valid tools identified from selection."
        exit 0
    fi

    # Show confirmation
    gum style --foreground 245 "Selected tools for installation:"
    for tool in "${tool_array[@]}"; do
        echo "  • ${tool_names[$tool]}"
    done
    echo ""

    if gum confirm "Install ${#tool_array[@]} selected tool(s)?"; then
        # Run installation
        if run_installation "${tool_array[@]}"; then
            gum style --foreground 46 --bold "✅ Installation complete!"

            # Show post-installation instructions
            show_post_install_instructions "${tool_array[@]}"
        else
            exit 1
        fi
    else
        gum style --foreground 214 "Installation cancelled."
    fi

    # Show log file location
    echo ""
    gum style --foreground 245 "Installation log saved to: $LOG_FILE"
}

# Handle Ctrl+C gracefully
trap 'echo ""; gum style --foreground 214 "Installation cancelled by user."; exit 130' INT

# Run main function
main "$@"
# Tool Re-Installation Feature Implementation Plan

**Goal:** Enable re-installation of already installed tools with user choice between upgrade and force reinstall.

**Architecture:** Remove installation guards from shell script and Ansible roles, add per-tool action prompts, pass structured data to Ansible with tool-action pairs.

**Tech Stack:** Bash 3.2+, Ansible, Homebrew, Gum UI

---

## Task 1: Enable Selection of Installed Tools in Shell Script

**Files:**
- Modify: `install-tools.sh:218-246` (build_tool_list function)
- Modify: `install-tools.sh:469-485` (selection parsing)

**Step 1: Update build_tool_list to allow installed tool selection**

Replace lines 218-246 with:
```bash
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

    # Output for gum with pre-selected items
    printf "%s\n" "${tool_list[@]}" | \
        gum choose --no-limit \
                   --header "Select tools to install/re-install (Space to toggle, Enter to confirm):" \
                   --selected="${preselected[@]}"
}
```

**Step 2: Test the updated selection UI**

Run: `./install-tools.sh`
Expected: See installed tools with "✓" prefix and "(installed)" suffix, all selectable

**Step 3: Update selection parsing to handle installed tools**

Replace lines 469-485 with:
```bash
# Parse selected tools (both installed and uninstalled)
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
```

**Step 4: Commit the selection changes**

```bash
git add install-tools.sh
git commit -m "feat: Allow selection of installed tools for re-installation"
```

---

## Task 2: Add Action Prompt for Installed Tools

**Files:**
- Modify: `install-tools.sh:487` (add new function after line 486)
- Modify: `install-tools.sh:497` (update install confirmation section)

**Step 1: Add function to prompt for reinstall action**

Add after line 486:
```bash
# Function to prompt for reinstall action
prompt_reinstall_action() {
    local tool_id="$1"
    local tool_name="$(get_tool_prop "$tool_id" "name")"

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
    local tools=("$@")
    local json_array="["
    local first=true

    for tool in "${tools[@]}"; do
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
```

**Step 2: Test the prompt function**

Run: `./install-tools.sh` and select an installed tool
Expected: See prompt asking for "Upgrade to latest version" or "Force reinstall"

**Step 3: Commit the prompt functionality**

```bash
git add install-tools.sh
git commit -m "feat: Add action prompt for installed tools"
```

---

## Task 3: Update Ansible Playbook to Handle Actions

**Files:**
- Modify: `config/ansible/playbook.yml:11-14` (update vars section)
- Modify: `config/ansible/playbook.yml:60-64` (update task inclusion)

**Step 1: Update playbook vars to receive tool actions**

Replace lines 11-14 with:
```yaml
  vars:
    # Tools to install with their actions (will be passed from shell script)
    tools_with_actions: "{{ selected_tools | default([]) }}"

    # Legacy support for simple tool list
    tools_to_install: "{{ tools_with_actions | map(attribute='name') | list if tools_with_actions[0] is defined and tools_with_actions[0].name is defined else tools_with_actions }}"
```

**Step 2: Update task inclusion to pass action**

Replace lines 60-64 with:
```yaml
  tasks:
    - name: Include tool installation roles
      include_role:
        name: "{{ item.name if item.name is defined else item }}"
      vars:
        tool_action: "{{ item.action | default('install') }}"
      loop: "{{ tools_with_actions }}"
```

**Step 3: Test playbook with sample data**

Run: `ansible-playbook config/ansible/playbook.yml -e '{"selected_tools":[{"name":"git","action":"reinstall"}]}' --check`
Expected: Playbook runs without errors in check mode

**Step 4: Commit the playbook changes**

```bash
git add config/ansible/playbook.yml
git commit -m "feat: Update playbook to handle tool actions"
```

---

## Task 4: Update Git Role to Support Reinstall

**Files:**
- Modify: `config/ansible/roles/git/tasks/main.yml:15-21` (installation task)

**Step 1: Replace installation task with action support**

Replace lines 15-28 with:
```yaml
- name: Install/Upgrade Git via Homebrew
  homebrew:
    name: git
    state: latest
  when:
    - not dry_run | default(false)
    - tool_action | default('install') != 'reinstall'

- name: Force reinstall Git via Homebrew
  shell: brew reinstall git
  when:
    - not dry_run | default(false)
    - tool_action | default('install') == 'reinstall'

- name: Simulate Git installation/upgrade (dry run)
  debug:
    msg: "Would {{ tool_action | default('install') }} Git via Homebrew"
  when:
    - dry_run | default(false)
```

**Step 2: Test the Git role**

Run: `ansible-playbook config/ansible/playbook.yml -e '{"selected_tools":[{"name":"git","action":"reinstall"}]}' --check`
Expected: Shows "Would reinstall Git via Homebrew" in dry run

**Step 3: Commit the Git role changes**

```bash
git add config/ansible/roles/git/tasks/main.yml
git commit -m "feat: Add reinstall support to Git role"
```

---

## Task 5: Update AWS CLI Role to Support Reinstall

**Files:**
- Modify: `config/ansible/roles/aws_cli/tasks/main.yml:22-28` (installation task)

**Step 1: Replace installation task with action support**

Replace lines 22-35 with:
```yaml
- name: Install/Upgrade AWS CLI via Homebrew
  homebrew:
    name: awscli
    state: latest
  when:
    - not dry_run | default(false)
    - tool_action | default('install') != 'reinstall'

- name: Force reinstall AWS CLI via Homebrew
  shell: brew reinstall awscli
  when:
    - not dry_run | default(false)
    - tool_action | default('install') == 'reinstall'

- name: Simulate AWS CLI installation/upgrade (dry run)
  debug:
    msg: "Would {{ tool_action | default('install') }} AWS CLI via Homebrew"
  when:
    - dry_run | default(false)
```

**Step 2: Commit the AWS CLI role changes**

```bash
git add config/ansible/roles/aws_cli/tasks/main.yml
git commit -m "feat: Add reinstall support to AWS CLI role"
```

---

## Task 6: Create Template for Other Roles

**Files:**
- Create: `config/ansible/roles/template_reinstall.yml`

**Step 1: Create reusable template**

```yaml
# Template for adding reinstall support to any role
# Replace TOOL_NAME and BREW_PACKAGE with actual values

- name: Install/Upgrade TOOL_NAME via Homebrew
  homebrew:
    name: BREW_PACKAGE
    state: latest
  when:
    - not dry_run | default(false)
    - tool_action | default('install') != 'reinstall'

- name: Force reinstall TOOL_NAME via Homebrew
  shell: brew reinstall BREW_PACKAGE
  when:
    - not dry_run | default(false)
    - tool_action | default('install') == 'reinstall'

- name: Simulate TOOL_NAME installation/upgrade (dry run)
  debug:
    msg: "Would {{ tool_action | default('install') }} TOOL_NAME via Homebrew"
  when:
    - dry_run | default(false)
```

**Step 2: Commit the template**

```bash
git add config/ansible/roles/template_reinstall.yml
git commit -m "feat: Add template for role reinstall support"
```

---

## Task 7: Update Shell Script to Use New Data Format

**Files:**
- Modify: `install-tools.sh:269-312` (install_tools function)

**Step 1: Update install_tools to build and pass action data**

Replace lines 278-293 with:
```bash
    echo -e "${BLUE}Installing selected tools using Ansible...${NC}"
    log_message "Starting Ansible installation for: ${tools_to_install[*]}"

    # Build tool actions JSON
    local tools_json=$(build_tool_actions "${tools_to_install[@]}")

    # Create the extra vars JSON object
    local extra_vars="{\"selected_tools\": $tools_json}"

    # Log the JSON being passed to Ansible for debugging
    log_message "Passing to Ansible: $extra_vars"

    # Run Ansible playbook with spinner
    ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" gum spin --spinner dot --title "Running Ansible playbook..." -- \
        ansible-playbook "$PLAYBOOK" \
        -e "$extra_vars" \
        -vv >> "$LOG_FILE" 2>&1
```

**Step 2: Add reinstall notification**

Add before line 278:
```bash
    # Show reinstall/upgrade notifications
    if [[ ${#installed_tools_selected[@]} -gt 0 ]]; then
        echo ""
        echo "The following installed tools will be processed:"
        for tool in "${installed_tools_selected[@]}"; do
            local name="$(get_tool_prop "$tool" "name")"
            echo "  • $name (action will be selected)"
        done
        echo ""
    fi
```

**Step 3: Test the complete flow**

Run: `./install-tools.sh`
Expected: Can select installed tools, get prompted for action, and see Ansible process them

**Step 4: Commit the final shell script changes**

```bash
git add install-tools.sh
git commit -m "feat: Complete shell script integration for reinstall feature"
```

---

## Task 8: Update Remaining Roles

**Files:**
- Modify: All role files in `config/ansible/roles/*/tasks/main.yml`

**Step 1: List all roles that need updating**

Run: `find config/ansible/roles -name "main.yml" -path "*/tasks/*" | grep -v -E "(git|aws_cli)"`
Expected: List of remaining role files

**Step 2: Apply template pattern to each role**

For each role:
1. Remove `when: xxx_installed.rc != 0` conditions
2. Add upgrade task with `state: latest` and `when: tool_action != 'reinstall'`
3. Add reinstall task with `shell: brew reinstall` and `when: tool_action == 'reinstall'`

**Step 3: Commit all role updates**

```bash
git add config/ansible/roles/
git commit -m "feat: Add reinstall support to all Ansible roles"
```

---

## Task 9: Integration Testing

**Files:**
- Create: `test-reinstall.sh`

**Step 1: Create test script**

```bash
#!/bin/bash
# Test script for reinstall feature

set -euo pipefail

echo "Testing Tool Reinstall Feature"
echo "==============================="

# Test 1: Check if installed tools are selectable
echo "Test 1: Checking if git (installed) appears in selection..."
output=$(./install-tools.sh --dry-run 2>&1)
if echo "$output" | grep -q "✓.*Git.*installed"; then
    echo "✓ Installed tools shown correctly"
else
    echo "✗ Failed to show installed tools"
    exit 1
fi

echo "==============================="
echo "All tests passed!"
```

**Step 2: Run the test**

Run: `chmod +x test-reinstall.sh && ./test-reinstall.sh`
Expected: All tests pass

**Step 3: Commit the test**

```bash
git add test-reinstall.sh
git commit -m "test: Add integration test for reinstall feature"
```

---

## Task 10: Documentation Updates

**Files:**
- Modify: `README.md:21-22` (features section)
- Modify: `README.md:70-94` (workflow section)

**Step 1: Update features list**

Add after line 22:
```markdown
- **Re-installation Support**: Installed tools can be upgraded to latest version or force-reinstalled
```

**Step 2: Update workflow documentation**

Add after line 82:
```markdown
   - For installed tools that are selected:
     - Choose "Upgrade to latest version" to update
     - Choose "Force reinstall" to remove and reinstall (fixes corruption)
```

**Step 3: Commit documentation**

```bash
git add README.md
git commit -m "docs: Update README with reinstall feature"
```

---

## Verification Steps

1. **Test new installation**: Select only uninstalled tools
2. **Test upgrade**: Select installed tool, choose "Upgrade to latest"
3. **Test force reinstall**: Select installed tool, choose "Force reinstall"
4. **Test mixed selection**: Select both installed and uninstalled tools
5. **Test dry run**: Run with `--dry-run` flag

## Success Criteria

- [x] Installed tools can be selected in UI
- [x] User gets prompted for upgrade vs reinstall for installed tools
- [x] Ansible receives structured data with tool actions
- [x] Roles execute appropriate action (install/upgrade/reinstall)
- [x] No breaking changes to existing functionality
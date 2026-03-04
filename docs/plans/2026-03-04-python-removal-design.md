# Python/Textual Removal and Shell/GUM Consolidation Design

## Date: 2026-03-04

## Overview

This design document outlines the complete removal of Python/Textual components from the tool-install project and consolidation around the shell script + GUM UI + Ansible backend approach.

## Objective

Remove all Python/Textual code and dependencies to create a cleaner, single-implementation project focused on the shell/GUM/Ansible approach while preserving valuable features and configurations.

## Approach

**Selected Approach: Clean Sweep**

Complete removal of Python components with careful preservation of Ansible configurations and addition of browser launch feature to shell script.

## Implementation Details

### 1. File Structure Changes

#### Items to Remove
- `tool-installer/` directory (entire Python implementation including):
  - All Python source files (`*.py`)
  - `requirements.txt`
  - Python-specific configuration
  - Git repository within tool-installer
- `src/installer/` directory (empty, unused)
- `config/ansible/roles/ngrok/` and `config/ansible/roles/nodejs/` (to be replaced)

#### Items to Preserve and Move
- `tool-installer/config/ansible/` → `config/ansible/` (complete Ansible setup)
- `tool-installer/config/tools.yaml` → `config/tools.yaml`

#### Final Structure
```
tool-install/
├── config/
│   ├── ansible/
│   │   ├── playbook.yml
│   │   └── roles/
│   │       ├── aws_cli/
│   │       ├── git/
│   │       ├── ngrok/
│   │       └── nodejs/
│   └── tools.yaml
├── install-tools.sh
├── test-installer.sh
├── test-installer-windows.sh
└── README.md (renamed from README-shell-installer.md)
```

### 2. Script Path Updates

#### install-tools.sh
- Update `TOOLS_YAML="${SCRIPT_DIR}/tool-installer/config/tools.yaml"` to `"${SCRIPT_DIR}/config/tools.yaml"`
- Update `ANSIBLE_DIR="${SCRIPT_DIR}/tool-installer/config/ansible"` to `"${SCRIPT_DIR}/config/ansible"`

#### test-installer.sh and test-installer-windows.sh
- Update any config path references to match new structure
- Ensure compatibility with relocated configuration files

### 3. Feature Preservation: Browser Launch

Add browser opening functionality from Python version to shell script:

```bash
# Function to open tool documentation in browser
open_tool_docs() {
    local tool_name=$1
    local tool_url=$2

    if [[ -n "$tool_url" ]]; then
        if gum confirm "Open $tool_name documentation in browser?"; then
            open "$tool_url" 2>/dev/null || echo "Could not open browser"
        fi
    fi
}
```

Integration points:
- Post-installation instructions section
- Extract URLs from tools.yaml configuration
- Use gum confirm for consistent UI experience

### 4. Testing and Validation

#### Validation Steps
1. Run `install-tools.sh` to verify functionality with new paths
2. Test tool detection for already installed tools
3. Verify Ansible playbook execution with moved roles
4. Confirm browser launch works for tools with URLs
5. Execute test scripts to ensure continued functionality

#### Error Handling
- Validate config file existence before proceeding
- Provide clear error messages for missing files
- Ensure graceful degradation if browser launch fails

## Benefits

1. **Simplified Maintenance**: Single implementation to maintain
2. **Reduced Dependencies**: No Python, Textual, or Rich requirements
3. **Cleaner Structure**: Unambiguous project organization
4. **Preserved Functionality**: All Ansible roles and browser feature retained
5. **Consistent UI**: Pure GUM-based interface throughout

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Loss of Python features | Carefully port browser launch to shell |
| Path update errors | Thorough testing of all scripts |
| Missing Ansible roles | Verify all roles copied before deletion |
| Git history loss | Git preserves full history of deleted files |

## Success Criteria

- All shell scripts execute without errors
- Tool installation works for all defined tools
- Browser documentation launch functions correctly
- No Python dependencies remain in project
- Clean project structure with single implementation

## Next Steps

1. Execute implementation plan using writing-plans skill
2. Perform thorough testing after each major step
3. Update documentation to reflect new structure
4. Consider adding any additional shell-based enhancements
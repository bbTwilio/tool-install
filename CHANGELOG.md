# Changelog

All notable changes to the macOS Tool Installer will be documented in this file.

## [1.5.3] - 2026-03-11

### Added
- New zscaler_cert tool for configuring ZScaler root certificates for AWS CLI
- Automatically finds and exports ZScaler certificate from macOS keychain
- Configures AWS_CA_BUNDLE environment variable in shell configuration files
- Added to cloud and full profiles for users behind corporate ZScaler proxies

### Features
- Searches multiple keychains (System, Library, User) for ZScaler certificates
- Validates exported certificate using OpenSSL
- Supports multiple certificate name variations
- Provides graceful handling when certificate is not found
- Idempotent - safe to run multiple times without duplicating shell config entries
- Supports reinstall and upgrade actions

## [1.5.2] - 2026-03-11

### Removed
- Removed dead code references to 12 non-existent tools from install-tools.sh
- Cleaned up orphaned documentation URL mappings for: docker, kubernetes_cli, terraform,
  ansible, python, rust, go, java, neovim, tmux, jq, gum
- Removed docker post-install instructions

### Why
- These tools were never defined in tools.yaml and the code was unreachable
- Simplifies the installer script to only reference actually configured tools
- Improves code maintainability by removing orphaned references

## [1.5.1] - 2026-03-11

### Removed
- Removed aws_jit_sso informational tool feature
- Deleted aws_jit_sso Ansible role
- Removed aws_jit_sso from cloud and full profiles
- Updated test scripts to remove aws_jit_sso references

### Why
- aws_jit_sso was an informational-only tool that provided AWS Bedrock access instructions
- This functionality is better handled through separate documentation
- Simplifies the tool installer to focus on actual tool installations

## [1.5.0] - 2026-03-11

### Changed
- Integrated Segment engineering laptop setup Ansible roles
- Removed direct management of: git, GitHub CLI, Node.js, ngrok, AWS CLI, VS Code
- These tools can still be installed via Homebrew directly
- Updated profiles to reflect new tool set

### Added
- github_ssh tool for GitHub SSH authentication setup
- aws_configure_sso tool for AWS SSO profile configuration
- Ansible collection requirements file (config/ansible/requirements.yml)
- Auto-installation of Ansible collections before running playbook

### Removed
- Removed 6 tool definitions from tools.yaml (git, github_cli, ngrok, nodejs, aws_cli, vscode)
- Removed corresponding Ansible roles for the 6 tools
- Removed post-install instructions for deleted tools

### Migration Notes
- Users with existing installations: The 6 removed tools remain installed on their systems
- Future management of these tools should be done via Homebrew directly
- The installer will no longer update or reinstall these tools

## [1.4.8] - 2026-03-10

### Fixed
- Fixed "role 'null' was not found" error when yq returns literal string "null"
- Updated get_tool_property function to convert "null" strings to empty strings
- Added defensive check for "null" string in role extraction logic
- This fixes installation failures for tools without install_methods fields (e.g., aws_jit_sso)

### Technical Details
- yq returns the literal string "null" when querying non-existent fields
- Previous empty string check `[[ -z "$tool_role" ]]` didn't catch "null"
- Now handles both empty strings and "null" strings properly

## [1.4.7] - 2026-03-10

### Fixed
- Fixed Ansible role not found errors for tools with mismatched IDs and role names
- Added role field extraction from tools.yaml and included it in JSON passed to Ansible
- The installer now correctly maps tool IDs to their corresponding Ansible role directories

### Technical Details
- Added `TOOL_ROLES` array to track Ansible role names separately from tool IDs
- Modified `load_tools()` to extract the `role` field from `install_methods[0].role` in tools.yaml
- Added `get_tool_role()` function to retrieve the correct role name for a tool
- Updated `build_tool_actions()` to include both `name` and `role` fields in the JSON
- Modified Ansible playbook to use `item.role` with fallback to `item.name` for backward compatibility
- This fix resolves issues with tools like `github_cli` (role: `github`) and `claude_code` (role: `claude`)

### Changed
- JSON structure passed to Ansible now includes: `{"name": "tool_id", "role": "role_name", "action": "action"}`
- Ansible playbook uses `item.role | default(item.name)` to determine which role to include

## [1.4.6] - 2026-03-10

### Fixed
- Fixed unbound variable error when iterating over empty arrays in for loops with bash 3.2
- Added safety check before iterating over `installed_tools_selected` array at line 332
- The issue occurred when no installed tools were selected, causing the for loop to trigger an unbound variable error
- This fix prevents the script from exiting with "unbound variable" error when using strict mode (`set -u`)

### Technical Details
- The problem specifically affected the `build_tool_actions()` function when iterating over an empty `installed_tools_selected` array
- Solution: Added `if [[ ${#installed_tools_selected[@]} -gt 0 ]]` check before the for loop
- This ensures the for loop only executes when the array has elements
- Complements the v1.4.5 fix for array expansion in logging statements

## [1.4.5] - 2026-03-10

### Fixed
- Fixed unbound variable error in macOS bash 3.2 when expanding empty arrays
- Replaced unsafe `${array[*]}` expansions with safe `${array[@]+"${array[*]}"}` pattern
- This fix prevents the script from exiting with "unbound variable" errors when arrays are empty
- Affects all debug logging statements that display array contents (11 locations fixed)

### Technical Details
- The issue occurred because bash's `set -u` option treats expansion of uninitialized/empty arrays as an error
- The safe pattern `${array[@]+"${array[*]}"}` expands to empty string for empty arrays
- This is particularly important for macOS which ships with bash 3.2 by default
- The fix ensures compatibility with strict mode (`set -euo pipefail`) across all bash versions

### Added
- Test script (`test-array-fix.sh`) to verify the array expansion fix

## [1.4.4] - 2026-03-10

### Fixed
- Fixed critical tool selection bug where selected tools were not being passed to Ansible
- Replaced here-string parsing with temp file approach for better Bash 3.2 compatibility
- Added comprehensive debug logging throughout the tool selection and installation process
- Fixed array scope issues in `build_tool_actions` function
- Improved `extract_tool_id` function with error handling and debug output

### Added
- Extensive debug logging to help diagnose tool selection issues
- Test script (`test-tool-selection.sh`) to verify the fix works correctly
- Debug messages now show:
  - Raw selected items from Gum UI
  - Tool ID extraction process
  - Array contents at each stage
  - JSON generation for Ansible

### Changed
- Tool selection parsing now uses temp file instead of here-string for Bash 3.2 compatibility
- Improved error handling in tool selection pipeline

## [1.4.3] - 2026-03-09

### Fixed
- Attempted fix for tool selection bug by removing `local` keywords in subshell

## [1.4.2] - 2026-03-08

### Fixed
- Added JSON validation to prevent Ansible parsing errors

## [1.4.1] - 2026-03-07

### Fixed
- Fixed tool selection UI not showing installed tools

## [1.4.0] - 2026-03-06

### Added
- Reinstall feature for already installed tools
- Option to upgrade or force reinstall tools

## Previous versions
- Earlier version history not documented
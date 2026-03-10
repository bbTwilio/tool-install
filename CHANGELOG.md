# Changelog

All notable changes to the macOS Tool Installer will be documented in this file.

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
# Tool Installer - Shell Script + Gum UI

A lightweight, interactive tool installer for macOS that uses shell scripting with the `gum` UI toolkit for the interface and Ansible for the backend installation logic.

[![GitHub](https://img.shields.io/badge/GitHub-bbTwilio%2Ftool--install-blue)](https://github.com/bbTwilio/tool-install)
![Version](https://img.shields.io/badge/version-1.5.0-green)
![Status](https://img.shields.io/badge/status-stable-brightgreen)

> **Latest Update (v1.5.0):** Integrated Segment engineering laptop setup Ansible roles. Removed direct management of git, GitHub CLI, Node.js, ngrok, AWS CLI, and VS Code - these can still be installed via Homebrew directly.

## Quick Start

```bash
# Clone and run
git clone https://github.com/bbTwilio/tool-install.git
cd tool-install
chmod +x install-tools.sh
./install-tools.sh
```

## Features

- **Interactive UI**: Modern terminal UI using `gum` for tool selection
- **Auto-dependency Management**: Automatically installs required dependencies (Homebrew, gum, Ansible, yq)
- **Smart Detection**: Detects already installed tools and marks them with ✓
- **Pre-selection**: Automatically pre-selects uninstalled tools for convenience
- **Re-installation Support**: Installed tools can be upgraded to latest version or force-reinstalled
- **Ansible Backend**: Leverages robust Ansible roles for installation
- **Browser Launch**: Optionally opens tool documentation in browser after installation
- **Logging**: Comprehensive logging to `/tmp/tool-installer-*.log`
- **Post-install Instructions**: Provides tool-specific configuration steps after installation
- **AWS SSO Support**: Configures AWS SSO profiles for seamless cloud access
- **GitHub SSH Setup**: Automatically configures SSH keys for GitHub access

## Prerequisites

- macOS (Darwin)
- Bash shell (3.2+ compatible - works with default macOS bash)
- Internet connection for downloading dependencies

## Installation

1. Clone the repository:
```bash
git clone https://github.com/bbTwilio/tool-install.git
cd tool-install
```

2. Make the script executable (if not already):
```bash
chmod +x install-tools.sh
```

3. Run the installer:
```bash
./install-tools.sh
```

## Usage

The installer is completely interactive and requires no command-line arguments:

```bash
./install-tools.sh
```

### Command Line Options

```bash
./install-tools.sh --help      # Show help message
./install-tools.sh --version   # Show version information
./install-tools.sh --dry-run   # Run without making changes
```

### Workflow

1. **Dependency Check**: The script first checks for and installs required dependencies:
   - Homebrew (if not installed)
   - gum (UI toolkit)
   - Ansible (automation backend)
   - yq (YAML processor for better parsing)

2. **Tool Selection**: An interactive multi-select list shows all available tools:
   - Tools are categorized (cloud, vcs, runtime, etc.)
   - Installed tools are marked with ✓ and "(installed)" suffix
   - Uninstalled tools are pre-selected by default
   - Use `Space` to toggle selection
   - Use `Enter` to confirm
   - For installed tools that are selected:
     - Choose "Upgrade to latest version" to update
     - Choose "Force reinstall" to remove and reinstall (fixes corruption)

3. **Confirmation**: Review selected tools and confirm installation

4. **Installation**: Ansible runs in the background with a progress spinner

5. **Post-Installation**:
   - Tool-specific configuration instructions are displayed
   - Optional prompt to open documentation in browser for each installed tool
   - Documentation URLs are provided for manual access if browser launch fails

## Re-installation and Upgrades

The installer supports re-installing and upgrading already installed tools:

### When to Use Each Option

**Upgrade to latest version**
- Updates the tool to the newest available version
- Preserves configuration and settings
- Recommended for routine updates

**Force reinstall**
- Completely removes and reinstalls the tool
- Useful when:
  - Tool installation is corrupted
  - Configuration needs to be reset
  - Troubleshooting persistent issues

### How It Works

1. Installed tools appear in the selection list with a ✓ checkmark and "(installed)" suffix
2. You can select them just like uninstalled tools
3. When you proceed, you'll be prompted for each installed tool to choose your action
4. The installer will execute the appropriate Homebrew command:
   - Upgrade: `brew upgrade <tool>` or `brew upgrade --cask <tool>`
   - Reinstall: `brew reinstall <tool>` or `brew reinstall --cask <tool>`

## Available Tools

The installer supports the following tools:

| Tool | Category | Description | Ansible Role |
|------|----------|-------------|--------------|
| GitHub SSH Setup | vcs | Configure SSH authentication for GitHub | github |
| AWS SSO Configuration | cloud | Configure AWS SSO profiles | aws_configure_sso |
| Claude Code | ai | Anthropic's official CLI for Claude | claude |
| AWS JIT SSO | info | Open browser to request Bedrock access | aws_jit_sso |

### Special Roles

| Role | Purpose |
|------|---------|
| aws_configure_sso | Configures AWS SSO profiles for seamless authentication |
| github | Sets up SSH keys and configures GitHub access |
| claude | Installs Claude Code CLI with shell integration |

### Migration Note

**For users with existing installations:** The following tools have been removed from direct installer management in v1.5.0:
- Git
- GitHub CLI
- Node.js
- ngrok
- AWS CLI
- VS Code

These tools remain installed on your system and can be managed directly through Homebrew:
```bash
# Example: Update git via Homebrew
brew upgrade git

# Example: Install VS Code if needed
brew install --cask visual-studio-code
```

## Configuration

The installer uses configuration files from `config/`:

- `config/tools.yaml`: Tool definitions and metadata
- `config/ansible/playbook.yml`: Main Ansible playbook
- `config/ansible/roles/*/`: Individual tool installation roles

### Key Configuration Files

- **tools.yaml**: Defines all available tools, their installation methods, and verification commands
- **playbook.yml**: Orchestrates the installation process using Ansible
- **Role-specific defaults**: Each role has a `defaults/main.yml` for customizable settings

## Logging

Installation logs are saved to `/tmp/tool-installer-YYYYMMDD-HHMMSS.log`

The log includes:
- Dependency installation steps
- Tool detection results
- Ansible playbook execution output
- Error messages (if any)

## Troubleshooting

### Script fails with "This script requires macOS"

The installer is designed specifically for macOS. Linux and Windows support may be added in future versions.

### Homebrew installation prompts for password

This is normal. Homebrew requires administrator privileges for initial setup.

### Tool installation fails

1. Check the log file shown at the end of execution
2. Ensure you have internet connectivity
3. Try running the installer again:
   - For new tools: they will be pre-selected automatically
   - For corrupted tools: select them and choose "Force reinstall" when prompted

### "gum: command not found"

The script should auto-install gum. If this fails:
```bash
brew install gum
```

### AWS SSO Configuration

After installing AWS CLI, you can configure SSO profiles:
```bash
aws configure sso
# Or use the aws_configure_sso Ansible role directly
```

### GitHub SSH Access

The GitHub role automatically:
- Generates an SSH key if none exists
- Configures known_hosts for GitHub
- Provides instructions for adding the key to your GitHub account


## Development

### Adding New Tools

1. Add tool definition to `config/tools.yaml`
2. Create Ansible role in `config/ansible/roles/<tool_name>/`
3. Update `install-tools.sh` if special handling is needed
4. The installer will automatically detect the new tool

### Ansible Role Structure

Each tool role should follow this structure:
```
config/ansible/roles/<tool_name>/
├── defaults/
│   └── main.yml    # Default variables
├── tasks/
│   └── main.yml    # Installation tasks
└── templates/       # Optional config templates
```

### Testing

Run the test scripts to verify functionality:
```bash
./test-installer.sh          # Basic tests
./test-reinstall.sh          # Test reinstall/upgrade feature
```

### Debugging

The installer includes comprehensive debug logging (v1.4.4+). Check the log file shown at completion for detailed debug information:
```bash
# View debug logs
grep "DEBUG:" /tmp/tool-installer-*.log

# Enable bash trace mode for even more detail
# Edit the script and add after line 7:
set -x  # Enable bash debug output
```

### Troubleshooting

#### Tools not installing (v1.4.3 bug - fixed in v1.4.4)
If you experience issues where selected tools are not being installed:
1. Update to the latest version (v1.4.4 or later)
2. Run the test script: `./test-tool-selection.sh`
3. Check debug logs for tool selection details

#### Version Information
Current version: 1.5.0 (2026-03-11)
- Integrated Segment engineering laptop setup Ansible roles
- Removed direct management of common tools (now managed via Homebrew)
- See [CHANGELOG.md](CHANGELOG.md) for full version history

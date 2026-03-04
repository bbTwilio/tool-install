# Tool Installer - Shell Script + Gum UI

A lightweight, interactive tool installer for macOS that uses shell scripting with the `gum` UI toolkit for the interface and Ansible for the backend installation logic.

## Features

- **Interactive UI**: Modern terminal UI using `gum` for tool selection
- **Auto-dependency Management**: Automatically installs required dependencies (Homebrew, gum, Ansible, yq)
- **Smart Detection**: Detects already installed tools and marks them with ✓
- **Pre-selection**: Automatically pre-selects uninstalled tools for convenience
- **Ansible Backend**: Leverages existing Ansible roles for robust installation
- **Logging**: Comprehensive logging to `/tmp/tool-installer-*.log`
- **Post-install Instructions**: Provides tool-specific configuration steps after installation

## Prerequisites

- macOS (Darwin)
- Bash shell
- Internet connection for downloading dependencies

## Installation

1. Clone the repository or download the installer:
```bash
git clone <repository-url>
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

### Workflow

1. **Dependency Check**: The script first checks for and installs required dependencies:
   - Homebrew (if not installed)
   - gum (UI toolkit)
   - Ansible (automation backend)
   - yq (YAML processor for better parsing)

2. **Tool Selection**: An interactive multi-select list shows all available tools:
   - Tools are categorized (cloud, vcs, runtime, etc.)
   - Installed tools are marked with ✓
   - Uninstalled tools are pre-selected by default
   - Use `Space` to toggle selection
   - Use `Enter` to confirm

3. **Confirmation**: Review selected tools and confirm installation

4. **Installation**: Ansible runs in the background with a progress spinner

5. **Post-Installation**: Tool-specific configuration instructions are displayed

## Available Tools

The installer supports the following tools:

| Tool | Category | Description |
|------|----------|-------------|
| AWS CLI | cloud | Amazon Web Services command-line interface |
| Git | vcs | Distributed version control system |
| GitHub CLI | vcs | GitHub's official command line tool |
| Ngrok | networking | Secure tunnels to localhost |
| Claude Code | ai | Anthropic's official CLI for Claude |
| Node.js | runtime | JavaScript runtime built on Chrome's V8 engine |
| VS Code | editor | Source code editor developed by Microsoft |

## Configuration

The installer uses configuration files from `tool-installer/config/`:

- `tools.yaml`: Tool definitions and metadata
- `ansible/playbook.yml`: Main Ansible playbook
- `ansible/roles/*/`: Individual tool installation roles

## Logging

Installation logs are saved to `/tmp/tool-installer-YYYYMMDD-HHMMSS.log`

The log includes:
- Dependency installation steps
- Tool detection results
- Ansible playbook execution output
- Error messages (if any)

## Troubleshooting

### Script fails with "This script requires macOS"

The installer only works on macOS. For other platforms, use the Python-based installer.

### Homebrew installation prompts for password

This is normal. Homebrew requires administrator privileges for initial setup.

### Tool installation fails

1. Check the log file shown at the end of execution
2. Ensure you have internet connectivity
3. Try running the installer again - it will skip already installed tools

### "gum: command not found"

The script should auto-install gum. If this fails:
```bash
brew install gum
```


## Development

### Adding New Tools

1. Add tool definition to `tool-installer/config/tools.yaml`
2. Create Ansible role in `tool-installer/config/ansible/roles/<tool_name>/`
3. The installer will automatically detect the new tool

### Debugging

Enable verbose logging by setting the log level in the script:
```bash
# Edit the script and add after line 14:
set -x  # Enable bash debug output
```

## License

[Your License Here]

## Contributing

Contributions are welcome! Please submit pull requests with:
- Tool additions in the YAML configuration
- Ansible role improvements
- Bug fixes to the shell script

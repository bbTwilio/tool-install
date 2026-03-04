#!/bin/bash
# Compatibility launcher for install-tools.sh
# Automatically finds and uses bash 4+ if available

# Try to find bash 4+ in common locations
BASH_PATHS=(
    "/usr/local/bin/bash"      # Homebrew on Intel Macs
    "/opt/homebrew/bin/bash"   # Homebrew on Apple Silicon Macs
    "/usr/bin/bash"             # System bash (might be updated)
    "/bin/bash"                 # Default location
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="${SCRIPT_DIR}/install-tools.sh"

# Find the first bash that is version 4+
for bash_path in "${BASH_PATHS[@]}"; do
    if [[ -x "$bash_path" ]]; then
        version=$("$bash_path" -c 'echo ${BASH_VERSION%%.*}')
        if [[ "$version" -ge 4 ]]; then
            echo "Using bash $bash_path (version $("$bash_path" -c 'echo $BASH_VERSION'))"
            exec "$bash_path" "$INSTALLER" "$@"
        fi
    fi
done

# If we get here, no bash 4+ was found
echo "Error: bash 4+ is required but not found."
echo ""
echo "Please install a newer version of bash:"
echo "  brew install bash"
echo ""
echo "Then run this script again."
exit 1
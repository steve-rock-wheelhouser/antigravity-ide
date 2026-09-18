#!/bin/bash
set -euo pipefail

# Ensure script runs from its own directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure standard system paths are in the PATH
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:${PATH:-}"

# Parse command line options
TARGET=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target|-t)
            TARGET="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") [--target rocky|fedora]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $(basename "$0") [--target rocky|fedora]"
            exit 1
            ;;
    esac
done

# If target is not explicitly specified, auto-detect from OS
if [ -z "$TARGET" ]; then
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [[ "${ID:-}" == "rocky" || "${ID_LIKE:-}" =~ rhel ]]; then
            TARGET="rocky"
        elif [[ "${ID:-}" == "fedora" ]]; then
            TARGET="fedora"
        fi
    fi
fi

# Fallback default if still undetermined
TARGET="${TARGET:-rocky}"

if [ "$TARGET" == "rocky" ]; then
    REPO_DIR="$(cd "$SCRIPT_DIR/../rocky-repo" && pwd)"
    REPO_NAME="Rocky Linux (rocky-repo)"
elif [ "$TARGET" == "fedora" ]; then
    REPO_DIR="$(cd "$SCRIPT_DIR/../fedora-repo" && pwd)"
    REPO_NAME="Fedora (fedora-repo)"
else
    echo "Error: Unknown target repository '$TARGET'. Must be 'rocky' or 'fedora'."
    exit 1
fi

echo "Publishing to target repository: $REPO_NAME"
echo "Repository path: $REPO_DIR"

echo "Locating the most recent Antigravity IDE RPM build..."
# Find the most recently modified antigravity-ide RPM file in the script directory
LATEST_RPM=$(ls -t "$SCRIPT_DIR"/antigravity-ide-*.rpm 2>/dev/null | head -n 1)

if [ -z "$LATEST_RPM" ]; then
    echo "Error: No Antigravity IDE RPM build found in $SCRIPT_DIR."
    echo "Please run ./build_rpm.sh first."
    exit 1
fi

RPM_FILENAME=$(basename "$LATEST_RPM")
echo "Found most recent build: $RPM_FILENAME"

# Verify destination repository exists
if [ ! -d "$REPO_DIR" ]; then
    echo "Error: Target repository directory not found at $REPO_DIR"
    exit 1
fi

# Copy the new build to the repository
echo "Copying $RPM_FILENAME to $REPO_DIR..."
cp "$LATEST_RPM" "$REPO_DIR/"

# Clean up older antigravity-ide builds in the repository, keeping only the 2 most recent ones
echo "Cleaning up old Antigravity IDE builds in $REPO_DIR (keeping only the 2 most recent)..."
RPM_FILES=("$REPO_DIR"/antigravity-ide-*.rpm)
if [ -f "${RPM_FILES[0]}" ]; then
    ls -t "${RPM_FILES[@]}" 2>/dev/null | tail -n +3 | while read -r old_rpm; do
        if [ -f "$old_rpm" ]; then
            echo "Removing older build: $(basename "$old_rpm")"
            rm -f "$old_rpm"
        fi
    done
fi

# Locate and copy the most recent release RPM build if it exists
echo "Locating the most recent release RPM build..."
RELEASE_MATCHES=("$SCRIPT_DIR"/steve-rock-wheelhouser-release-*.rpm)
if [ -e "${RELEASE_MATCHES[0]}" ]; then
    LATEST_RELEASE_RPM=$(ls -t "${RELEASE_MATCHES[@]}" | head -n 1)
    RELEASE_FILENAME=$(basename "$LATEST_RELEASE_RPM")
    echo "Found most recent release build: $RELEASE_FILENAME"
    
    # Copy the new release build to the repository
    echo "Copying $RELEASE_FILENAME to $REPO_DIR..."
    cp "$LATEST_RELEASE_RPM" "$REPO_DIR/"
    
    # Clean up older release builds in the repository, keeping only the 1 most recent one
    echo "Cleaning up old release builds in $REPO_DIR (keeping only the most recent)..."
    RELEASE_FILES=("$REPO_DIR"/steve-rock-wheelhouser-release-*.rpm)
    if [ -f "${RELEASE_FILES[0]}" ]; then
        ls -t "${RELEASE_FILES[@]}" 2>/dev/null | tail -n +2 | while read -r old_rpm; do
            if [ -f "$old_rpm" ]; then
                echo "Removing older release build: $(basename "$old_rpm")"
                rm -f "$old_rpm"
            fi
        done
    fi
else
    echo "No release RPM build found in $SCRIPT_DIR. Skipping release RPM publishing."
fi


# Run the repository update script (which signs, rebuilds metadata, commits and pushes)
if [ -f "$REPO_DIR/update_repo.sh" ]; then
    echo "Running update_repo.sh in $REPO_DIR..."
    (cd "$REPO_DIR" && ./update_repo.sh)
else
    echo "Error: update_repo.sh not found in $REPO_DIR"
    exit 1
fi

echo "Publishing complete!"

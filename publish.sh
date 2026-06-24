#!/bin/bash
set -euo pipefail

# Ensure script runs from its own directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Define target repository directory
FEDORA_REPO_DIR="$(cd "$SCRIPT_DIR/../fedora-repo" && pwd)"

echo "Locating the most recent Antigravity RPM build..."
# Find the most recently modified antigravity RPM file in the script directory
LATEST_RPM=$(ls -t "$SCRIPT_DIR"/antigravity-*.rpm 2>/dev/null | head -n 1)

if [ -z "$LATEST_RPM" ]; then
    echo "Error: No Antigravity RPM build found in $SCRIPT_DIR."
    echo "Please run ./build_rpm.sh first."
    exit 1
fi

RPM_FILENAME=$(basename "$LATEST_RPM")
echo "Found most recent build: $RPM_FILENAME"

# Verify destination repository exists
if [ ! -d "$FEDORA_REPO_DIR" ]; then
    echo "Error: Fedora repository directory not found at $FEDORA_REPO_DIR"
    exit 1
fi

# Clean up older antigravity builds in the repository to only keep the latest one
echo "Removing older Antigravity builds from $FEDORA_REPO_DIR..."
rm -f "$FEDORA_REPO_DIR"/antigravity-*.rpm

# Copy the new build to the repository
echo "Copying $RPM_FILENAME to $FEDORA_REPO_DIR..."
cp "$LATEST_RPM" "$FEDORA_REPO_DIR/"

# Run the repository update script (which signs, rebuilds metadata, commits and pushes)
if [ -f "$FEDORA_REPO_DIR/update_repo.sh" ]; then
    echo "Running update_repo.sh in $FEDORA_REPO_DIR..."
    (cd "$FEDORA_REPO_DIR" && ./update_repo.sh)
else
    echo "Error: update_repo.sh not found in $FEDORA_REPO_DIR"
    exit 1
fi

echo "Publishing complete!"

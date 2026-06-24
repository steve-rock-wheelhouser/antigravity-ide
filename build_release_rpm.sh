#!/bin/bash
set -euo pipefail

# Ensure standard system paths are in the PATH
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:${PATH:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Define paths
FEDORA_REPO_DIR="$(cd "$SCRIPT_DIR/../fedora-repo" && pwd)"
RPMBUILD_DIR="$SCRIPT_DIR/rpmbuild-release"
SPEC_FILE="$SCRIPT_DIR/steve-rock-wheelhouser-release.spec"
REPO_FILE="$FEDORA_REPO_DIR/steve-rock-wheelhouser.repo"
GPG_KEY="$FEDORA_REPO_DIR/steve-rock-wheelhouser-gpg.key"

# Verify files exist
for file in "$SPEC_FILE" "$REPO_FILE" "$GPG_KEY"; do
    if [ ! -f "$file" ]; then
        echo "Error: Required file not found: $file"
        exit 1
    fi
done

echo "Setting up release rpmbuild directories..."
rm -rf "$RPMBUILD_DIR"
mkdir -p "$RPMBUILD_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

echo "Copying sources..."
cp "$REPO_FILE" "$RPMBUILD_DIR/SOURCES/steve-rock-wheelhouser.repo"
cp "$GPG_KEY" "$RPMBUILD_DIR/SOURCES/steve-rock-wheelhouser-gpg.key"
cp "$SPEC_FILE" "$RPMBUILD_DIR/SPECS/steve-rock-wheelhouser-release.spec"

echo "Building release RPM..."
rpmbuild --define "_topdir $RPMBUILD_DIR" -ba "$RPMBUILD_DIR/SPECS/steve-rock-wheelhouser-release.spec"

echo "Copying built release RPMs to workspace root..."
cp "$RPMBUILD_DIR"/RPMS/*/*.rpm "$SCRIPT_DIR/"

echo "--------------------------------------------------"
echo "Release RPM build complete!"
echo "Built files:"
ls -la "$SCRIPT_DIR"/steve-rock-wheelhouser-release-*.rpm
echo "--------------------------------------------------"

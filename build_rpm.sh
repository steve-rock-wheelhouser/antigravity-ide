#!/bin/bash
set -euo pipefail

# Print usage instructions
usage() {
    cat <<EOF
Usage: $(basename "$0")

Options:
  -h, --help    Show this help message and exit
EOF
}

# Handle help flags
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Get directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPMBUILD_DIR="$SCRIPT_DIR/rpmbuild"
SPEC_FILE="$SCRIPT_DIR/antigravity.spec"
ICON_FILE="$SCRIPT_DIR/assets/icons/antigravity-icon.png"

if [ ! -f "$ICON_FILE" ]; then
    echo "Error: Cannot find icon at $ICON_FILE. Exiting."
    exit 1
fi

if [ ! -f "$SPEC_FILE" ]; then
    echo "Error: Cannot find spec file at $SPEC_FILE. Exiting."
    exit 1
fi

echo "Setting up local rpmbuild directories..."
rm -rf "$RPMBUILD_DIR"
mkdir -p "$RPMBUILD_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

echo "Copying sources to rpmbuild directory..."
cp "$ICON_FILE" "$RPMBUILD_DIR/SOURCES/antigravity-icon.png"
cp "$SPEC_FILE" "$RPMBUILD_DIR/SPECS/antigravity.spec"

echo "Building RPM..."
rpmbuild --define "_topdir $RPMBUILD_DIR" -ba "$RPMBUILD_DIR/SPECS/antigravity.spec"

echo "Copying built RPMs to workspace root..."
cp "$RPMBUILD_DIR"/RPMS/*/*.rpm "$SCRIPT_DIR/"

echo "--------------------------------------------------"
echo "RPM build complete!"
echo "Built files:"
ls -la "$SCRIPT_DIR"/*.rpm
echo "--------------------------------------------------"

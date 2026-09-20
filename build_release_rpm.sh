#!/bin/bash
set -euo pipefail

# Ensure standard system paths are in the PATH
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:${PATH:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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

TARGET="${TARGET:-rocky}"
REPO_DIR="$(cd "$SCRIPT_DIR/../wheelhouserllc-repo" && pwd)"

if [ "$TARGET" == "rocky" ]; then
    REPO_NAME="Rocky Linux (rocky)"
    MACRO_DEFINE='--define "rhel 10" --define "dist .el10"'
elif [ "$TARGET" == "fedora" ]; then
    REPO_NAME="Fedora (fedora)"
    MACRO_DEFINE='--define "fedora 44" --define "dist .fc44"'
else
    echo "Error: Unknown target repository '$TARGET'. Must be 'rocky' or 'fedora'."
    exit 1
fi

echo "Building release RPM for: $REPO_NAME"
echo "Repository path: $REPO_DIR"

RPMBUILD_DIR="$SCRIPT_DIR/rpmbuild-release"
SPEC_FILE="$SCRIPT_DIR/steve-rock-wheelhouser-release.spec"
ROCKY_REPO_FILE="$REPO_DIR/steve-rock-wheelhouser-rocky.repo"
FEDORA_REPO_FILE="$REPO_DIR/steve-rock-wheelhouser-fedora.repo"
GPG_KEY="$REPO_DIR/steve-rock-wheelhouser-gpg.key"

# Verify files exist
for file in "$SPEC_FILE" "$ROCKY_REPO_FILE" "$FEDORA_REPO_FILE" "$GPG_KEY"; do
    if [ ! -f "$file" ]; then
        echo "Error: Required file not found: $file"
        exit 1
    fi
done

echo "Setting up release rpmbuild directories..."
rm -rf "$RPMBUILD_DIR"
mkdir -p "$RPMBUILD_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

echo "Copying sources..."
cp "$ROCKY_REPO_FILE" "$RPMBUILD_DIR/SOURCES/steve-rock-wheelhouser-rocky.repo"
cp "$FEDORA_REPO_FILE" "$RPMBUILD_DIR/SOURCES/steve-rock-wheelhouser-fedora.repo"
cp "$GPG_KEY" "$RPMBUILD_DIR/SOURCES/steve-rock-wheelhouser-gpg.key"
cp "$SPEC_FILE" "$RPMBUILD_DIR/SPECS/steve-rock-wheelhouser-release.spec"

echo "Building release RPM..."
eval rpmbuild --define \"_topdir $RPMBUILD_DIR\" "$MACRO_DEFINE" -ba \"$RPMBUILD_DIR/SPECS/steve-rock-wheelhouser-release.spec\"

echo "Signing built release RPMs..."
rpmsign --addsign "$RPMBUILD_DIR"/RPMS/*/*.rpm

echo "Copying built release RPMs to workspace root..."
cp "$RPMBUILD_DIR"/RPMS/*/*.rpm "$SCRIPT_DIR/"

echo "--------------------------------------------------"
echo "Release RPM build complete!"
echo "Built files:"
ls -la "$SCRIPT_DIR"/steve-rock-wheelhouser-release-*.rpm
echo "--------------------------------------------------"

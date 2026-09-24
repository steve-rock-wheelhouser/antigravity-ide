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
if [[ "$(basename "$SCRIPT_DIR")" == "build-linux" ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi
RPMBUILD_DIR="$PROJECT_ROOT/rpmbuild"
SPEC_FILE="$PROJECT_ROOT/antigravity-ide.spec"
ICON_FILE="$PROJECT_ROOT/assets/icons/antigravity-ide-icon.png"

LICENSE_FILE="$PROJECT_ROOT/LICENSE"
METAINFO_FILE="$PROJECT_ROOT/assets/com.wheelhouser.antigravity-ide.metainfo.xml"
HICOLOR_TAR="$PROJECT_ROOT/assets/icons/hicolor-icons.tar.gz"

if [ ! -f "$ICON_FILE" ]; then
    echo "Error: Cannot find icon at $ICON_FILE. Exiting."
    exit 1
fi

if [ ! -f "$LICENSE_FILE" ]; then
    echo "Error: Cannot find license at $LICENSE_FILE. Exiting."
    exit 1
fi

if [ ! -f "$METAINFO_FILE" ]; then
    echo "Error: Cannot find metainfo at $METAINFO_FILE. Exiting."
    exit 1
fi

if [ ! -f "$HICOLOR_TAR" ]; then
    echo "Error: Cannot find hicolor tarball at $HICOLOR_TAR. Generating..."
    tar -czf "$HICOLOR_TAR" -C "$PROJECT_ROOT/assets/icons" hicolor
fi

if [ ! -f "$SPEC_FILE" ]; then
    echo "Error: Cannot find spec file at $SPEC_FILE. Exiting."
    exit 1
fi

BUMP_RELEASE=false
TARGET="all"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bump)
            BUMP_RELEASE=true
            shift
            ;;
        --no-bump)
            BUMP_RELEASE=false
            shift
            ;;
        --target|-t)
            TARGET="$2"
            shift 2
            ;;
        --all)
            TARGET="all"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

if [[ "$BUMP_RELEASE" == true ]]; then
    echo "Incrementing build/release number in spec file..."
    if grep -qE "^%define[[:space:]]+release_number" "$SPEC_FILE"; then
        CURRENT_RELEASE=$(grep -E "^%define[[:space:]]+release_number" "$SPEC_FILE" | awk '{print $3}')
        if [[ "$CURRENT_RELEASE" =~ ^[0-9]+$ ]]; then
            NEW_RELEASE=$((CURRENT_RELEASE + 1))
            sed -i -E "s/^(%define[[:space:]]+release_number[[:space:]]+)[0-9]+/\1$NEW_RELEASE/" "$SPEC_FILE"
            echo "Release version incremented from $CURRENT_RELEASE to $NEW_RELEASE."
        else
            echo "Warning: Could not parse numeric release version from %define release_number in $SPEC_FILE"
        fi
    elif grep -qE "^Release:" "$SPEC_FILE"; then
        RELEASE_LINE=$(grep -E "^Release:" "$SPEC_FILE")
        CURRENT_RELEASE=$(echo "$RELEASE_LINE" | sed -E 's/^Release:[[:space:]]*([0-9]+).*/\1/')
        if [[ "$CURRENT_RELEASE" =~ ^[0-9]+$ ]]; then
            NEW_RELEASE=$((CURRENT_RELEASE + 1))
            sed -i -E "s/^(Release:[[:space:]]*)$CURRENT_RELEASE/\1$NEW_RELEASE/" "$SPEC_FILE"
            echo "Release version incremented from $CURRENT_RELEASE to $NEW_RELEASE."
        else
            echo "Warning: Could not parse numeric release version from: $RELEASE_LINE"
        fi
    else
        echo "Warning: Release tag not found in $SPEC_FILE"
    fi
else
    echo "Preserving release number in spec file (build mode)..."
fi

echo "Setting up local rpmbuild directories..."
rm -rf "$RPMBUILD_DIR"
mkdir -p "$RPMBUILD_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

echo "Copying sources to rpmbuild directory..."
cp "$ICON_FILE" "$RPMBUILD_DIR/SOURCES/antigravity-ide-icon.png"
cp "$LICENSE_FILE" "$RPMBUILD_DIR/SOURCES/LICENSE"
cp "$METAINFO_FILE" "$RPMBUILD_DIR/SOURCES/com.wheelhouser.antigravity-ide.metainfo.xml"
cp "$HICOLOR_TAR" "$RPMBUILD_DIR/SOURCES/hicolor-icons.tar.gz"
cp "$SPEC_FILE" "$RPMBUILD_DIR/SPECS/antigravity-ide.spec"

echo "Building RPM package(s) for target: $TARGET..."
if [[ "$TARGET" == "all" ]]; then
    echo "--> Building Enterprise Linux 10 RPM (Rocky 10 / AlmaLinux 10)..."
    rpmbuild --define "_topdir $RPMBUILD_DIR" --define "dist .el10" -ba "$RPMBUILD_DIR/SPECS/antigravity-ide.spec"
    echo "--> Building Fedora 44 RPM..."
    rpmbuild --define "_topdir $RPMBUILD_DIR" --define "dist .fc44" -ba "$RPMBUILD_DIR/SPECS/antigravity-ide.spec"
elif [[ "$TARGET" == "fedora" ]]; then
    echo "--> Building Fedora 44 RPM..."
    rpmbuild --define "_topdir $RPMBUILD_DIR" --define "dist .fc44" -ba "$RPMBUILD_DIR/SPECS/antigravity-ide.spec"
else
    echo "--> Building Enterprise Linux 10 RPM ($TARGET)..."
    rpmbuild --define "_topdir $RPMBUILD_DIR" --define "dist .el10" -ba "$RPMBUILD_DIR/SPECS/antigravity-ide.spec"
fi

if command -v rpmsign >/dev/null 2>&1; then
    echo "Signing built RPMs..."
    rpmsign --addsign "$RPMBUILD_DIR"/RPMS/*/*.rpm 2>/dev/null || true
else
    echo "==> Note: rpmsign not present on this node; package will be signed centrally by repository orchestrator."
fi

DISTRO_NAME="rocky"
DISTRO_VER="10"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_NAME="${ID:-rocky}"
    DISTRO_VER=$(echo "${VERSION_ID:-10}" | cut -d. -f1)
fi

STANDARDIZED_OUTPUT_DIR="$PROJECT_ROOT/build-linux/Output/$DISTRO_NAME/$DISTRO_VER"
mkdir -p "$STANDARDIZED_OUTPUT_DIR"
cp -f "$RPMBUILD_DIR"/RPMS/*/*.rpm "$STANDARDIZED_OUTPUT_DIR/"
cp -f "$RPMBUILD_DIR"/RPMS/*/*.rpm "$PROJECT_ROOT/"

if [[ "$TARGET" == "all" ]]; then
    mkdir -p "$PROJECT_ROOT/build-linux/Output/fedora/44"
    mkdir -p "$PROJECT_ROOT/build-linux/Output/almalinux/10"
    mkdir -p "$PROJECT_ROOT/build-linux/Output/rocky/10"
    cp -f "$RPMBUILD_DIR"/RPMS/*/*fc44*.rpm "$PROJECT_ROOT/build-linux/Output/fedora/44/" 2>/dev/null || true
    cp -f "$RPMBUILD_DIR"/RPMS/*/*el10*.rpm "$PROJECT_ROOT/build-linux/Output/almalinux/10/" 2>/dev/null || true
    cp -f "$RPMBUILD_DIR"/RPMS/*/*el10*.rpm "$PROJECT_ROOT/build-linux/Output/rocky/10/" 2>/dev/null || true
fi

echo "--------------------------------------------------"
echo "RPM build complete!"
echo "Built files:"
ls -la "$STANDARDIZED_OUTPUT_DIR"/*.rpm
echo "--------------------------------------------------"

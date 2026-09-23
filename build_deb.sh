#!/usr/bin/env bash
# ==============================================================================
# build_deb.sh - Native Debian / Ubuntu (.deb) Packaging Script for Antigravity IDE
# Wheelhouser LLC (c) 2026
# ==============================================================================
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Builds native .deb package for Debian 13 (Trixie) and Ubuntu 24.

Options:
  --no-bump      Preserve release number in spec/control file
  --target, -t   Target distro (debian, ubuntu, or all)
  -h, --help     Show this help message and exit
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC_FILE="$SCRIPT_DIR/antigravity-ide.spec"
ICON_FILE="$SCRIPT_DIR/assets/icons/antigravity-ide-icon.png"
LICENSE_FILE="$SCRIPT_DIR/LICENSE"

if [ ! -f "$ICON_FILE" ]; then
    echo "❌ Error: Cannot find icon at $ICON_FILE" >&2
    exit 1
fi

if [ ! -f "$LICENSE_FILE" ]; then
    echo "❌ Error: Cannot find license at $LICENSE_FILE" >&2
    exit 1
fi

if [ ! -f "$SPEC_FILE" ]; then
    echo "❌ Error: Cannot find spec file at $SPEC_FILE" >&2
    exit 1
fi

NO_BUMP=false
TARGET="all"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-bump)
            NO_BUMP=true
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

# Check if dpkg-deb is available
DPKG_DEB_CMD=""
if command -v dpkg-deb >/dev/null 2>&1; then
    DPKG_DEB_CMD="dpkg-deb"
elif [ -x "$HOME/.local/bin/dpkg-deb" ]; then
    DPKG_DEB_CMD="$HOME/.local/bin/dpkg-deb"
else
    echo "❌ Error: dpkg-deb is required to build Debian packages." >&2
    exit 1
fi

# Parse application version and release from spec file
APP_VERSION=$(awk 'tolower($1)=="version:" {print $2; exit}' "$SPEC_FILE")
if [ -z "$APP_VERSION" ]; then
    APP_VERSION="1.0.0"
fi

if [[ "$NO_BUMP" == false ]]; then
    if grep -qE "^Release:" "$SPEC_FILE"; then
        CURRENT_RELEASE=$(grep -E "^Release:" "$SPEC_FILE" | sed -E 's/^Release:[[:space:]]*([0-9]+).*/\1/')
        if [[ "$CURRENT_RELEASE" =~ ^[0-9]+$ ]]; then
            NEW_RELEASE=$((CURRENT_RELEASE + 1))
            sed -i -E "s/^(Release:[[:space:]]*)$CURRENT_RELEASE/\1$NEW_RELEASE/" "$SPEC_FILE"
            echo "==> Incremented release from $CURRENT_RELEASE to $NEW_RELEASE"
            APP_RELEASE="$NEW_RELEASE"
        else
            APP_RELEASE=$(grep -E "^Release:" "$SPEC_FILE" | sed -E 's/^Release:[[:space:]]*//; s/%\{\??dist\}//g; s/[^0-9]+$//')
        fi
    else
        APP_RELEASE="1"
    fi
else
    APP_RELEASE=$(grep -E "^Release:" "$SPEC_FILE" | sed -E 's/^Release:[[:space:]]*//; s/%\{\??dist\}//g; s/[^0-9]+$//')
fi

# Detect distribution safely without clobbering variables
DISTRO_NAME="debian"
DISTRO_VER="13"
if [ -f /etc/os-release ]; then
    DISTRO_NAME="$(grep -E '^ID=' /etc/os-release | head -n 1 | cut -d= -f2 | tr -d '\"')"
    DISTRO_VER="$(grep -E '^VERSION_ID=' /etc/os-release | head -n 1 | cut -d= -f2 | tr -d '\"' | cut -d. -f1)"
fi
DISTRO_NAME="${DISTRO_NAME:-debian}"
DISTRO_VER="${DISTRO_VER:-13}"

echo "========================================================================"
echo "🔨 Building Debian/Ubuntu Package: antigravity-ide v${APP_VERSION}-${APP_RELEASE}"
echo "📍 Distro Detected: ${DISTRO_NAME} ${DISTRO_VER}"
echo "========================================================================"

BUILD_ROOT=$(mktemp -d -t antigravity-deb-build-XXXXXX)
chmod 755 "$BUILD_ROOT"
cleanup() {
    rm -rf "$BUILD_ROOT"
}
trap cleanup EXIT

# 1. Prepare directory structure
mkdir -p "$BUILD_ROOT/DEBIAN"
mkdir -p "$BUILD_ROOT/usr/bin"
mkdir -p "$BUILD_ROOT/usr/share/applications"
mkdir -p "$BUILD_ROOT/usr/share/pixmaps"
mkdir -p "$BUILD_ROOT/usr/share/doc/antigravity-ide"

# 2. Generate DEBIAN/control
cat <<EOF > "$BUILD_ROOT/DEBIAN/control"
Package: antigravity-ide
Version: ${APP_VERSION}-${APP_RELEASE}
Section: devel
Priority: optional
Architecture: all
Essential: no
Maintainer: Steve Rock <steve.rock@wheelhouser.com>
Depends: curl, tar, xdg-utils, desktop-file-utils, libnotify4, libxss1, libxkbfile1, libgbm1, libnss3, gnome-keyring, libsecret-1-0, libasound2t64 | libasound2
Provides: antigravity (= ${APP_VERSION}-${APP_RELEASE})
Replaces: antigravity (<= 1.0.0-12)
Conflicts: antigravity (<= 1.0.0-12)
Homepage: https://github.com/steve-rock-wheelhouser/antigravity-ide
Description: Antigravity IDE launcher utility
 Open-source launcher and desktop integration utility for Antigravity IDE on
 Debian and Ubuntu. Automatically downloads and installs the official Google
 Antigravity IDE binary payload on installation.
EOF
chmod 644 "$BUILD_ROOT/DEBIAN/control"

# 3. Generate DEBIAN/preinst
cat <<'EOF' > "$BUILD_ROOT/DEBIAN/preinst"
#!/bin/sh
set -e
echo "Terminating any running Antigravity IDE processes..."
pkill -x antigravity-ide || true
exit 0
EOF
chmod 755 "$BUILD_ROOT/DEBIAN/preinst"

# 4. Generate DEBIAN/postinst
cat <<'EOF' > "$BUILD_ROOT/DEBIAN/postinst"
#!/bin/sh
set -e
INSTALL_DIR="/usr/share/antigravity-ide"
echo "Downloading Antigravity IDE package from Google..."
mkdir -p "$INSTALL_DIR"
TEMP_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz"

if curl -sL -o "$TEMP_DIR/Antigravity-IDE.tar.gz" "$URL"; then
    echo "Extracting payload..."
    tar -xzf "$TEMP_DIR/Antigravity-IDE.tar.gz" -C "$TEMP_DIR"
    BIN_FILE=$(find "$TEMP_DIR" -name "chrome-sandbox" -type f | head -n 1)
    if [ -n "$BIN_FILE" ]; then
        SOURCE_DIR=$(dirname "$BIN_FILE")
        rm -rf "$INSTALL_DIR"/*
        cp -r "$SOURCE_DIR/"* "$INSTALL_DIR/"

        chown -R root:root "$INSTALL_DIR" 2>/dev/null || true
        chmod -R u+rwX,go+rX "$INSTALL_DIR"
        chmod +x "$INSTALL_DIR/antigravity-ide" 2>/dev/null || true
        chmod +x "$INSTALL_DIR/bin/antigravity-ide" 2>/dev/null || true

        if [ -f "$INSTALL_DIR/chrome-sandbox" ]; then
            chown root:root "$INSTALL_DIR/chrome-sandbox" 2>/dev/null || true
            chmod 4755 "$INSTALL_DIR/chrome-sandbox" 2>/dev/null || true
        fi

        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database /usr/share/applications || true
        fi

        echo "Antigravity IDE payload installed successfully in $INSTALL_DIR."
    else
        echo "Error: Antigravity IDE binary could not be found in archive." >&2
        exit 1
    fi
else
    echo "Error: Failed to download Antigravity IDE from $URL." >&2
    exit 1
fi
exit 0
EOF
chmod 755 "$BUILD_ROOT/DEBIAN/postinst"

# 5. Generate DEBIAN/postrm
cat <<'EOF' > "$BUILD_ROOT/DEBIAN/postrm"
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    echo "Removing Antigravity IDE system-wide files..."
    rm -rf /usr/share/antigravity-ide
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications || true
fi
exit 0
EOF
chmod 755 "$BUILD_ROOT/DEBIAN/postrm"

# 6. Install binaries, icons, and desktop entries into package payload
cat <<'EOF' > "$BUILD_ROOT/usr/bin/antigravity-ide"
#!/usr/bin/bash
# Clean up any stale antigravity-ide processes (excluding this wrapper script) to release the single-instance lock
pgrep -x antigravity-ide | grep -v "^$$$" | xargs kill -9 2>/dev/null || true
exec /usr/share/antigravity-ide/bin/antigravity-ide "$@"
EOF
chmod 755 "$BUILD_ROOT/usr/bin/antigravity-ide"

ln -sf antigravity-ide "$BUILD_ROOT/usr/bin/antigravity"

cat <<EOF > "$BUILD_ROOT/usr/share/applications/antigravity-ide.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Antigravity IDE
Comment=Launch Antigravity IDE
Exec=/usr/bin/antigravity-ide %u
Icon=antigravity-ide-icon
Terminal=false
Categories=Development;IDE;Utility;
MimeType=x-scheme-handler/antigravity;
StartupWMClass=antigravity
EOF
chmod 644 "$BUILD_ROOT/usr/share/applications/antigravity-ide.desktop"

cp -f "$ICON_FILE" "$BUILD_ROOT/usr/share/pixmaps/antigravity-ide-icon.png"
chmod 644 "$BUILD_ROOT/usr/share/pixmaps/antigravity-ide-icon.png"

cp -f "$LICENSE_FILE" "$BUILD_ROOT/usr/share/doc/antigravity-ide/copyright"
chmod 644 "$BUILD_ROOT/usr/share/doc/antigravity-ide/copyright"

# 7. Build .deb package
DEB_NAME="antigravity-ide_${APP_VERSION}-${APP_RELEASE}_all.deb"
LOCAL_DEB="$SCRIPT_DIR/$DEB_NAME"

echo "==> Invoking dpkg-deb..."
"$DPKG_DEB_CMD" --build --root-owner-group "$BUILD_ROOT" "$LOCAL_DEB"

# 8. Standardize output staging
OUTPUT_BASE="$SCRIPT_DIR/build-linux/Output"
STANDARDIZED_OUTPUT_DIR="$OUTPUT_BASE/$DISTRO_NAME/$DISTRO_VER"
mkdir -p "$STANDARDIZED_OUTPUT_DIR"
cp -f "$LOCAL_DEB" "$STANDARDIZED_OUTPUT_DIR/"

# If building on debian, also mirror to ubuntu if target is all (or vice-versa)
if [[ "$TARGET" == "all" ]]; then
    if [ "$DISTRO_NAME" = "debian" ]; then
        mkdir -p "$OUTPUT_BASE/ubuntu/24"
        cp -f "$LOCAL_DEB" "$OUTPUT_BASE/ubuntu/24/"
    elif [ "$DISTRO_NAME" = "ubuntu" ]; then
        mkdir -p "$OUTPUT_BASE/debian/13"
        cp -f "$LOCAL_DEB" "$OUTPUT_BASE/debian/13/"
    fi
fi

echo "--------------------------------------------------"
echo "✅ Debian package build complete!"
echo "Built files:"
ls -la "$STANDARDIZED_OUTPUT_DIR"/antigravity-ide*.deb
echo "--------------------------------------------------"

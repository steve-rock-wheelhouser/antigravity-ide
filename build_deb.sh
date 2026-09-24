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
if [[ "$(basename "$SCRIPT_DIR")" == "build-linux" ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi
SPEC_FILE="$PROJECT_ROOT/antigravity-ide.spec"
ICON_FILE="$PROJECT_ROOT/assets/icons/antigravity-ide-icon.png"
LICENSE_FILE="$PROJECT_ROOT/LICENSE"

METAINFO_FILE="$PROJECT_ROOT/assets/com.wheelhouser.antigravity-ide.metainfo.xml"

if [ ! -f "$ICON_FILE" ]; then
    echo "❌ Error: Cannot find icon at $ICON_FILE" >&2
    exit 1
fi

if [ ! -f "$LICENSE_FILE" ]; then
    echo "❌ Error: Cannot find license at $LICENSE_FILE" >&2
    exit 1
fi

if [ ! -f "$METAINFO_FILE" ]; then
    echo "❌ Error: Cannot find metainfo at $METAINFO_FILE" >&2
    exit 1
fi

if [ ! -f "$SPEC_FILE" ]; then
    echo "❌ Error: Cannot find spec file at $SPEC_FILE" >&2
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

if grep -qE "^%define[[:space:]]+release_number" "$SPEC_FILE"; then
    CURRENT_RELEASE=$(grep -E "^%define[[:space:]]+release_number" "$SPEC_FILE" | awk '{print $3}')
    APP_RELEASE="$CURRENT_RELEASE"
    if [[ "$BUMP_RELEASE" == true ]]; then
        if [[ "$CURRENT_RELEASE" =~ ^[0-9]+$ ]]; then
            NEW_RELEASE=$((CURRENT_RELEASE + 1))
            sed -i -E "s/^(%define[[:space:]]+release_number[[:space:]]+)[0-9]+/\1$NEW_RELEASE/" "$SPEC_FILE"
            echo "==> Incremented release from $CURRENT_RELEASE to $NEW_RELEASE"
            APP_RELEASE="$NEW_RELEASE"
        fi
    fi
elif [[ "$BUMP_RELEASE" == true ]]; then
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
mkdir -p "$BUILD_ROOT/usr/share/metainfo"
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
Homepage: https://wheelhouser.com/products/antigravity-ide.html
Description: Advanced AI-Powered Agentic Coding & Development Suite
 This Linux wrapper/installer from Wheelhouser LLC simplifies and automates the
 installation of Antigravity IDE, Google's next-generation integrated development
 environment and intelligent coding companion. Powered by autonomous
 AI agentic architecture, Antigravity IDE empowers developers to create, debug,
 refactor, and test complex software systems with speed and confidence.
EOF
chmod 644 "$BUILD_ROOT/DEBIAN/control"

# 3. Generate DEBIAN/preinst
cat <<'EOF' > "$BUILD_ROOT/DEBIAN/preinst"
#!/bin/sh
set -e
exit 0
EOF
chmod 755 "$BUILD_ROOT/DEBIAN/preinst"

# 4. Generate DEBIAN/postinst
cat <<'EOF' > "$BUILD_ROOT/DEBIAN/postinst"
#!/bin/sh
set -e
INSTALL_DIR="/usr/share/antigravity-ide"
echo "Deploying Antigravity IDE package..."
mkdir -p "$INSTALL_DIR"
TEMP_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

ARCHIVE="$TEMP_DIR/Antigravity-IDE.tar.gz"
DOWNLOADED=false

# 1. Check for pre-existing extracted payload directory first
for candidate_dir in \
    /root/Downloads/"Antigravity IDE" \
    /home/*/Downloads/"Antigravity IDE"; do
    if [ -d "$candidate_dir" ] && [ -f "$candidate_dir/chrome-sandbox" ]; then
        echo "Found pre-extracted payload at $candidate_dir"
        cp -r "$candidate_dir/"* "$INSTALL_DIR/"
        DOWNLOADED=true
        break
    fi
done

# 2. Check for pre-existing local download first
if [ "$DOWNLOADED" = false ]; then
    for candidate in \
        /root/Downloads/"Antigravity IDE.tar.gz" \
        /root/Downloads/"Antigravity-IDE.tar.gz" \
        /home/*/Downloads/"Antigravity IDE.tar.gz" \
        /home/*/Downloads/"Antigravity-IDE.tar.gz"; do
        if [ -f "$candidate" ] && gzip -t "$candidate" 2>/dev/null; then
            echo "Found valid cached payload at $candidate"
            cp "$candidate" "$ARCHIVE"
            DOWNLOADED=true
            break
        fi
    done
fi

if [ "$DOWNLOADED" = false ]; then
    LOCAL_URL1="https://staging.wheelhouser.com/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
    LOCAL_URL2="http://10.0.0.166/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
    REMOTE_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz"

    if curl -s -f -m 3 --connect-timeout 2 -o "$ARCHIVE" "$LOCAL_URL1" 2>/dev/null && [ -f "$ARCHIVE" ] && gzip -t "$ARCHIVE" 2>/dev/null; then
        echo "Downloaded payload from Wheelhouser Staging Hub (staging.wheelhouser.com)"
        DOWNLOADED=true
    elif curl -s -f -m 3 --connect-timeout 2 -o "$ARCHIVE" "$LOCAL_URL2" 2>/dev/null && [ -f "$ARCHIVE" ] && gzip -t "$ARCHIVE" 2>/dev/null; then
        echo "Downloaded payload from Wheelhouser Staging Hub (10.0.0.166)"
        DOWNLOADED=true
    else
        rm -f "$ARCHIVE"
        echo "Downloading payload from Google CDN..."
        if curl -4 -sL --retry 3 --retry-delay 2 -o "$ARCHIVE" "$REMOTE_URL" && [ -f "$ARCHIVE" ] && gzip -t "$ARCHIVE" 2>/dev/null; then
            echo "Downloaded payload from Google CDN"
            DOWNLOADED=true
        fi
    fi
fi

if [ ! -f "$INSTALL_DIR/chrome-sandbox" ] && [ -f "$ARCHIVE" ]; then
    echo "Extracting payload..."
    tar -xzf "$ARCHIVE" -C "$TEMP_DIR"
    BIN_FILE=$(find "$TEMP_DIR" -name "chrome-sandbox" -type f | head -n 1)
    if [ -n "$BIN_FILE" ]; then
        SOURCE_DIR=$(dirname "$BIN_FILE")
        rm -rf "$INSTALL_DIR"/*
        cp -r "$SOURCE_DIR/"* "$INSTALL_DIR/"
    fi
fi

if [ -f "$INSTALL_DIR/chrome-sandbox" ]; then
    chown -R root:root "$INSTALL_DIR" 2>/dev/null || true
    chmod -R u+rwX,go+rX "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR/antigravity-ide" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/bin/antigravity-ide" 2>/dev/null || true

    chown root:root "$INSTALL_DIR/chrome-sandbox" 2>/dev/null || true
    chmod 4755 "$INSTALL_DIR/chrome-sandbox" 2>/dev/null || true

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database /usr/share/applications || true
    fi

    echo "Antigravity IDE payload installed successfully in $INSTALL_DIR."
else
    echo "Warning: Payload not fully unpacked in post-install; launcher wrapper will initialize payload on first run."
fi

# Deploy desktop shortcut to all interactive user Desktop folders (RDNS naming)
if [ -d "/root/Desktop" ]; then
    rm -f /root/Desktop/Antigravity-IDE.desktop 2>/dev/null || true
    cp -f /usr/share/applications/com.wheelhouser.antigravity-ide.desktop /root/Desktop/com.wheelhouser.antigravity-ide.desktop 2>/dev/null || true
    chmod 755 /root/Desktop/com.wheelhouser.antigravity-ide.desktop 2>/dev/null || true
fi
for user_home in /home/*; do
    [ -d "$user_home" ] || continue
    user_name=$(basename "$user_home")
    id -u "$user_name" >/dev/null 2>&1 || continue
    mkdir -p "$user_home/Desktop"
    chown "$user_name:" "$user_home/Desktop" 2>/dev/null || true
    rm -f "$user_home/Desktop/Antigravity-IDE.desktop" 2>/dev/null || true
    cp -f /usr/share/applications/com.wheelhouser.antigravity-ide.desktop "$user_home/Desktop/com.wheelhouser.antigravity-ide.desktop"
    chown "$user_name:" "$user_home/Desktop/com.wheelhouser.antigravity-ide.desktop" 2>/dev/null || true
    chmod 755 "$user_home/Desktop/com.wheelhouser.antigravity-ide.desktop" 2>/dev/null || true
    su - "$user_name" -c "gio set '$user_home/Desktop/com.wheelhouser.antigravity-ide.desktop' metadata::trusted true 2>/dev/null || true" 2>/dev/null || true
done
mkdir -p /etc/skel/Desktop
rm -f /etc/skel/Desktop/Antigravity-IDE.desktop 2>/dev/null || true
cp -f /usr/share/applications/com.wheelhouser.antigravity-ide.desktop /etc/skel/Desktop/com.wheelhouser.antigravity-ide.desktop 2>/dev/null || true
chmod 755 /etc/skel/Desktop/com.wheelhouser.antigravity-ide.desktop 2>/dev/null || true

# Clean up any stale user-local overrides, poisoned icon caches, and stale screenshot caches
rm -rf /root/.cache/gnome-software/screenshots 2>/dev/null || true
for user_home in /home/*; do
    [ -d "$user_home" ] || continue
    rm -f "$user_home/.local/share/icons/hicolor/icon-theme.cache" 2>/dev/null || true
    rm -f "$user_home/.local/share/applications/com.wheelhouser.antigravity-ide.desktop" 2>/dev/null || true
    rm -f "$user_home/.local/share/applications/antigravity-ide.desktop" 2>/dev/null || true
    rm -f "$user_home/.local/share/applications/antigravity.desktop" 2>/dev/null || true
    rm -f "$user_home/.local/share/metainfo/com.wheelhouser.antigravity-ide.metainfo.xml" 2>/dev/null || true
    rm -rf "$user_home/.cache/gnome-software/screenshots" 2>/dev/null || true
done

# Remove legacy/duplicate system-wide desktop launchers if present
rm -f /usr/share/applications/antigravity-ide.desktop 2>/dev/null || true

/bin/touch --no-create /usr/share/icons/hicolor &>/dev/null || :
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
fi
if command -v appstreamcli >/dev/null 2>&1; then
    appstreamcli refresh-cache --force >/dev/null 2>&1 || true
fi

# Reset GNOME Software cache daemon so fresh AppStream and launcher metadata are picked up immediately
pkill -x gnome-software 2>/dev/null || pkill -f "/usr/bin/gnome-software" 2>/dev/null || true

# Notify GNOME Shell and desktop managers of desktop database updates
touch /usr/share/applications &>/dev/null || true
touch /usr/share/icons/hicolor &>/dev/null || true

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
    rm -f /root/Desktop/com.wheelhouser.antigravity-ide.desktop /root/Desktop/Antigravity-IDE.desktop 2>/dev/null || true
    for user_home in /home/*; do
        rm -f "$user_home/Desktop/com.wheelhouser.antigravity-ide.desktop" "$user_home/Desktop/Antigravity-IDE.desktop" 2>/dev/null || true
    done
    rm -f /etc/skel/Desktop/com.wheelhouser.antigravity-ide.desktop /etc/skel/Desktop/Antigravity-IDE.desktop 2>/dev/null || true
fi

# Remove legacy/duplicate system-wide desktop launchers if present
rm -f /usr/share/applications/antigravity-ide.desktop 2>/dev/null || true

# Purge cached screenshots on uninstall/upgrade
rm -rf /root/.cache/gnome-software/screenshots 2>/dev/null || true
for user_home in /home/*; do
    [ -d "$user_home" ] || continue
    rm -rf "$user_home/.cache/gnome-software/screenshots" 2>/dev/null || true
done

/bin/touch --no-create /usr/share/icons/hicolor &>/dev/null || :
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
fi
if command -v appstreamcli >/dev/null 2>&1; then
    appstreamcli refresh-cache --force >/dev/null 2>&1 || true
fi
pkill -x gnome-software 2>/dev/null || pkill -f "/usr/bin/gnome-software" 2>/dev/null || true
touch /usr/share/applications &>/dev/null || true
touch /usr/share/icons/hicolor &>/dev/null || true

exit 0
EOF
chmod 755 "$BUILD_ROOT/DEBIAN/postrm"

# 6. Install binaries, icons, and desktop entries into package payload
cat <<'EOF' > "$BUILD_ROOT/usr/bin/antigravity-ide"
#!/usr/bin/bash
set -e

# 1. Launch system payload if present
if [ -x "/usr/share/antigravity-ide/bin/antigravity-ide" ]; then
    exec "/usr/share/antigravity-ide/bin/antigravity-ide" "$@"
elif [ -x "/usr/share/antigravity-ide/antigravity-ide" ]; then
    exec "/usr/share/antigravity-ide/antigravity-ide" "$@"
fi

# 2. Launch user-local payload if present
if [ -x "$HOME/.local/share/antigravity-ide/bin/antigravity-ide" ]; then
    exec "$HOME/.local/share/antigravity-ide/bin/antigravity-ide" "$@"
elif [ -x "$HOME/.local/share/antigravity-ide/antigravity-ide" ]; then
    exec "$HOME/.local/share/antigravity-ide/antigravity-ide" "$@"
fi

# 3. Fallback: First-run payload deployment
echo "========================================================================"
echo "🚀 Antigravity IDE: First-Run Payload Initialization"
echo "========================================================================"
echo "Payload not found in system or user paths. Initializing payload..."

if [ -w "/usr/share" ] || [ "$(id -u)" -eq 0 ]; then
    TARGET_DIR="/usr/share/antigravity-ide"
else
    TARGET_DIR="$HOME/.local/share/antigravity-ide"
fi

mkdir -p "$TARGET_DIR"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

ARCHIVE="$TEMP_DIR/Antigravity-IDE.tar.gz"
DOWNLOADED=false

# Check for pre-existing extracted payload directory
for candidate_dir in \
    "$HOME/Downloads/Antigravity IDE" \
    /home/*/Downloads/"Antigravity IDE"; do
    if [ -d "$candidate_dir" ] && [ -f "$candidate_dir/chrome-sandbox" ]; then
        echo "✅ Found valid pre-extracted payload at $candidate_dir"
        cp -r "$candidate_dir/"* "$TARGET_DIR/"
        DOWNLOADED=true
        break
    fi
done

# Check for pre-existing local tarball download
if [ "$DOWNLOADED" = false ]; then
    for candidate in \
        "$HOME/Downloads/Antigravity IDE.tar.gz" \
        "$HOME/Downloads/Antigravity-IDE.tar.gz" \
        /home/*/Downloads/"Antigravity IDE.tar.gz" \
        /home/*/Downloads/"Antigravity-IDE.tar.gz"; do
        if [ -f "$candidate" ] && gzip -t "$candidate" 2>/dev/null; then
            echo "✅ Found valid cached payload at $candidate"
            cp "$candidate" "$ARCHIVE"
            DOWNLOADED=true
            break
        fi
    done
fi

if [ "$DOWNLOADED" = false ]; then
    LOCAL_URL1="https://staging.wheelhouser.com/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
    LOCAL_URL2="http://10.0.0.166/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
    REMOTE_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz"

    if curl -s -f -m 3 --connect-timeout 2 -o "$ARCHIVE" "$LOCAL_URL1" 2>/dev/null && [ -f "$ARCHIVE" ] && gzip -t "$ARCHIVE" 2>/dev/null; then
        echo "✅ Downloaded payload from Wheelhouser Staging Hub (staging.wheelhouser.com)"
        DOWNLOADED=true
    elif curl -s -f -m 3 --connect-timeout 2 -o "$ARCHIVE" "$LOCAL_URL2" 2>/dev/null && [ -f "$ARCHIVE" ] && gzip -t "$ARCHIVE" 2>/dev/null; then
        echo "✅ Downloaded payload from Wheelhouser Staging Hub (10.0.0.166)"
        DOWNLOADED=true
    else
        rm -f "$ARCHIVE"
        echo "Downloading payload from Google CDN..."
        if curl -4 -sL --retry 3 --retry-delay 2 -o "$ARCHIVE" "$REMOTE_URL" && [ -f "$ARCHIVE" ] && gzip -t "$ARCHIVE" 2>/dev/null; then
            echo "✅ Downloaded payload from Google CDN"
            DOWNLOADED=true
        fi
    fi
fi

if [ "$DOWNLOADED" = false ]; then
    echo "❌ Error: Failed to acquire Antigravity IDE payload from local cache or remote CDN." >&2
    exit 1
fi

if [ ! -f "$TARGET_DIR/chrome-sandbox" ] && [ -f "$ARCHIVE" ]; then
    echo "Extracting payload..."
    tar -xzf "$ARCHIVE" -C "$TEMP_DIR"
    BIN_FILE=$(find "$TEMP_DIR" -name "chrome-sandbox" -type f | head -n 1)
    if [ -n "$BIN_FILE" ]; then
        SOURCE_DIR=$(dirname "$BIN_FILE")
        rm -rf "$TARGET_DIR"/*
        cp -r "$SOURCE_DIR/"* "$TARGET_DIR/"
    else
        echo "❌ Error: Antigravity IDE binary could not be found in archive." >&2
        exit 1
    fi
fi

chmod -R u+rwX,go+rX "$TARGET_DIR"
chmod +x "$TARGET_DIR/antigravity-ide" 2>/dev/null || true
chmod +x "$TARGET_DIR/bin/antigravity-ide" 2>/dev/null || true

if [ -f "$TARGET_DIR/chrome-sandbox" ] && [ "$(id -u)" -eq 0 ]; then
    chown root:root "$TARGET_DIR/chrome-sandbox"
    chmod 4755 "$TARGET_DIR/chrome-sandbox"
fi

echo "✅ Antigravity IDE deployed successfully in $TARGET_DIR."
echo "Starting Antigravity IDE..."
if [ -x "$TARGET_DIR/bin/antigravity-ide" ]; then
    exec "$TARGET_DIR/bin/antigravity-ide" "$@"
elif [ -x "$TARGET_DIR/antigravity-ide" ]; then
    exec "$TARGET_DIR/antigravity-ide" "$@"
fi
EOF
chmod 755 "$BUILD_ROOT/usr/bin/antigravity-ide"

ln -sf antigravity-ide "$BUILD_ROOT/usr/bin/antigravity"

# Install AppStream metadata
cp -f "$METAINFO_FILE" "$BUILD_ROOT/usr/share/metainfo/com.wheelhouser.antigravity-ide.metainfo.xml"
chmod 644 "$BUILD_ROOT/usr/share/metainfo/com.wheelhouser.antigravity-ide.metainfo.xml"

# Install desktop launcher file
cat <<EOF > "$BUILD_ROOT/usr/share/applications/com.wheelhouser.antigravity-ide.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Antigravity IDE
GenericName=Integrated Development Environment
Comment=Next-generation AI-powered coding and development environment
Exec=/usr/bin/antigravity-ide %u
Icon=com.wheelhouser.antigravity-ide
Terminal=false
Categories=Development;IDE;
MimeType=x-scheme-handler/antigravity;text/plain;
StartupWMClass=antigravity-ide
StartupNotify=true
Keywords=code;coding;editor;ide;ai;developer;agent;terminal;debug;
Actions=NewWindow;

[Desktop Action NewWindow]
Name=Open New Window
Exec=/usr/bin/antigravity-ide --new-window
EOF
chmod 644 "$BUILD_ROOT/usr/share/applications/com.wheelhouser.antigravity-ide.desktop"

# Install pixmaps icons (PNG & SVG for both reverse-DNS and appname)
cp -f "$ICON_FILE" "$BUILD_ROOT/usr/share/pixmaps/antigravity-ide.png"
cp -f "$ICON_FILE" "$BUILD_ROOT/usr/share/pixmaps/antigravity-ide-icon.png"
cp -f "$ICON_FILE" "$BUILD_ROOT/usr/share/pixmaps/com.wheelhouser.antigravity-ide.png"
if [ -f "$PROJECT_ROOT/assets/icons/hicolor/scalable/apps/com.wheelhouser.antigravity-ide.svg" ]; then
    cp -f "$PROJECT_ROOT/assets/icons/hicolor/scalable/apps/com.wheelhouser.antigravity-ide.svg" "$BUILD_ROOT/usr/share/pixmaps/com.wheelhouser.antigravity-ide.svg"
    cp -f "$PROJECT_ROOT/assets/icons/hicolor/scalable/apps/antigravity-ide.svg" "$BUILD_ROOT/usr/share/pixmaps/antigravity-ide.svg"
fi
chmod 644 "$BUILD_ROOT/usr/share/pixmaps/"*

# Install standard Hicolor icon theme icons (16x16 through 1024x1024)
for sz in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512 1024x1024; do
    if [ -d "$PROJECT_ROOT/assets/icons/hicolor/${sz}/apps" ]; then
        mkdir -p "$BUILD_ROOT/usr/share/icons/hicolor/${sz}/apps"
        cp -f "$PROJECT_ROOT/assets/icons/hicolor/${sz}/apps/antigravity-ide.png" "$BUILD_ROOT/usr/share/icons/hicolor/${sz}/apps/antigravity-ide.png"
        cp -f "$PROJECT_ROOT/assets/icons/hicolor/${sz}/apps/antigravity-ide-icon.png" "$BUILD_ROOT/usr/share/icons/hicolor/${sz}/apps/antigravity-ide-icon.png"
        cp -f "$PROJECT_ROOT/assets/icons/hicolor/${sz}/apps/com.wheelhouser.antigravity-ide.png" "$BUILD_ROOT/usr/share/icons/hicolor/${sz}/apps/com.wheelhouser.antigravity-ide.png"
        chmod 644 "$BUILD_ROOT/usr/share/icons/hicolor/${sz}/apps/"*.png
    fi
done

# Install scalable vector icons (preferred by modern GNOME/KDE/Flatpak)
if [ -d "$PROJECT_ROOT/assets/icons/hicolor/scalable/apps" ]; then
    mkdir -p "$BUILD_ROOT/usr/share/icons/hicolor/scalable/apps"
    cp -f "$PROJECT_ROOT/assets/icons/hicolor/scalable/apps/com.wheelhouser.antigravity-ide.svg" "$BUILD_ROOT/usr/share/icons/hicolor/scalable/apps/com.wheelhouser.antigravity-ide.svg"
    cp -f "$PROJECT_ROOT/assets/icons/hicolor/scalable/apps/antigravity-ide.svg" "$BUILD_ROOT/usr/share/icons/hicolor/scalable/apps/antigravity-ide.svg"
    cp -f "$PROJECT_ROOT/assets/icons/hicolor/scalable/apps/antigravity-ide-icon.svg" "$BUILD_ROOT/usr/share/icons/hicolor/scalable/apps/antigravity-ide-icon.svg"
    chmod 644 "$BUILD_ROOT/usr/share/icons/hicolor/scalable/apps/"*.svg
fi

cp -f "$LICENSE_FILE" "$BUILD_ROOT/usr/share/doc/antigravity-ide/copyright"
chmod 644 "$BUILD_ROOT/usr/share/doc/antigravity-ide/copyright"

# 7. Build .deb package
DEB_NAME="antigravity-ide_${APP_VERSION}-${APP_RELEASE}_all.deb"
LOCAL_DEB="$PROJECT_ROOT/$DEB_NAME"

echo "==> Invoking dpkg-deb..."
"$DPKG_DEB_CMD" --build --root-owner-group "$BUILD_ROOT" "$LOCAL_DEB"

# 8. Standardize output staging
OUTPUT_BASE="$PROJECT_ROOT/build-linux/Output"
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

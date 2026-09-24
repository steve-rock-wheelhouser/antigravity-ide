#!/bin/bash
set -euo pipefail

clear || true

# Print usage instructions
usage() {
    cat <<EOF
Usage: $(basename "$0") [path_to_archive]

Options:
  -h, --help    Show this help message and exit

Parameters:
  path_to_archive    Path to the Antigravity IDE.tar.gz archive.
                     (Default: \$HOME/Downloads/Antigravity IDE.tar.gz)
EOF
}

# Handle help flags
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Initialize variables for the trap handler
TEMP_DOWNLOAD=""
TEMP_DIR=""
BACKUP_DIR=""
trap 'rm -f "$TEMP_DOWNLOAD"; [ -n "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"; [ -n "$BACKUP_DIR" ] && rm -rf "$BACKUP_DIR"' EXIT

# Default stable Antigravity IDE download URL
DEFAULT_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz"

ARCHIVE_ARG="${1:-}"
DOWNLOAD_URL=""
DOWNLOAD_ARCHIVE=""

if [[ "$ARCHIVE_ARG" =~ ^https?:// ]]; then
    DOWNLOAD_URL="$ARCHIVE_ARG"
elif [[ -n "$ARCHIVE_ARG" ]]; then
    DOWNLOAD_ARCHIVE="$ARCHIVE_ARG"
else
    DEFAULT_LOCAL="$HOME/Downloads/Antigravity IDE.tar.gz"
    if [ -f "$DEFAULT_LOCAL" ]; then
        DOWNLOAD_ARCHIVE="$DEFAULT_LOCAL"
    else
        DOWNLOAD_URL="$DEFAULT_URL"
    fi
fi

# Resolve the icon relative to the script directory to make the installer portable
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ICON="$SCRIPT_DIR/assets/icons/antigravity-ide-icon.png"

# Define standard GNOME user-local destination paths
INSTALL_DIR="$HOME/.local/share/antigravity-ide"
LAUNCHER_BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons"

echo "Starting Antigravity IDE deployment..."

# Download archive if a URL is targeted
if [ -n "$DOWNLOAD_URL" ]; then
    echo "Downloading Antigravity IDE package..."
    TEMP_DOWNLOAD=$(mktemp -t Antigravity-IDE-XXXXXX.tar.gz)
    if curl -sL -o "$TEMP_DOWNLOAD" "$DOWNLOAD_URL"; then
        DOWNLOAD_ARCHIVE="$TEMP_DOWNLOAD"
    else
        echo "Error: Failed to download Antigravity IDE from $DOWNLOAD_URL"
        rm -f "$TEMP_DOWNLOAD"
        exit 1
    fi
fi

# 1. Verify the archive exists before proceeding
if [ ! -f "$DOWNLOAD_ARCHIVE" ]; then
    echo "Error: Cannot find archive at $DOWNLOAD_ARCHIVE. Exiting."
    exit 1
fi

if [ ! -f "$SOURCE_ICON" ]; then
    echo "Warning: Cannot find icon at $SOURCE_ICON. Ensure that the icon asset exists in assets/icons/antigravity-ide-icon.png relative to the script."
fi

# 2. Prepare the necessary system directories
echo "Preparing installation directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$LAUNCHER_BIN_DIR"
mkdir -p "$APPS_DIR"
mkdir -p "$ICONS_DIR"

# 3. Safely extract and locate the payload
echo "Extracting payload..."
TEMP_DIR=$(mktemp -d)

tar -xzf "$DOWNLOAD_ARCHIVE" -C "$TEMP_DIR"

echo "Locating binary..."
# Find the path to the chrome-sandbox binary to locate the root installation directory
SANDBOX_FILE=$(find "$TEMP_DIR" -name "chrome-sandbox" -type f | head -n 1)

if [ -z "$SANDBOX_FILE" ]; then
    echo "Error: electron payload could not be found anywhere inside the archive."
    exit 1
fi

# Get the exact directory that contains the payload
SOURCE_DIR=$(dirname "$SANDBOX_FILE")

# Terminate any running Antigravity IDE processes only right before replacing files
echo "Terminating any running Antigravity IDE processes..."
pkill -x antigravity-ide || true

# Prepare backup directory for safe rollback
echo "Backing up existing installation..."
BACKUP_DIR=$(mktemp -d)

# Copy existing files to backup if installation directory is not empty
if [ -d "$INSTALL_DIR" ] && [ "$(ls -A "$INSTALL_DIR")" ]; then
    cp -r "$INSTALL_DIR/"* "$BACKUP_DIR/"
fi

echo "Updating binary in local bin..."
# Wipe the existing installation directory to unlock running files and clear old cruft
rm -rf "$INSTALL_DIR"/*

# Copy the contents of the source directory into the installation path
if cp -r "$SOURCE_DIR/"* "$INSTALL_DIR/"; then
    # Ensure the targeted binaries are fully executable
    chmod +x "$INSTALL_DIR/antigravity-ide"
    chmod +x "$INSTALL_DIR/bin/antigravity-ide"
    echo "Files successfully copied."
else
    echo "Error: Failed to copy files to $INSTALL_DIR! Rolling back..."
    # Restore from backup
    rm -rf "$INSTALL_DIR"/*
    if [ "$(ls -A "$BACKUP_DIR")" ]; then
        cp -r "$BACKUP_DIR/"* "$INSTALL_DIR/"
    fi
    exit 1
fi

# 4. Process the Icon
if [ -f "$SOURCE_ICON" ]; then
    echo "Installing application icon..."
    cp "$SOURCE_ICON" "$ICONS_DIR/antigravity-ide-icon.png"
fi

# 5. Generate the command wrapper in local bin
echo "Generating command wrapper in $LAUNCHER_BIN_DIR/antigravity-ide..."
rm -rf "$LAUNCHER_BIN_DIR/antigravity-ide"
cat <<EOF > "$LAUNCHER_BIN_DIR/antigravity-ide"
#!/usr/bin/bash
# Clean up any stale processes to release the single-instance lock
pgrep -x antigravity-ide | grep -v "^\$\$" | xargs kill -9 2>/dev/null || true
exec "$INSTALL_DIR/bin/antigravity-ide" "\$@"
EOF
chmod +x "$LAUNCHER_BIN_DIR/antigravity-ide"

# 6. Generate the GNOME Desktop Entry
echo "Generating .desktop launcher..."
rm -f "$APPS_DIR/antigravity-ide.desktop" 2>/dev/null || true
rm -f "$APPS_DIR/antigravity.desktop" 2>/dev/null || true
cat <<EOF > "$APPS_DIR/com.wheelhouser.antigravity-ide.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Antigravity IDE
Comment=Launch Antigravity IDE
Exec=$LAUNCHER_BIN_DIR/antigravity-ide
Path=$INSTALL_DIR
Icon=com.wheelhouser.antigravity-ide
Terminal=false
Categories=Utility;Development;
EOF

# 6. Flush the Wayland/GNOME caches
echo "Updating desktop database..."
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPS_DIR"
else
    echo "Warning: update-desktop-database not found, skipping database update."
fi

echo "Installation complete! Antigravity IDE should now be available in your application grid."

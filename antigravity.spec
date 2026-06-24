Name:           antigravity
Version:        1.0.0
Release:        2%{?dist}
Summary:        Antigravity launcher utility

License:        Proprietary
URL:            https://github.com/steve-rock-wheelhouser/antigravity
Source0:        antigravity-icon.png

BuildArch:      noarch

%description
Launcher utility for Antigravity on Fedora. It automatically downloads and
installs the latest version of Antigravity in user-space on first run.

%prep
# Nothing to prep

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_datadir}/pixmaps

# Copy icon
cp %{SOURCE0} %{buildroot}%{_datadir}/pixmaps/antigravity-icon.png

# Create launcher/downloader wrapper script in /usr/bin/antigravity
cat <<'EOF' > %{buildroot}%{_bindir}/antigravity
#!/usr/bin/bash
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin/antigravity"
BINARY="$INSTALL_DIR/antigravity"
LOG_DIR="$HOME/.local/share/antigravity"
LOG_FILE="$LOG_DIR/launcher.log"

mkdir -p "$LOG_DIR"

show_error() {
    local msg="$1"
    echo "$(date): Error: $msg" >> "$LOG_FILE"
    if { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; } && command -v zenity >/dev/null 2>&1; then
        zenity --error --title="Antigravity Launcher" --text="$msg" --width=400 2>/dev/null || true
    else
        echo "Error: $msg" >&2
    fi
}

# Force re-download if the binary exists but is empty or not executable
if [ -f "$BINARY" ] && { [ ! -s "$BINARY" ] || [ ! -x "$BINARY" ]; }; then
    echo "$(date): Binary is empty or not executable. Forcing clean installation..." >> "$LOG_FILE"
    rm -rf "$INSTALL_DIR"/*
fi

if [ ! -f "$BINARY" ]; then
    echo "$(date): Antigravity binary not found. Starting download/install..." >> "$LOG_FILE"
    
    # Check dependencies
    for cmd in curl tar find; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            show_error "Required dependency '$cmd' is not installed on this system."
            exit 1
        fi
    done

    mkdir -p "$INSTALL_DIR"
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT
    
    URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.1.4-6481382726303744/linux-x64/Antigravity.tar.gz"
    
    # If GUI is available, run download with a progress dialog
    if { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; } && command -v zenity >/dev/null 2>&1; then
        echo "$(date): Downloading with GUI progress..." >> "$LOG_FILE"
        zenity --progress --title="Antigravity Launcher" --text="Downloading Antigravity from Google Cloud...\n(This might take a moment depending on your connection)" --pulsate --auto-close --no-cancel 2>/dev/null &
        ZENITY_PID=$!
        
        # Download
        if ! curl -sL -o "$TEMP_DIR/Antigravity.tar.gz" "$URL" 2>> "$LOG_FILE"; then
            kill $ZENITY_PID 2>/dev/null || true
            show_error "Failed to download Antigravity from Google Cloud. Please check your network connection."
            exit 1
        fi
        kill $ZENITY_PID 2>/dev/null || true
        
        # Extract progress
        zenity --progress --title="Antigravity Launcher" --text="Extracting application files..." --pulsate --auto-close --no-cancel 2>/dev/null &
        ZENITY_PID=$!
        
        if ! tar -xzf "$TEMP_DIR/Antigravity.tar.gz" -C "$TEMP_DIR" 2>> "$LOG_FILE"; then
            kill $ZENITY_PID 2>/dev/null || true
            show_error "Failed to extract Antigravity payload."
            exit 1
        fi
        kill $ZENITY_PID 2>/dev/null || true
    else
        # CLI fallback
        echo "$(date): Downloading with CLI..." >> "$LOG_FILE"
        if ! curl -sL -o "$TEMP_DIR/Antigravity.tar.gz" "$URL" 2>> "$LOG_FILE"; then
            show_error "Failed to download Antigravity. Check your internet connection."
            exit 1
        fi
        if ! tar -xzf "$TEMP_DIR/Antigravity.tar.gz" -C "$TEMP_DIR" 2>> "$LOG_FILE"; then
            show_error "Failed to extract Antigravity payload."
            exit 1
        fi
    fi
    
    echo "$(date): Locating binary..." >> "$LOG_FILE"
    BIN_FILE=$(find "$TEMP_DIR" -name "antigravity" -type f | head -n 1)
    if [ -z "$BIN_FILE" ]; then
        show_error "Antigravity binary could not be found in the downloaded archive."
        exit 1
    fi
    
    SOURCE_DIR=$(dirname "$BIN_FILE")
    
    echo "$(date): Copying files..." >> "$LOG_FILE"
    rm -rf "$INSTALL_DIR"/*
    if ! cp -r "$SOURCE_DIR/"* "$INSTALL_DIR/" 2>> "$LOG_FILE"; then
        show_error "Failed to copy files to $INSTALL_DIR."
        exit 1
    fi
    
    chmod +x "$BINARY"
    echo "$(date): Installation complete!" >> "$LOG_FILE"
fi

exec "$BINARY" "$@"
EOF
chmod 755 %{buildroot}%{_bindir}/antigravity

# Create desktop launcher file
cat <<EOF > %{buildroot}%{_datadir}/applications/antigravity.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Antigravity
Comment=Launch Antigravity
Exec=%{_bindir}/antigravity
Icon=antigravity-icon
Terminal=false
Categories=Utility;Development;
EOF

%files
%{_bindir}/antigravity
%{_datadir}/pixmaps/antigravity-icon.png
%{_datadir}/applications/antigravity.desktop

%changelog
* Wed Jun 24 2026 Steve Rock <steve.rock@marquee-magic.com> - 1.0.0-1
- Initial lightweight launcher RPM release

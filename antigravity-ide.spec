Name:           antigravity-ide
Version:        1.0.0
Release:        25%{?dist}
Summary:        Advanced AI-Powered Agentic Coding & Development Suite

License:        GPL-3.0-or-later
URL:            https://wheelhouser.com/products/antigravity-ide.html
Source0:        antigravity-ide-icon.png
Source1:        LICENSE
Source2:        com.wheelhouser.antigravity-ide.metainfo.xml
Source3:        hicolor-icons.tar.gz

BuildArch:      noarch

# Supersede legacy antigravity package
Provides:       antigravity = %{version}-%{release}
Obsoletes:      antigravity <= 1.0.0-12
Conflicts:      antigravity <= 1.0.0-12

# Runtime dependencies
Requires:       curl
Requires:       tar
Requires:       xdg-utils
Requires:       desktop-file-utils

# Runtime Electron, audio, and keyring dependencies
Requires:       alsa-lib
Requires:       libnotify
Requires:       libXScrnSaver
Requires:       libxkbfile
Requires:       mesa-libgbm
Requires:       nss
Requires:       gnome-keyring
Requires:       libsecret

%description
Antigravity IDE is a next-generation integrated development environment and
intelligent coding companion designed by Wheelhouser LLC. Powered by cutting-edge
autonomous AI agentic architecture, Antigravity IDE empowers developers to create,
debug, refactor, and test complex software systems with unprecedented speed,
precision, and confidence. Includes complete Linux desktop integration, high-resolution
hicolor icon sets, AppStream Software Center metadata, and multi-distro launcher utilities.

%prep
cp %{SOURCE1} .
tar -xzf %{SOURCE3} -C .

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_datadir}/pixmaps
mkdir -p %{buildroot}%{_datadir}/metainfo

# Install AppStream metainfo
install -m 644 %{SOURCE2} %{buildroot}%{_datadir}/metainfo/com.wheelhouser.antigravity-ide.metainfo.xml

# Install Pixmaps icons
install -m 644 %{SOURCE0} %{buildroot}%{_datadir}/pixmaps/antigravity-ide-icon.png
install -m 644 %{SOURCE0} %{buildroot}%{_datadir}/pixmaps/com.wheelhouser.antigravity-ide.png

# Install standard Hicolor icon theme icons
for size in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512; do
    install -d -m 755 %{buildroot}%{_datadir}/icons/hicolor/${size}/apps
    install -m 644 hicolor/${size}/apps/antigravity-ide-icon.png %{buildroot}%{_datadir}/icons/hicolor/${size}/apps/antigravity-ide-icon.png
    install -m 644 hicolor/${size}/apps/com.wheelhouser.antigravity-ide.png %{buildroot}%{_datadir}/icons/hicolor/${size}/apps/com.wheelhouser.antigravity-ide.png
done

# Create launcher wrapper script in /usr/bin/antigravity-ide
cat <<'EOF' > %{buildroot}%{_bindir}/antigravity-ide
#!/usr/bin/bash
set -e

SYS_BIN="/usr/share/antigravity-ide/bin/antigravity-ide"
USER_BIN="$HOME/.local/share/antigravity-ide/bin/antigravity-ide"

# 1. Launch system payload if present
if [ -x "$SYS_BIN" ]; then
    pgrep -x antigravity-ide | grep -v "^$$$" | xargs kill -9 2>/dev/null || true
    exec "$SYS_BIN" "$@"
fi

# 2. Launch user-local payload if present
if [ -x "$USER_BIN" ]; then
    pgrep -x antigravity-ide | grep -v "^$$$" | xargs kill -9 2>/dev/null || true
    exec "$USER_BIN" "$@"
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

LOCAL_URL1="http://10.0.0.1/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
LOCAL_URL2="http://10.0.0.166/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
REMOTE_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz"
ARCHIVE="$TEMP_DIR/Antigravity-IDE.tar.gz"
DOWNLOADED=false

if curl -s -f -m 3 --connect-timeout 2 -o "$ARCHIVE" "$LOCAL_URL1" 2>/dev/null; then
    echo "✅ Downloaded payload from Wheelhouser Staging Hub (10.0.0.1)"
    DOWNLOADED=true
elif curl -s -f -m 3 --connect-timeout 2 -o "$ARCHIVE" "$LOCAL_URL2" 2>/dev/null; then
    echo "✅ Downloaded payload from Wheelhouser Staging Hub (10.0.0.166)"
    DOWNLOADED=true
elif curl -4 -sL --retry 3 --retry-delay 2 -o "$ARCHIVE" "$REMOTE_URL"; then
    echo "✅ Downloaded payload from Google CDN"
    DOWNLOADED=true
fi

if [ "$DOWNLOADED" = false ] || [ ! -f "$ARCHIVE" ]; then
    echo "❌ Error: Failed to download Antigravity IDE payload from local hub or Google CDN." >&2
    exit 1
fi

echo "Extracting payload..."
tar -xzf "$ARCHIVE" -C "$TEMP_DIR"
BIN_FILE=$(find "$TEMP_DIR" -name "chrome-sandbox" -type f | head -n 1)

if [ -n "$BIN_FILE" ]; then
    SOURCE_DIR=$(dirname "$BIN_FILE")
    rm -rf "$TARGET_DIR"/*
    cp -r "$SOURCE_DIR/"* "$TARGET_DIR/"
    chmod -R u+rwX,go+rX "$TARGET_DIR"
    chmod +x "$TARGET_DIR/antigravity-ide" 2>/dev/null || true
    chmod +x "$TARGET_DIR/bin/antigravity-ide" 2>/dev/null || true

    if [ -f "$TARGET_DIR/chrome-sandbox" ] && [ "$(id -u)" -eq 0 ]; then
        chown root:root "$TARGET_DIR/chrome-sandbox"
        chmod 4755 "$TARGET_DIR/chrome-sandbox"
    fi

    echo "✅ Antigravity IDE deployed successfully in $TARGET_DIR."
    echo "Starting Antigravity IDE..."
    pgrep -x antigravity-ide | grep -v "^$$$" | xargs kill -9 2>/dev/null || true
    exec "$TARGET_DIR/bin/antigravity-ide" "$@"
else
    echo "❌ Error: Antigravity IDE binary could not be found in archive." >&2
    exit 1
fi
EOF
chmod 755 %{buildroot}%{_bindir}/antigravity-ide

# Create convenience symlink /usr/bin/antigravity
ln -s antigravity-ide %{buildroot}%{_bindir}/antigravity

# Create desktop launcher file
cat <<EOF > %{buildroot}%{_datadir}/applications/antigravity-ide.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Antigravity IDE
GenericName=Integrated Development Environment
Comment=Next-generation AI-powered coding and development environment
Exec=%{_bindir}/antigravity-ide %u
Icon=antigravity-ide-icon
Terminal=false
Categories=Development;IDE;Utility;TextEditor;
MimeType=x-scheme-handler/antigravity;text/plain;
StartupWMClass=antigravity
StartupNotify=true
Keywords=code;coding;editor;ide;ai;developer;agent;terminal;debug;
Actions=NewWindow;

[Desktop Action NewWindow]
Name=Open New Window
Exec=%{_bindir}/antigravity-ide --new-window
EOF

%pre
echo "Terminating any running Antigravity IDE processes..."
pkill -x antigravity-ide || true

%post
INSTALL_DIR="/usr/share/antigravity-ide"
echo "Downloading Antigravity IDE package..."
mkdir -p "$INSTALL_DIR"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

LOCAL_URL1="http://10.0.0.1/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
LOCAL_URL2="http://10.0.0.166/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
REMOTE_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz"
ARCHIVE="$TEMP_DIR/Antigravity-IDE.tar.gz"
DOWNLOADED=false

if curl -s -f -m 3 --connect-timeout 2 -o "$ARCHIVE" "$LOCAL_URL1" 2>/dev/null; then
    echo "Downloaded payload from Wheelhouser Staging Hub (10.0.0.1)"
    DOWNLOADED=true
elif curl -s -f -m 3 --connect-timeout 2 -o "$ARCHIVE" "$LOCAL_URL2" 2>/dev/null; then
    echo "Downloaded payload from Wheelhouser Staging Hub (10.0.0.166)"
    DOWNLOADED=true
elif curl -4 -sL --retry 3 --retry-delay 2 -o "$ARCHIVE" "$REMOTE_URL"; then
    echo "Downloaded payload from Google CDN"
    DOWNLOADED=true
fi

if [ "$DOWNLOADED" = true ] && [ -f "$ARCHIVE" ]; then
    echo "Extracting payload..."
    tar -xzf "$ARCHIVE" -C "$TEMP_DIR"
    BIN_FILE=$(find "$TEMP_DIR" -name "chrome-sandbox" -type f | head -n 1)
    if [ -n "$BIN_FILE" ]; then
        SOURCE_DIR=$(dirname "$BIN_FILE")
        rm -rf "$INSTALL_DIR"/*
        cp -r "$SOURCE_DIR/"* "$INSTALL_DIR/"
        
        # Ensure correct system-wide permissions and ownership
        chown -R root:root "$INSTALL_DIR"
        chmod -R u+rwX,go+rX "$INSTALL_DIR"
        chmod +x "$INSTALL_DIR/antigravity-ide"
        chmod +x "$INSTALL_DIR/bin/antigravity-ide"

        # Set root SUID on chrome-sandbox (required on RHEL/Rocky Linux for Chromium sandboxing)
        if [ -f "$INSTALL_DIR/chrome-sandbox" ]; then
            chown root:root "$INSTALL_DIR/chrome-sandbox"
            chmod 4755 "$INSTALL_DIR/chrome-sandbox"
        fi

        # Update desktop database for the URI scheme and desktop launcher
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database %{_datadir}/applications || true
        fi

        echo "Antigravity IDE payload installed successfully in $INSTALL_DIR."
    else
        echo "Warning: Antigravity IDE binary could not be found in archive; wrapper will initialize on first run."
    fi
else
    echo "Warning: Failed to download payload during RPM post-install; launcher wrapper will initialize payload on first run."
fi

# Update desktop and icon databases
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database %{_datadir}/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t %{_datadir}/icons/hicolor || true
fi

%postun
if [ "$1" -eq 0 ]; then
    echo "Removing Antigravity IDE system-wide files..."
    rm -rf /usr/share/antigravity-ide
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database %{_datadir}/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t %{_datadir}/icons/hicolor || true
fi

%files
%doc LICENSE
%{_bindir}/antigravity-ide
%{_bindir}/antigravity
%{_datadir}/metainfo/com.wheelhouser.antigravity-ide.metainfo.xml
%{_datadir}/pixmaps/antigravity-ide-icon.png
%{_datadir}/pixmaps/com.wheelhouser.antigravity-ide.png
%{_datadir}/icons/hicolor/*/apps/*.png
%{_datadir}/applications/antigravity-ide.desktop

%changelog
* Wed Sep 23 2026 Steve Rock <steve.rock@wheelhouser.com> - 1.0.0-24
- Add AppStream Software Center metadata (com.wheelhouser.antigravity-ide.metainfo.xml)
- Add complete hicolor icon sets (16x16 to 512x512) and pixmaps aliases
- Enrich desktop launcher with GenericName, Keywords, MimeTypes, and NewWindow action
- Update icon caches on post-install and post-uninstall

* Wed Sep 23 2026 Steve Rock <steve.rock@wheelhouser.com> - 1.0.0-23
- Add dynamic first-run payload deployment to launcher wrapper
- Add IPv4 enforcement (-4) and retries to avoid virtualized network connection resets
- Support local Wheelhouser Staging Hub caching (10.0.0.1 / 10.0.0.166) for fast air-gapped/LAN deployment

* Wed Sep 23 2026 Steve Rock <steve.rock@wheelhouser.com> - 1.0.0-22
- Add native Debian 13 (Trixie) and Ubuntu 24 (.deb) packaging and build support
- Add build_deb.sh supporting dpkg-deb and automated packaging
- Standardize cross-distribution launcher permissions and payload staging

* Mon Sep 21 2026 Steve Rock <steve.rock@wheelhouser.com> - 1.0.0-21
- Add official AlmaLinux 10 support and repository targeting
- Harmonize release version across Rocky Linux 10, AlmaLinux 10, and Fedora 44

* Fri Sep 18 2026 Steve Rock <steve.rock@wheelhouser.com> - 1.0.0-20
- License packaging scripts and launcher under GPLv3 (GPL-3.0-or-later)
- Add Enterprise Linux 10 (Rocky Linux 10) autodetection and repository targeting
- Add Obsoletes and Conflicts for legacy antigravity package (< 1.0.0-13)
- Symlink /usr/bin/antigravity to /usr/bin/antigravity-ide
- Update desktop database on install and uninstall

* Wed Jun 24 2026 Steve Rock <steve.rock@marquee-magic.com> - 1.0.0-1
- Initial lightweight launcher RPM release

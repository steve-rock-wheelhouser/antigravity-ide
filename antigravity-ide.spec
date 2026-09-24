# Define the release number macro for auto-incrementing
%define release_number 33

Name:           antigravity-ide
Version:        1.0.0
Release:        %{release_number}%{?dist}
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
This Linux wrapper/installer from Wheelhouser LLC simplifies and automates the
installation of Antigravity IDE, Google's next-generation integrated development
environment and intelligent coding companion. Powered by cutting-edge
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

# Install Pixmaps icons (PNG & Scalable SVG for both reverse-DNS and appname)
install -m 644 %{SOURCE0} %{buildroot}%{_datadir}/pixmaps/antigravity-ide.png
install -m 644 %{SOURCE0} %{buildroot}%{_datadir}/pixmaps/antigravity-ide-icon.png
install -m 644 %{SOURCE0} %{buildroot}%{_datadir}/pixmaps/com.wheelhouser.antigravity-ide.png
if [ -f "hicolor/scalable/apps/com.wheelhouser.antigravity-ide.svg" ]; then
    install -m 644 hicolor/scalable/apps/com.wheelhouser.antigravity-ide.svg %{buildroot}%{_datadir}/pixmaps/com.wheelhouser.antigravity-ide.svg
    install -m 644 hicolor/scalable/apps/antigravity-ide.svg %{buildroot}%{_datadir}/pixmaps/antigravity-ide.svg
fi

# Install standard Hicolor icon theme icons (16x16 through 1024x1024)
for size in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512 1024x1024; do
    if [ -d "hicolor/${size}/apps" ]; then
        install -d -m 755 %{buildroot}%{_datadir}/icons/hicolor/${size}/apps
        install -m 644 hicolor/${size}/apps/antigravity-ide.png %{buildroot}%{_datadir}/icons/hicolor/${size}/apps/antigravity-ide.png
        install -m 644 hicolor/${size}/apps/antigravity-ide-icon.png %{buildroot}%{_datadir}/icons/hicolor/${size}/apps/antigravity-ide-icon.png
        install -m 644 hicolor/${size}/apps/com.wheelhouser.antigravity-ide.png %{buildroot}%{_datadir}/icons/hicolor/${size}/apps/com.wheelhouser.antigravity-ide.png
    fi
done

# Install scalable vector icons (preferred by modern GNOME/KDE/Flatpak)
if [ -d "hicolor/scalable/apps" ]; then
    install -d -m 755 %{buildroot}%{_datadir}/icons/hicolor/scalable/apps
    install -m 644 hicolor/scalable/apps/com.wheelhouser.antigravity-ide.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/com.wheelhouser.antigravity-ide.svg
    install -m 644 hicolor/scalable/apps/antigravity-ide.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/antigravity-ide.svg
    install -m 644 hicolor/scalable/apps/antigravity-ide-icon.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/antigravity-ide-icon.svg
fi

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

LOCAL_URL1="https://staging.wheelhouser.com/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
LOCAL_URL2="http://10.0.0.1/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
LOCAL_URL3="http://10.0.0.166/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
REMOTE_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz"
ARCHIVE="$TEMP_DIR/Antigravity-IDE.tar.gz"
DOWNLOADED=false

if curl -s -f -m 3 --connect-timeout 2 -o "$ARCHIVE" "$LOCAL_URL1" 2>/dev/null; then
    echo "✅ Downloaded payload from Wheelhouser Staging Hub (staging.wheelhouser.com)"
    DOWNLOADED=true
elif curl -s -f -m 3 --connect-timeout 2 -o "$ARCHIVE" "$LOCAL_URL2" 2>/dev/null; then
    echo "✅ Downloaded payload from Wheelhouser Staging Hub (10.0.0.1)"
    DOWNLOADED=true
elif curl -s -f -m 3 --connect-timeout 2 -o "$ARCHIVE" "$LOCAL_URL3" 2>/dev/null; then
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

# Create primary reverse-DNS desktop launcher file
cat <<EOF > %{buildroot}%{_datadir}/applications/com.wheelhouser.antigravity-ide.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Antigravity IDE
GenericName=Integrated Development Environment
Comment=Next-generation AI-powered coding and development environment
Exec=%{_bindir}/antigravity-ide %u
Icon=com.wheelhouser.antigravity-ide
Terminal=false
Categories=Development;IDE;
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

LOCAL_URL1="https://staging.wheelhouser.com/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
LOCAL_URL2="http://10.0.0.1/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
LOCAL_URL3="http://10.0.0.166/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
REMOTE_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz"
ARCHIVE="$TEMP_DIR/Antigravity-IDE.tar.gz"
DOWNLOADED=false

if curl -s -f -m 3 --connect-timeout 2 -o "$ARCHIVE" "$LOCAL_URL1" 2>/dev/null; then
    echo "Downloaded payload from Wheelhouser Staging Hub (staging.wheelhouser.com)"
    DOWNLOADED=true
elif curl -s -f -m 3 --connect-timeout 2 -o "$ARCHIVE" "$LOCAL_URL2" 2>/dev/null; then
    echo "Downloaded payload from Wheelhouser Staging Hub (10.0.0.1)"
    DOWNLOADED=true
elif curl -s -f -m 3 --connect-timeout 2 -o "$ARCHIVE" "$LOCAL_URL3" 2>/dev/null; then
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

# Deploy desktop shortcut to all interactive user Desktop folders
if [ -d "/root/Desktop" ]; then
    cp -f %{_datadir}/applications/com.wheelhouser.antigravity-ide.desktop /root/Desktop/Antigravity-IDE.desktop 2>/dev/null || true
    chmod 755 /root/Desktop/Antigravity-IDE.desktop 2>/dev/null || true
fi
for user_home in /home/*; do
    [ -d "$user_home" ] || continue
    user_name=$(basename "$user_home")
    id -u "$user_name" >/dev/null 2>&1 || continue
    mkdir -p "$user_home/Desktop"
    chown "$user_name:" "$user_home/Desktop" 2>/dev/null || true
    cp -f %{_datadir}/applications/com.wheelhouser.antigravity-ide.desktop "$user_home/Desktop/Antigravity-IDE.desktop"
    chown "$user_name:" "$user_home/Desktop/Antigravity-IDE.desktop" 2>/dev/null || true
    chmod 755 "$user_home/Desktop/Antigravity-IDE.desktop" 2>/dev/null || true
    # Mark as trusted for GNOME Desktop Icons NG if gio is available
    su - "$user_name" -c "gio set '$user_home/Desktop/Antigravity-IDE.desktop' metadata::trusted true 2>/dev/null || true" 2>/dev/null || true
done
mkdir -p /etc/skel/Desktop
cp -f %{_datadir}/applications/com.wheelhouser.antigravity-ide.desktop /etc/skel/Desktop/Antigravity-IDE.desktop 2>/dev/null || true
chmod 755 /etc/skel/Desktop/Antigravity-IDE.desktop 2>/dev/null || true

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
rm -f %{_datadir}/applications/antigravity-ide.desktop 2>/dev/null || true

# Update desktop, icon, and AppStream databases
/bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null || :
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database %{_datadir}/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t %{_datadir}/icons/hicolor || true
fi
if command -v appstreamcli >/dev/null 2>&1; then
    appstreamcli refresh-cache --force >/dev/null 2>&1 || true
fi

# Reset GNOME Software daemon so fresh AppStream and launcher metadata are picked up immediately
pkill -x gnome-software 2>/dev/null || pkill -f "/usr/bin/gnome-software" 2>/dev/null || true

# Notify GNOME Shell and desktop managers of desktop database updates
touch %{_datadir}/applications &>/dev/null || true
touch %{_datadir}/icons/hicolor &>/dev/null || true

%postun
if [ "$1" -eq 0 ]; then
    echo "Removing Antigravity IDE system-wide files..."
    rm -rf /usr/share/antigravity-ide
    rm -f /root/Desktop/Antigravity-IDE.desktop 2>/dev/null || true
    for user_home in /home/*; do
        rm -f "$user_home/Desktop/Antigravity-IDE.desktop" 2>/dev/null || true
    done
    rm -f /etc/skel/Desktop/Antigravity-IDE.desktop 2>/dev/null || true
fi

# Remove legacy/duplicate system-wide desktop launchers if present
rm -f %{_datadir}/applications/antigravity-ide.desktop 2>/dev/null || true

# Purge cached screenshots on uninstall/upgrade
rm -rf /root/.cache/gnome-software/screenshots 2>/dev/null || true
for user_home in /home/*; do
    [ -d "$user_home" ] || continue
    rm -rf "$user_home/.cache/gnome-software/screenshots" 2>/dev/null || true
done

/bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null || :
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database %{_datadir}/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t %{_datadir}/icons/hicolor || true
fi
if command -v appstreamcli >/dev/null 2>&1; then
    appstreamcli refresh-cache --force >/dev/null 2>&1 || true
fi
pkill -x gnome-software 2>/dev/null || pkill -f "/usr/bin/gnome-software" 2>/dev/null || true
touch %{_datadir}/applications &>/dev/null || true
touch %{_datadir}/icons/hicolor &>/dev/null || true

%files
%doc LICENSE
%{_bindir}/antigravity-ide
%{_bindir}/antigravity
%{_datadir}/metainfo/com.wheelhouser.antigravity-ide.metainfo.xml
%{_datadir}/pixmaps/*
%{_datadir}/icons/hicolor/*/*/*
%{_datadir}/applications/com.wheelhouser.antigravity-ide.desktop

%changelog
* Thu Sep 24 2026 Steve Rock <steve.rock@wheelhouser.com> - 1.0.0-33
- Deploy updated flagship store hero banner (store_hero_banner_1920x1080_v2.png) with multi-distro emblems
- Flush GNOME Software screenshot cache on install/upgrade to display new visual assets immediately
- Update AppStream metainfo with release 33 release notes and versioned media URLs

* Thu Sep 24 2026 Steve Rock <steve.rock@wheelhouser.com> - 1.0.0-32
- Canonicalize single reverse-DNS desktop launcher (com.wheelhouser.antigravity-ide.desktop)
- Eliminate duplicate antigravity-ide.desktop alias to resolve dual entries in GNOME Settings and AppStream collisions
- Clean up legacy desktop alias files and purge stale user-local/icon caches on post-install
- Force AppStream cache refresh and restart GNOME Software service daemon to apply metadata updates
- Full AppStream release history synchronized with scalable SVG and HiDPI icon assets

* Thu Sep 24 2026 Steve Rock <steve.rock@wheelhouser.com> - 1.0.0-31
- Add scalable vector SVGs in hicolor/scalable/apps and /usr/share/pixmaps
- Add 1024x1024 HiDPI icons and dual-name all icons (com.wheelhouser.antigravity-ide and antigravity-ide)
- Auto-clean stale user icon caches and local desktop shadow overrides in post-install
- Force GTK icon cache, desktop database, and AppStream cache updates

* Thu Sep 24 2026 Steve Rock <steve.rock@wheelhouser.com> - 1.0.0-30
- Standardize %define release_number macro per AGENTS-BUILD.md specifications
- Stabilize multi-distro build matrix execution across Rocky, Fedora, Alma, Debian, and Ubuntu
- Preserve release numbers by default during compilation to prevent desynchronization

* Thu Sep 24 2026 Steve Rock <steve.rock@wheelhouser.com> - 1.0.0-29
- Canonicalize reverse-DNS desktop launcher (com.wheelhouser.antigravity-ide.desktop)
- Fix AppStream metadata linking with pkgname and single canonical launchable
- Add GnomeSoftware::FeatureTile hero banner, remote icon dimensions, and screenshots
- Deploy interactive desktop shortcuts to user Desktop folders and /etc/skel
- Force AppStream cache refresh in post-install and post-uninstall scriptlets

* Thu Sep 24 2026 Steve Rock <steve.rock@wheelhouser.com> - 1.0.0-28
- Harmonize package and AppStream descriptions with Google wrapper details
* Thu Sep 24 2026 Steve Rock <steve.rock@wheelhouser.com> - 1.0.0-27
- Clarify Antigravity IDE application description and Google packaging details
- Harmonize build-linux/build_rpm.sh symlink for automated multi-distro build matrix orchestration
- Set default staging hub URLs to staging.wheelhouser.com

* Thu Sep 24 2026 Steve Rock <steve.rock@wheelhouser.com> - 1.0.0-26
- Complete AppStream 1.0 software center metadata suite and expanded screenshot gallery
- Dual reverse-DNS desktop launchers (com.wheelhouser.antigravity-ide.desktop symlink)
- Clean up desktop file categories for full FreeDesktop menu specification compliance
- Add secure Let's Encrypt HTTPS staging mirror to payload fetch fallback chain

* Thu Sep 24 2026 Steve Rock <steve.rock@wheelhouser.com> - 1.0.0-25
- Multi-distro package build harmonization and automated QA verification across Fedora, Rocky, Alma, Debian, and Ubuntu

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

Name:           antigravity-ide
Version:        1.0.0
Release:        19%{?dist}
Summary:        Antigravity IDE launcher utility

License:        Proprietary
URL:            https://github.com/steve-rock-wheelhouser/antigravity-ide
Source0:        antigravity-ide-icon.png

BuildArch:      noarch

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
Launcher utility for Antigravity IDE on Fedora and Enterprise Linux (Rocky Linux 10).
It automatically downloads and installs the latest version of Antigravity IDE on first run.

%prep
# Nothing to prep

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_datadir}/pixmaps

# Copy icon
cp %{SOURCE0} %{buildroot}%{_datadir}/pixmaps/antigravity-ide-icon.png

# Create launcher wrapper script in /usr/bin/antigravity-ide
cat <<'EOF' > %{buildroot}%{_bindir}/antigravity-ide
#!/usr/bin/bash
# Clean up any stale antigravity-ide processes (excluding this wrapper script) to release the single-instance lock
pgrep -x antigravity-ide | grep -v "^$$$" | xargs kill -9 2>/dev/null || true
exec /usr/share/antigravity-ide/bin/antigravity-ide "$@"
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
Comment=Launch Antigravity IDE
Exec=%{_bindir}/antigravity-ide %u
Icon=antigravity-ide-icon
Terminal=false
Categories=Development;IDE;Utility;
MimeType=x-scheme-handler/antigravity;
StartupWMClass=antigravity
EOF

%pre
echo "Terminating any running Antigravity IDE processes..."
pkill -x antigravity-ide || true

%post
INSTALL_DIR="/usr/share/antigravity-ide"
echo "Downloading Antigravity IDE package from Google..."
mkdir -p "$INSTALL_DIR"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz"

if curl -sL -o "$TEMP_DIR/Antigravity-IDE.tar.gz" "$URL"; then
    echo "Extracting payload..."
    tar -xzf "$TEMP_DIR/Antigravity-IDE.tar.gz" -C "$TEMP_DIR"
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
        echo "Error: Antigravity IDE binary could not be found in the downloaded archive."
        exit 1
    fi
else
    echo "Error: Failed to download Antigravity IDE from $URL."
    exit 1
fi

%postun
if [ "$1" -eq 0 ]; then
    echo "Removing Antigravity IDE system-wide files..."
    rm -rf /usr/share/antigravity-ide
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database %{_datadir}/applications || true
fi

%files
%{_bindir}/antigravity-ide
%{_bindir}/antigravity
%{_datadir}/pixmaps/antigravity-ide-icon.png
%{_datadir}/applications/antigravity-ide.desktop

%changelog
* Wed Jun 24 2026 Steve Rock <steve.rock@marquee-magic.com> - 1.0.0-1
- Initial lightweight launcher RPM release

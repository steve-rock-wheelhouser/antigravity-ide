Name:           antigravity
Version:        1.0.0
Release:        15%{?dist}
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

# Create launcher wrapper script in /usr/bin/antigravity
cat <<'EOF' > %{buildroot}%{_bindir}/antigravity
#!/usr/bin/bash
# Clean up any stale antigravity processes (excluding this wrapper script) to release the single-instance lock
pgrep -x antigravity | grep -v "^$$$" | xargs kill -9 2>/dev/null || true
exec /usr/share/antigravity/antigravity "$@"
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

%pre
echo "Terminating any running Antigravity processes..."
pkill -x antigravity || true

%post
INSTALL_DIR="/usr/share/antigravity"
echo "Downloading Antigravity package from Google Cloud..."
mkdir -p "$INSTALL_DIR"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.1.4-6481382726303744/linux-x64/Antigravity.tar.gz"

if curl -sL -o "$TEMP_DIR/Antigravity.tar.gz" "$URL"; then
    echo "Extracting payload..."
    tar -xzf "$TEMP_DIR/Antigravity.tar.gz" -C "$TEMP_DIR"
    BIN_FILE=$(find "$TEMP_DIR" -name "antigravity" -type f | head -n 1)
    if [ -n "$BIN_FILE" ]; then
        SOURCE_DIR=$(dirname "$BIN_FILE")
        rm -rf "$INSTALL_DIR"/*
        cp -r "$SOURCE_DIR/"* "$INSTALL_DIR/"
        
        # Ensure correct system-wide permissions and ownership
        chown -R root:root "$INSTALL_DIR"
        chmod -R u+rwX,go+rX "$INSTALL_DIR"
        chmod +x "$INSTALL_DIR/antigravity"
        echo "Antigravity payload installed successfully in $INSTALL_DIR."
    else
        echo "Error: Antigravity binary could not be found in the downloaded archive."
        exit 1
    fi
else
    echo "Error: Failed to download Antigravity from $URL."
    exit 1
fi

%postun
if [ "$1" -eq 0 ]; then
    echo "Removing Antigravity system-wide files..."
    rm -rf /usr/share/antigravity
fi


%files
%{_bindir}/antigravity
%{_datadir}/pixmaps/antigravity-icon.png
%{_datadir}/applications/antigravity.desktop

%changelog
* Wed Jun 24 2026 Steve Rock <steve.rock@marquee-magic.com> - 1.0.0-1
- Initial lightweight launcher RPM release

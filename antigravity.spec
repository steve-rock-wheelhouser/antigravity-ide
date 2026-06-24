Name:           antigravity
Version:        1.0.0
Release:        1%{?dist}
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
#!/bin/bash
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin/antigravity"
BINARY="$INSTALL_DIR/antigravity"

if [ ! -f "$BINARY" ]; then
    echo "Antigravity binary not found at $BINARY."
    echo "Downloading and installing Antigravity..."
    mkdir -p "$INSTALL_DIR"
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT
    
    URL="https://github.com/steve-rock-wheelhouser/antigravity/releases/latest/download/Antigravity.tar.gz"
    
    echo "Downloading from $URL..."
    if curl -sL -o "$TEMP_DIR/Antigravity.tar.gz" "$URL"; then
        echo "Extracting payload..."
        tar -xzf "$TEMP_DIR/Antigravity.tar.gz" -C "$TEMP_DIR"
        BIN_FILE=$(find "$TEMP_DIR" -name "antigravity" -type f | head -n 1)
        if [ -z "$BIN_FILE" ]; then
            echo "Error: antigravity binary could not be found in the downloaded archive."
            exit 1
        fi
        SOURCE_DIR=$(dirname "$BIN_FILE")
        rm -rf "$INSTALL_DIR"/*
        cp -r "$SOURCE_DIR/"* "$INSTALL_DIR/"
        chmod +x "$BINARY"
        echo "Installation complete!"
    else
        echo "Error: Failed to download Antigravity from $URL."
        echo "Please ensure the release exists on GitHub."
        exit 1
    fi
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

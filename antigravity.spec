Name:           antigravity
Version:        1.0.0
Release:        1%{?dist}
Summary:        Antigravity launcher utility

License:        Proprietary
URL:            https://github.com/steve-rock-wheelhouser/antigravity
Source0:        Antigravity.tar.gz
Source1:        antigravity-icon.png

# No debuginfo subpackage is needed since we package a precompiled binary
%global debug_package %{nil}

%description
Launcher utility for Antigravity on Fedora.

%prep
%setup -q -c -n %{name}-%{version}

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_datadir}/pixmaps

# Find the binary inside the extracted files and copy it
BIN_FILE=$(find . -name "antigravity" -type f | head -n 1)
if [ -z "$BIN_FILE" ]; then
    echo "Error: antigravity binary not found in source archive"
    exit 1
fi
cp "$BIN_FILE" %{buildroot}%{_bindir}/antigravity
chmod 755 %{buildroot}%{_bindir}/antigravity

# Copy icon to pixmaps
cp %{SOURCE1} %{buildroot}%{_datadir}/pixmaps/antigravity-icon.png

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
- Initial RPM package release

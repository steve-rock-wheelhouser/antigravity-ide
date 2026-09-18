Name:           steve-rock-wheelhouser-release
Version:        1.0
Release:        1%{?dist}
Summary:        Steve Rock Wheelhouser repository configuration

License:        GPL-3.0-or-later
URL:            https://github.com/steve-rock-wheelhouser/fedora-repo
Source0:        steve-rock-wheelhouser.repo
Source1:        steve-rock-wheelhouser-gpg.key

BuildArch:      noarch

%description
This package contains the Steve Rock Wheelhouser Custom RPM Repository GPG key
and YUM/DNF repository configuration.

%prep
# Nothing to prep

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_sysconfdir}/yum.repos.d
mkdir -p %{buildroot}%{_sysconfdir}/pki/rpm-gpg

# Copy repo configuration
cp %{SOURCE0} %{buildroot}%{_sysconfdir}/yum.repos.d/steve-rock-wheelhouser.repo

# Copy GPG key
cp %{SOURCE1} %{buildroot}%{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-steve-rock-wheelhouser

%files
%{_sysconfdir}/yum.repos.d/steve-rock-wheelhouser.repo
%{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-steve-rock-wheelhouser

%changelog
* Wed Jun 24 2026 Steve Rock <steve.rock@marquee-magic.com> - 1.0-1
- Initial repository release package

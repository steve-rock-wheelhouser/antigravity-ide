# Antigravity IDE Linux Packaging & Launcher Utility

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Fedora Repo](https://img.shields.io/badge/Fedora-DNF%20Repo-294172?style=flat&logo=fedora&logoColor=white)](https://github.com/steve-rock-wheelhouser/fedora-repo)
[![Rocky Linux Repo](https://img.shields.io/badge/Rocky%20Linux-DNF%20Repo-10B981?style=flat&logo=rockylinux&logoColor=white)](https://github.com/steve-rock-wheelhouser/rocky-repo)

This repository provides open-source RPM packaging, build automation, desktop environment integration, and launcher tooling for **Google Antigravity IDE** on Red Hat Enterprise Linux derivatives (including **Rocky Linux 10**) and **Fedora**.

It packages the system launcher wrapper, registers the GNOME/XDG `.desktop` launcher and high-resolution icons, and manages downloading the stable Antigravity IDE application payload directly from official channels.

---

## Installation

You can install `antigravity-ide` via our public DNF repositories on either **Fedora** or **Rocky Linux / Enterprise Linux 10**.

### 1. Fedora

#### Option A: Install via Bootstrap RPM (Recommended)
This installs the repository configuration and imports our GPG signing key automatically:
```bash
sudo dnf install https://raw.githubusercontent.com/steve-rock-wheelhouser/fedora-repo/main/steve-rock-wheelhouser-release-1.0-1.fc44.noarch.rpm
sudo dnf install -y antigravity-ide
```

#### Option B: Manual Repository Setup
```bash
sudo curl -sL https://raw.githubusercontent.com/steve-rock-wheelhouser/fedora-repo/main/steve-rock-wheelhouser.repo -o /etc/yum.repos.d/steve-rock-wheelhouser.repo
sudo dnf install -y antigravity-ide
```

---

### 2. Rocky Linux 10 / Enterprise Linux 10

#### Option A: Install via Bootstrap RPM (Recommended)
```bash
sudo dnf install https://raw.githubusercontent.com/steve-rock-wheelhouser/rocky-repo/main/steve-rock-wheelhouser-release-1.0-1.el10.noarch.rpm
sudo dnf install -y antigravity-ide
```

#### Option B: Manual Repository Setup
```bash
sudo curl -sL https://raw.githubusercontent.com/steve-rock-wheelhouser/rocky-repo/main/steve-rock-wheelhouser.repo -o /etc/yum.repos.d/steve-rock-wheelhouser.repo
sudo dnf install -y antigravity-ide
```

---

## Launching Antigravity IDE

Once installed, you can launch the IDE via:
1. **Desktop Application Grid**: Search for **Antigravity IDE** in GNOME or your desktop application launcher.
2. **Terminal Command**:
   ```bash
   antigravity-ide
   # or
   antigravity
   ```

*Note: The launcher wrapper automatically handles single-instance process tracking and stale background cleanup.*

---

## Development & Maintenance

### Prerequisites
Install RPM build and repository tooling:
```bash
sudo dnf install -y rpm-build rpm-sign createrepo_c git
```

### Build the Application RPM
To build the application RPM (automatically increments the spec's `Release` version):
```bash
./build_rpm.sh
```

### Build the Release Configuration RPM
To build the distribution release RPM containing the repository configuration and GPG key:
```bash
./build_release_rpm.sh [--target rocky|fedora]
```
*(If `--target` is omitted, the script automatically detects your running distribution via `/etc/os-release`).*

### Publish to Public Repositories
To sign RPM builds, copy them to the target distribution repository, regenerate repository metadata, and commit:
```bash
./publish.sh [--target rocky|fedora]
```

---

## Community & Contributing

We welcome community contributions, bug reports, and packaging improvements!
- **Contributing Guidelines**: Review [CONTRIBUTING.md](CONTRIBUTING.md) for pull request instructions and commit conventions.
- **Code of Conduct**: This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).
- **Security Inquiries**: For responsible disclosure of potential vulnerabilities, refer to [SECURITY.md](SECURITY.md).

---

## Legal & Disclaimers

- **Packaging License**: The packaging scripts, RPM specifications, and tooling in this repository are licensed under the [GNU General Public License, Version 3.0 (GPLv3)](LICENSE).
- **Upstream Application**: **Google Antigravity IDE** is proprietary software developed and distributed by Google LLC. This repository is an independent community packaging effort by Wheelhouser LLC and is **not** affiliated with, endorsed by, or sponsored by Google LLC.
- **Trademarks**: "Antigravity", "Google", and associated logos are trademarks of Google LLC.

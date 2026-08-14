# Antigravity IDE Fedora RPM Repository & Launcher

Antigravity IDE is the launcher utility for the Antigravity workspace IDE on Fedora. This repository hosts the Fedora RPM package packaging configuration, build scripts, and publish scripts.

It installs system-wide launcher integration, registers the `.desktop` launcher, and handles downloading and caching the latest binary packages from the stable channel on install.

---

## Installation Instructions

You can set up the repository and install Antigravity IDE on your Fedora system in one of two ways:

### Option A: Install via Release Bootstrap RPM (Recommended)
This method automatically downloads and registers the repository configuration and imports the GPG signing keys for you:

```bash
sudo dnf install https://raw.githubusercontent.com/steve-rock-wheelhouser/fedora-repo/main/steve-rock-wheelhouser-release-1.0-1.fc44.noarch.rpm
sudo dnf install antigravity-ide
```

---

### Option B: Manual Repository Setup (Alternative)
If you prefer to configure the repository manually, you can download the `.repo` configuration file directly:

```bash
# 1. Download repository config file
sudo curl -sL https://raw.githubusercontent.com/steve-rock-wheelhouser/fedora-repo/main/steve-rock-wheelhouser.repo -o /etc/yum.repos.d/steve-rock-wheelhouser.repo

# 2. Install the package
sudo dnf install antigravity-ide
```

---

## Usage

Once installed, you can launch Antigravity IDE in two ways:
1. **Application Grid**: Click the **Antigravity IDE** icon in your desktop environment launcher.
2. **Terminal**: Run the command:
   ```bash
   antigravity-ide
   ```

*Note: Stale background processes are automatically managed and cleaned up upon launching, ensuring a fresh UI launch every time.*

---

## Development & Maintenance

### Prerequisites
Make sure the following packages are installed on your Fedora build machine:
```bash
sudo dnf install rpm-sign createrepo_c rpm-build
```

### Build the Application RPM
To build the application RPM package (automatically increments the spec's `Release` version on every run):
```bash
./build_rpm.sh
```

### Build the Release Configuration RPM
To build the release bootstrap RPM that packages the GPG key and repo config file:
```bash
./build_release_rpm.sh
```

### Publish to Public Repository
To copy the latest builds to your repository, sign them, generate YUM/DNF metadata, and push updates to the public GitHub repository:
```bash
./publish.sh
```
*(The repository retains only the 2 most recent application builds to allow easy user rollback, and the single latest release bootstrap build).*

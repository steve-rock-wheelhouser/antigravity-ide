# Integrating with Fedora Copr & Repology

This guide explains how to set up Fedora Copr (for automated community builds and hosting) and Repology (for package tracking and discovery).

---

## 1. Setting Up Fedora Copr

Fedora Copr is the official build system for community-maintained repositories. By setting up Copr, you can let Fedora's servers build, sign, host, and distribute your RPMs automatically every time you push to GitHub, replacing the need for manual signing and git pushing.

### Prerequisites
* You need a Fedora Account System (FAS) account. If you don't have one, register at [id.fedoraproject.org](https://id.fedoraproject.org/).

### Step 1: Create a Copr Project
1. Log in to [copr.fedorainfracloud.org](https://copr.fedorainfracloud.org/).
2. Click **New Project** in your dashboard.
3. Configure the project:
   * **Project Name**: `utilities` (or `antigravity`)
   * **Description**: Custom utilities by Steve Rock Wheelhouser.
   * **Chroots**: Select target architectures and Fedora releases (e.g., `fedora-40-x86_64`, `fedora-41-x86_64`, `fedora-rawhide-x86_64`).
4. Click **Create**.

### Step 2: Add a Package from GitHub
Copr can build directly from your GitHub repo using the spec file.
1. Inside your Copr project, go to the **Packages** tab and click **New Package**.
2. Configure:
   * **Name**: `antigravity`
   * **Source Type**: `git`
   * **Clone URL**: `https://github.com/steve-rock-wheelhouser/antigravity.git`
   * **Spec File Path**: `antigravity.spec` (Copr will find it at the root of your repo)
3. Click **Create**.

### Step 3: Trigger Builds and Configure Webhooks
* **Manual Build**: Click **Build** next to the package to trigger a manual compile.
* **Auto-Build on Push**: Copr provides a webhook URL (under the package settings). You can add this webhook URL to your GitHub repository settings under **Webhooks** (`Payload URL`) so that every time you run `git push`, Copr automatically rebuilds the package.

### Step 4: User Installation
Once built, users can enable your Copr repository and install packages with standard commands:
```bash
sudo dnf copr enable steve-rock-wheelhouser/utilities
sudo dnf install antigravity
```

---

## 2. Registering with Repology

Repology tracks version availability across all Linux distributions and repositories. Registering your repo makes your utilities searchable by the wider Linux community.

### Step 1: Submit Your Repository
To add your custom repository (`steve-rock-wheelhouser/fedora-repo`) to Repology:
1. Go to the [Repology Submit Page](https://repology.org/repository/new).
2. Fill out the request form:
   * **Repository Type**: `yum`
   * **Repository URL**: `https://raw.githubusercontent.com/steve-rock-wheelhouser/fedora-repo/main/`
   * **Repository Name**: `steve-rock-wheelhouser`
   * **Distribution**: `Fedora` (or `Fedora/Third party`)
3. Alternatively, you can open a Pull Request against the [Repology Rules repository on GitHub](https://github.com/repology/repology-rules) to add your YUM repository definition to their parser configs.

### Step 2: Track Package Versions
Once Repology accepts the repository, it will regularly scan your YUM metadata. It will display:
* Which versions of `antigravity` (or other utilities) are currently published.
* Whether they are up-to-date or out-of-date compared to your upstream GitHub releases.

# Debian & Ubuntu (.deb) Build System & Packaging Infrastructure

Establish complete Debian 13 and Ubuntu 24 `.deb` packaging, build orchestration, and APT repository publishing for `antigravity-ide` and the Wheelhouser ecosystem.

## User Review Required

> [!IMPORTANT]
> - **Build Environment Verification**: Both Debian 13 (`192.168.122.4`) and Ubuntu 24 (`192.168.122.212`) build VMs are online with SSH keys configured. Debian 13 has user-level `git` and `curl` configured in `~/.local/bin`, and both have `dpkg-deb` functional for non-root `.deb` creation.
> - **APT Repository Structure**: Debian and Ubuntu repositories will be hosted directly under `wheelhouserllc-repo/debian/13/` and `wheelhouserllc-repo/ubuntu/24/` (flat or scoped layout compatible with standard APT and GitHub Pages hosting), signed with the official Wheelhouser GPG key.

## Open Questions

None. The prerequisites have been thoroughly inspected and verified on the live VMs.

---

## Proposed Changes

### Antigravity IDE (`/home/user/Projects/antigravity-ide`)

#### [NEW] [build_deb.sh](file:///home/user/Projects/antigravity-ide/build_deb.sh) & `build-linux/build_deb.sh`
- Native Debian/Ubuntu packaging script using `dpkg-deb --build --root-owner-group`.
- Extracts version and release from `antigravity-ide.spec` (or CLI arguments `--no-bump`, `--target`, `--all`).
- Generates `DEBIAN/control` with correct runtime dependencies:
  `curl, tar, xdg-utils, desktop-file-utils, libnotify4, libxss1, libxkbfile1, libgbm1, libnss3, gnome-keyring, libsecret-1-0, libasound2t64 | libasound2`.
- Generates `DEBIAN/preinst` (process cleanup), `DEBIAN/postinst` (Google payload download and unpack into `/usr/share/antigravity-ide`, SUID root on `chrome-sandbox`, desktop database update), and `DEBIAN/postrm` (cleanup on purge/remove).
- Packages `/usr/bin/antigravity-ide`, `/usr/bin/antigravity` symlink, desktop entry, and icon.
- Outputs `.deb` to `build-linux/Output/$DISTRO_NAME/$DISTRO_VER/antigravity-ide_${VERSION}-${RELEASE}_all.deb`.

#### [MODIFY] [antigravity-ide.spec](file:///home/user/Projects/antigravity-ide/antigravity-ide.spec)
- Increment release to `22%{?dist}`.
- Add changelog entry noting official Debian 13 and Ubuntu 24 support.

#### [MODIFY] [README.md](file:///home/user/Projects/antigravity-ide/README.md)
- Add Debian & Ubuntu installation documentation alongside RPM instructions.

---

### Wheelhouser Repo & Repo Scripts (`/home/user/Projects/wheelhouserllc-repo` & `wheelhouserllc-repo-scripts`)

#### [NEW] [update_deb_repo.py](file:///home/user/Projects/wheelhouserllc-repo-scripts/update_deb_repo.py)
- Standalone Python utility to index `.deb` files in `wheelhouserllc-repo/debian/` and `wheelhouserllc-repo/ubuntu/`.
- Extracts package control fields, computes MD5/SHA1/SHA256, generates `Packages` and `Packages.gz`.
- Generates `Release` manifest with sha256 checksums and signs with GPG (`Release.gpg` and `InRelease`).

#### [MODIFY] [update_repo.sh](file:///home/user/Projects/wheelhouserllc-repo-scripts/update_repo.sh)
- Call `update_deb_repo.py` after signing RPMs to ensure both RPM and APT metadata are updated in one unified command.

#### [MODIFY] [wheelhouserllc-repo/index.html](file:///home/user/Projects/wheelhouserllc-repo/index.html)
- Add Debian 13 and Ubuntu 24.10 tabs and setup instructions (DEB822 sources list format and GPG keyring import).

---

### Wheelhouser Orchestra (`/home/user/Projects/orchestra`)

#### [MODIFY] [inventory/hosts.ini](file:///home/user/Projects/orchestra/inventory/hosts.ini)
- Partition `[rpm_build_nodes]` (rockylinux10, fedora44, almalinux10) and `[deb_build_nodes]` (debian13, ubuntu).
- Group `[build_nodes:children]` (rpm_build_nodes, deb_build_nodes).

#### [NEW] [playbooks/build_all_deb.yml](file:///home/user/Projects/orchestra/playbooks/build_all_deb.yml)
- Ansible playbook for DEB nodes (`debian13`, `ubuntu`):
  - Check SSH connectivity and ensure project repo exists (cloning if absent).
  - Synchronize git source on remote VMs (`pull.sh` or git fallback).
  - Execute `build_deb.sh` on each DEB node.
  - Collect generated `.deb` packages to host artifacts directory (`artifacts/debian/13/` and `artifacts/ubuntu/24/`).
  - Deploy collected `.deb` files to `wheelhouserllc-repo/debian/13/` and `wheelhouserllc-repo/ubuntu/24/` and host project `build-linux/Output/`.
  - Trigger `update_repo.sh` to update repodata and push repository.

#### [MODIFY] [src/config.py](file:///home/user/Projects/orchestra/src/config.py) & [src/main.py](file:///home/user/Projects/orchestra/src/main.py)
- Bump version to `0.2.8`.
- Define `PLAYBOOK_DEB_FILE = ORCHESTRA_DIR / "playbooks" / "build_all_deb.yml"`.
- Update `LinuxBuildWorker` in `src/workers.py` to trigger both RPM and DEB playbooks (or unified execution).

#### [MODIFY] [build-linux/build_rpm.sh](file:///home/user/Projects/orchestra/build-linux/build_rpm.sh)
- Rebuild Orchestra RPM package `orchestra-0.2.8-1.el10.noarch.rpm`.

---

### Epics Documentation

- Create `epics/2026-09-23-debian-ubuntu-deb-packaging/` in `antigravity-ide` with `implementation_plan.md` and `walkthrough.md`.
- Create `epics/2026-09-23-debian-ubuntu-deb-build-orchestration/` in `orchestra` with `implementation_plan.md` and `walkthrough.md`.

---

## Verification Plan

### Automated Tests
1. **DEB Build Execution**:
   - Run `build_deb.sh --no-bump` directly on `debian13` and `ubuntu` VMs:
     ```bash
     ssh user@192.168.122.4 "cd /home/user/Projects/antigravity-ide && ./build_deb.sh --no-bump"
     ssh user@192.168.122.212 "cd /home/user/Projects/antigravity-ide && ./build_deb.sh --no-bump"
     ```
   - Inspect generated `.deb` files with `dpkg-deb -I` and `dpkg-deb -c` to verify permissions, scripts, and dependencies.
2. **APT Repository Metadata Generation**:
   - Run `update_repo.sh` on Rocky 10 controller.
   - Verify `debian/13/Packages.gz`, `debian/13/Release`, `debian/13/Release.gpg`, `ubuntu/24/Packages.gz`, and signatures.
3. **Orchestra Playbook Integration**:
   - Execute DEB build playbook via Orchestra's virtual environment:
     ```bash
     /home/user/Projects/orchestra/.ansible-env/bin/ansible-playbook -i /home/user/Projects/orchestra/inventory/hosts.ini /home/user/Projects/orchestra/playbooks/build_all_deb.yml -e "project_name=antigravity-ide force_rebuild=true skip_git_push=false skip_git_pull=false build_only=false"
     ```
   - Verify full execution, artifact synchronization, and publication.

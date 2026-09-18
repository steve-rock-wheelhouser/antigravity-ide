# Walkthrough: Rocky Linux 10 Compatibility & RPM Conflict Resolution

We added Enterprise Linux 10 (Rocky Linux 10) compatibility across the packaging and release scripts in `antigravity-ide`, separated Rocky from Fedora publishing pipelines, and resolved DNF file conflicts between the legacy `antigravity` package and `antigravity-ide`.

## Changes Implemented

### 1. Spec File Packaging & Legacy Conflict Resolution
- **File**: [antigravity-ide.spec](file:///home/user/Projects/antigravity-ide/antigravity-ide.spec)
- **Commits**: `90873d7`, `0729f23`
- **Updates**:
  - Added `Obsoletes: antigravity < 1.0.0-13` and `Conflicts: antigravity < 1.0.0-13` to resolve:
    ```
    Error: Transaction test error:
      file /usr/bin/antigravity from install of antigravity-ide-1.0.0-19.el10.noarch conflicts with file from package antigravity-1.0.0-12.el10.noarch
    ```
  - Added symlink `/usr/bin/antigravity -> /usr/bin/antigravity-ide` in `%install` and `%files`.
  - Added `update-desktop-database` execution in `%post` and `%postun` scriptlets.

### 2. OS Autodetection & Build Targeting
- **File**: [build_release_rpm.sh](file:///home/user/Projects/antigravity-ide/build_release_rpm.sh)
- **Updates**:
  - Implemented auto-detection from `/etc/os-release`:
    - `ID=rocky` or `ID_LIKE=rhel` selects `rocky-repo`.
    - `ID=fedora` selects `fedora-repo`.
  - Added CLI flag `--target [rocky|fedora]` for manual overrides.

### 3. Release Publishing Pipeline
- **File**: [publish.sh](file:///home/user/Projects/antigravity-ide/publish.sh)
- **Updates**:
  - Synchronized target repository autodetection to prevent pushing Rocky RPMs to `fedora-repo`.
  - Added cleanup logic to remove older legacy `antigravity-[0-9]*.rpm` packages from the repository.
  - Retained the 2 most recent `antigravity-ide` builds.
  - Automatically invoked `$REPO_DIR/update_repo.sh` to re-sign RPMs and rebuild repository metadata.

---

## Validation & Verification

1. **RPM Build & GPG Signing**:
   - Built release RPMs targeting Enterprise Linux 10 (`.el10`).
   - Verified GPG signing with key `Wheelhouser LLC (Automated Release Pipeline) <steve.rock@wheelhouser.com>` (`1117A616E67A90C4`).

2. **Repository Deployment**:
   - Executed `./publish.sh --target rocky`.
   - Verified `steve-rock-wheelhouser/rocky-repo` metadata regenerated via `createrepo_c` and pushed to GitHub main branch.

3. **Installation & Conflict Resolution**:
   - Ran `sudo dnf install -y antigravity-ide` on Rocky Linux 10 with `antigravity-1.0.0-12.el10` previously installed.
   - DNF cleanly replaced the obsolete package without conflict errors on `/usr/bin/antigravity`.
   - Verified launcher desktop entry, application icon, and terminal commands (`antigravity` and `antigravity-ide`).

---

## Spec Changelog Reference

For synchronization with [antigravity-ide.spec](file:///home/user/Projects/antigravity-ide/antigravity-ide.spec), the following `%changelog` entry corresponds to this epic:

```spec
* Fri Sep 18 2026 Steve Rock <steve.rock@marquee-magic.com> - 1.0.0-20
- Add Enterprise Linux 10 (Rocky Linux 10) autodetection and repository targeting
- Add Obsoletes and Conflicts for legacy antigravity package (< 1.0.0-13)
- Symlink /usr/bin/antigravity to /usr/bin/antigravity-ide
- Update desktop database on install and uninstall
```

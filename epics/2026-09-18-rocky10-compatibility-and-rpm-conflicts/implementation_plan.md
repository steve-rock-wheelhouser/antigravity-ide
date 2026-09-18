# Implementation Plan: Rocky Linux 10 Compatibility & Legacy RPM Conflict Resolution

Enable Enterprise Linux 10 (Rocky Linux 10) compatibility for Antigravity IDE RPM packaging and repository distribution, prevent cross-contamination between Fedora and Rocky repositories, and resolve file conflict errors during upgrades from the legacy package.

## Proposed Changes

### Packaging & Spec Configuration

#### [antigravity-ide.spec](file:///home/user/Projects/antigravity-ide/antigravity-ide.spec)
- **Legacy Package Replacement**: Add `Obsoletes: antigravity < 1.0.0-13` and `Conflicts: antigravity < 1.0.0-13` so DNF cleanly upgrades existing systems without file conflict errors on `/usr/bin/antigravity`.
- **Dual Binary Symlinks**: Ensure `/usr/bin/antigravity` symlinks to `/usr/bin/antigravity-ide` so both CLI commands work interchangeably.
- **Desktop Database Integration**: Run `update-desktop-database %{_datadir}/applications` in both `%post` and `%postun` scriptlets.
- **Process Cleanup**: Ensure `%pre` scriptlet gracefully terminates existing running IDE instances prior to file overwrites.

### Build & Release Tooling

#### [build_release_rpm.sh](file:///home/user/Projects/antigravity-ide/build_release_rpm.sh)
- **Target OS Autodetection**: Inspect `/etc/os-release` to dynamically determine whether the build target is `rocky` (Rocky Linux / RHEL derivatives) or `fedora`.
- **Target Flag Support**: Accept `--target|-t [rocky|fedora]` to allow explicit target overrides.
- **Repository Path Routing**: Direct repository targets to `../rocky-repo` or `../fedora-repo` accordingly.

#### [publish.sh](file:///home/user/Projects/antigravity-ide/publish.sh)
- **Target Repo Autodetection**: Coordinate target detection with `build_release_rpm.sh` to prevent pushing Rocky RPMs to `fedora-repo` or vice-versa.
- **Retention Hygiene**: Keep only the 2 most recent `antigravity-ide` builds and remove legacy `antigravity-*.rpm` packages from the repository root.
- **Automated Repository Update**: Execute `update_repo.sh` in the resolved target repository to re-sign packages, rebuild repodata via `createrepo_c`, and push upstream.

---

## Verification Plan

### Automated Tests
- Test OS detection logic in `build_release_rpm.sh` and `publish.sh` on Rocky Linux 10 (`/etc/os-release`).
- Validate RPM spec file syntax and packaging build via `rpmbuild`.
- Verify package GPG signing using `rpmsign --checksig`.

### Manual Verification
- Run `publish.sh` to update `steve-rock-wheelhouser/rocky-repo`.
- Run `sudo dnf install -y antigravity-ide` on a Rocky Linux 10 system with the legacy `antigravity` package installed to confirm conflict resolution and clean replacement.

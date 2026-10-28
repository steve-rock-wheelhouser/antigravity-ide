# Implementation Plan: Google Antigravity IDE CLI Core Update Support (`antigravity-ide --update`)

**Date:** 2026-10-28  
**Epic Directory:** `epics/2026-10-28-cli-core-update-support`  
**Target Project:** `antigravity-ide`

---

## 1. Executive Summary

This epic introduces CLI-driven core payload updating capabilities (`antigravity-ide --update`) into the Wheelhouser Linux packaging and launcher wrapper suite for Google Antigravity IDE.

Currently, the launcher script installed at `/usr/bin/antigravity-ide` passes all arguments directly via `exec` to the underlying Electron binary, which does not provide native Linux CLI self-updating capabilities. This implementation refactors the launcher wrapper into a dedicated, maintainable source script (`src/antigravity-ide.sh`), adds command-line lifecycle management (`--update`, `--check-update`, `--wrapper-version`), and integrates atomic installation and rollback safeguards for both system-wide (`/usr/share/antigravity-ide`) and user-local (`~/.local/share/antigravity-ide`) environments.

---

## 2. Problem Statement & Motivation

- **Upstream Gap:** Google's Antigravity IDE Electron binary for Linux disables in-place CLI self-updates (`product.json` sets `"updateUrl": "https://example.com"`).
- **Maintenance Redundancy:** The current launcher script logic is duplicated across bash heredocs in `antigravity-ide.spec` and `build_deb.sh`.
- **User Workflow:** Developers and system administrators require a fast, headless, scriptable command (`antigravity-ide --update`) to upgrade the core application without manually downloading tarballs or reinstalling packages.

---

## 3. Architecture & Technical Design

### 3.1 CLI Interface & Dispatching
The wrapper intercepts management flags before launching the Electron IDE:
- `antigravity-ide --update [archive_path_or_url]` (or `-u`):
  - Fetches the latest stable payload from Google CDN or mirrors, or extracts a specified local tarball / remote URL.
  - Verifies payload integrity, backs up the existing installation, performs atomic replacement, and restores SUID sandbox permissions.
- `antigravity-ide --check-update`:
  - Inspects currently installed version (`resources/app/product.json` and `resources/app/package.json`) and queries upstream release status without modifying files.
- `antigravity-ide --wrapper-version`:
  - Displays the Wheelhouser packaging wrapper version.
- `antigravity-ide --help-launcher`:
  - Displays help and usage information for launcher options.
- `antigravity-ide [editor-args]`:
  - Standard fast-path passthrough to the installed Electron binary.

### 3.2 Permission Elevation & Multi-User Support
- **System Installation (`/usr/share/antigravity-ide`):**
  - If executed by an unprivileged user, detects write restrictions and automatically re-executes via `sudo` after displaying a clear notice.
- **User-Local Installation (`$HOME/.local/share/antigravity-ide`):**
  - Executes directly without requiring elevated privileges.

### 3.3 Atomic Safety & Rollback Protections
- **Process Guard:** Checks for active `antigravity-ide` processes to prevent file-locking corruption during binary replacement.
- **Integrity Validation:** Validates `gzip -t` and asserts presence of `chrome-sandbox` and `bin/antigravity-ide` before modifying the destination.
- **Atomic Rollback:** Creates an in-memory/temp backup of the current installation prior to extraction; if file transfer fails, the prior version is restored automatically.
- **SUID Sandbox Restoration:** Enforces `chown root:root` and `chmod 4755` on `chrome-sandbox` when running as root to preserve Chromium sandbox requirements on Fedora/Rocky Linux/Debian.

---

## 4. Implementation Steps

1. **Source Consolidation (`src/antigravity-ide.sh`):**
   - Create unified launcher script with robust argument parsing, version detection, downloading, extraction, atomic rollback, and SUID enforcement.
2. **RPM Packaging Integration (`antigravity-ide.spec` & `build_rpm.sh`):**
   - Add `Source4: antigravity-ide.sh` to spec file and install from source.
   - Bump release number from 38 to 39 and update `%changelog`.
   - Update `build_rpm.sh` to stage `src/antigravity-ide.sh` into RPM sources.
3. **Debian Packaging Integration (`build_deb.sh`):**
   - Replace embedded heredoc with `install -m 755 "$PROJECT_ROOT/src/antigravity-ide.sh" "$BUILD_ROOT/usr/bin/antigravity-ide"`.
4. **Standalone User Installer (`install.sh`):**
   - Harmonize wrapper deployment to use `src/antigravity-ide.sh`.
5. **Documentation (`README.md`):**
   - Add CLI usage instructions for `--update` and `--check-update`.
6. **Testing & Verification:**
   - Test CLI flags (`--wrapper-version`, `--check-update`, `--help-launcher`).
   - Test update flow with archive and dry-run verification.
   - Test full RPM build and cryptographic signature validation (`rpmsign`, `rpm -Kv`).
   - Create `walkthrough.md` in epic directory.

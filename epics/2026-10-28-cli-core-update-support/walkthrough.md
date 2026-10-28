# Walkthrough: Google Antigravity IDE CLI Core Update Support (`antigravity-ide --update`)

**Date:** 2026-10-28  
**Epic Directory:** `epics/2026-10-28-cli-core-update-support`  
**Package Release:** `1.0.0-39`

---

## 1. Overview & Objectives

In response to the requirement for managing and updating the Google Antigravity IDE core engine directly via the command line, this epic implemented full CLI lifecycle and update tooling into the `antigravity-ide` launcher suite.

Key capabilities introduced:
- `antigravity-ide --update [path|url]` (or `-u`): In-place updating/reinstallation of the core payload with integrity validation and atomic rollback.
- `antigravity-ide --check-update`: Non-destructive version querying and release channel status verification.
- `antigravity-ide --wrapper-version`: Displays Wheelhouser packaging version alongside core version.
- `antigravity-ide --help-launcher`: Launcher management usage reference.
- `src/antigravity-ide.sh`: Centralized, maintainable launcher script replacing embedded inline bash heredocs across RPM and Debian build pipelines.

---

## 2. Changes Summary

| File | Change Description |
| :--- | :--- |
| `src/antigravity-ide.sh` | Created canonical launcher script featuring argument dispatching, version detection, downloading, verification, atomic rollback, and SUID enforcement. |
| `antigravity-ide.spec` | Added `Source4: antigravity-ide.sh`, eliminated ~120 lines of duplicate heredoc in `%install`, bumped release to `39`, and added `%changelog` record. |
| `build_rpm.sh` | Staged `src/antigravity-ide.sh` to RPMBUILD sources; built and signed RPM packages for Fedora 44, Rocky Linux 10, and AlmaLinux 10. |
| `build_deb.sh` | Replaced duplicate embedded heredoc with `install -m 755 "$LAUNCHER_SCRIPT" "$BUILD_ROOT/usr/bin/antigravity-ide"`. |
| `install.sh` | Updated standalone local installer to deploy `src/antigravity-ide.sh`. |
| `README.md` | Documented CLI core update workflows, version checking, and options. |

---

## 3. Verification & Testing

### 3.1 CLI Management Command Verification

1. **Launcher Help:**
   ```bash
   $ src/antigravity-ide.sh --help-launcher
   Google Antigravity IDE - Linux Launcher & Manager (v1.0.0-39)
   Usage: antigravity-ide [launcher-options] [editor-arguments]

   Launcher Management Commands:
     --update, -u [path|url]     Update or reinstall the Google Antigravity IDE core payload.
     --check-update              Check installed core version against latest available payload.
     --wrapper-version           Display the Wheelhouser Linux launcher wrapper version.
     --help-launcher             Display this launcher wrapper help menu.
   ```

2. **Wrapper and Core Version Display:**
   ```bash
   $ src/antigravity-ide.sh --wrapper-version
   Antigravity IDE Launcher (Wheelhouser packaging): v1.0.0-39
   Installed Google IDE Core: v2.5.5 (/usr/share/antigravity-ide)
   ```

3. **Check Update Status:**
   ```bash
   $ src/antigravity-ide.sh --check-update
   ========================================================================
   🔍 Antigravity IDE Core Version Check
   ========================================================================
   Launcher Wrapper Version : v1.0.0-39
   Installation Directory   : /usr/share/antigravity-ide
   Installed Core Version   : v2.5.5
   Checking Google CDN release channel...
   Upstream Channel Status  : Available (Last Modified: Mon, 26 Oct 2026 14:10:53 GMT)
   ========================================================================
   To update to the latest payload, run: antigravity-ide --update
   ```

### 3.2 Update Execution & Atomic Rollback Tests

- **Mock Payload Update (`v2.5.5` -> `v2.6.0`):**
  - Simulated payload update using sandbox environment.
  - Verified extraction, version parsing, backup creation, and atomic swap into destination directory.
  - Successfully transitioned version from `v2.5.5` to `v2.6.0`.
- **Corrupt / Invalid Archive Rollback Guard:**
  - Tested update with archive missing `chrome-sandbox`.
  - Verified error was intercepted, destination was left unmodified, and prior installation remained fully intact.

### 3.3 RPM Packaging & Cryptographic Signature Validation

Executed full RPM build matrix:
```bash
./build_rpm.sh --no-bump --target all
```
Output:
- Enterprise Linux 10: `build-linux/Output/rocky/10/antigravity-ide-1.0.0-39.el10.noarch.rpm`
- Fedora 44: `build-linux/Output/fedora/44/antigravity-ide-1.0.0-39.fc44.noarch.rpm`
- Cryptographic verification (`rpmsign`, `rpm -Kv`): Both packages verified with Header V4 RSA/SHA256 signatures `OK`.

# Implementation Plan: Open Source Readiness & Secrets Sanitization for antigravity-ide

Prepare the `steve-rock-wheelhouser/antigravity-ide` repository for public open-source release on GitHub. This epic guarantees zero exposure of secrets, synchronizes security and gitignore policies with [AGENTS.md](file:///home/user/Projects/AGENTS.md), establishes proper open-source licensing and legal disclaimers, updates documentation for both Fedora and Rocky Linux, adds standard community governance files, and provides step-by-step guidance for safely switching repository visibility on GitHub.

## User Review Required

> [!IMPORTANT]
> **Audit Finding: No Secrets in Git History**
> A comprehensive scan of all git revisions in `antigravity-ide` confirmed that **no private keys, GPG secret files, or API credentials have ever been committed** to this repository. The GPG secret key mentioned in `.gitignore` was never staged or tracked in Git.

> [!WARNING]
> **Licensing Distinction: Wrapper vs. Upstream Binary**
> Google Antigravity IDE itself is proprietary software distributed by Google. This repository provides the **open-source packaging, build scripts, desktop integration, and system wrappers**. 
> We must clearly document this distinction in `README.md`, `LICENSE`, and spec files so downstream users and contributors understand that the packaging is open source while the downloaded binary is subject to Google's terms.

## Design Decisions

- **License**: Selected **GNU General Public License v3.0 (GPLv3 / GPL-3.0-or-later)** to match the predominant open-source licensing standard for Rocky Linux userland packages and ensure reciprocal open-source improvements.
- **Contact & Security Reporting Email**: Configured to `steve.rock@wheelhouser.com`.
- **Pruning Legacy Files**: Removed obsolete `assets/misc/backup.sh`.

---

## Proposed Changes

### 1. Security & Secrets Hardening

#### [MODIFY] [.gitignore](file:///home/user/Projects/antigravity-ide/.gitignore)
- Expand `.gitignore` to match the mandatory baseline in [AGENTS.md](file:///home/user/Projects/AGENTS.md):
  ```gitignore
  # Secrets, keys, and credentials
  *.key
  *.pem
  *.asc
  *.p12
  *-secret.*
  .env*

  # Build artifacts & packaging caches
  rpmbuild/
  rpmbuild-release/
  *.rpm
  *.iso
  build/
  dist/
  ```

#### [MODIFY] [push.sh](file:///home/user/Projects/antigravity-ide/push.sh)
- Remove `git add -A` and replace with safe staging audit checks so local files aren't accidentally swept into commits.
- Ensure commit messages prompt for or use Conventional Commits per `AGENTS.md`.

#### [DELETE] [assets/misc/backup.sh](file:///home/user/Projects/antigravity-ide/assets/misc/backup.sh)
- Remove obsolete backup script.

---

### 2. Legal, Licensing & Disclaimers

#### [NEW] [LICENSE](file:///home/user/Projects/antigravity-ide/LICENSE)
- Add full text for the selected open-source license (e.g. Apache 2.0 or MIT), copyrighted to Wheelhouser LLC / Steve Rock.

#### [MODIFY] [antigravity-ide.spec](file:///home/user/Projects/antigravity-ide/antigravity-ide.spec)
- Update `License:` tag from `Proprietary` to the chosen license (e.g. `Apache-2.0`).
- Clarify in `%description` that this package distributes the open-source launcher wrapper and downloads the official Antigravity IDE payload.

---

### 3. Documentation & Community Health

#### [MODIFY] [README.md](file:///home/user/Projects/antigravity-ide/README.md)
- Modernize README with:
  - Repository introduction and badges for both `fedora-repo` and `rocky-repo`.
  - Installation instructions for **both** Fedora and Rocky Linux 10 / Enterprise Linux.
  - Development and build instructions for contributors.
  - License and Third-Party Trademark / Upstream Disclaimer (making clear Antigravity is a trademark of Google and not affiliated with Wheelhouser LLC).

#### [NEW] [CONTRIBUTING.md](file:///home/user/Projects/antigravity-ide/CONTRIBUTING.md)
- Guidelines for filing issues, testing RPM builds, and submitting pull requests following Conventional Commits and [AGENTS.md](file:///home/user/Projects/AGENTS.md) standards.

#### [NEW] [SECURITY.md](file:///home/user/Projects/antigravity-ide/SECURITY.md)
- Clear policy on reporting potential security issues privately without disclosing zero-day vulnerabilities in public GitHub issues.

#### [NEW] [CODE_OF_CONDUCT.md](file:///home/user/Projects/antigravity-ide/CODE_OF_CONDUCT.md)
- Add standard Contributor Covenant v2.1 to foster an open, welcoming community.

---

### 4. GitHub Visibility Transition Checklist

Once code changes are verified and committed:
1. **GitHub Settings**:
   - Go to `https://github.com/steve-rock-wheelhouser/antigravity-ide/settings`
   - Scroll to **Danger Zone** -> **Change repository visibility** -> Select **Make public**.
2. **Branch Protection**:
   - Enable branch protection on `main` to prevent force-pushes from any contributor.
3. **Repository Metadata**:
   - Add topics: `rpm`, `fedora`, `rocky-linux`, `enterprise-linux`, `antigravity`, `developer-tools`, `packaging`.

---

## Verification Plan

### Automated Tests
- Run `git status` and verify no sensitive files are untracked or staged.
- Run `git log -p` audit to ensure clean history.
- Dry-run `build_rpm.sh` to confirm the spec file compiles properly with the updated `License:` and `%description`.

### Manual Verification
- Verify all links in `README.md`, `CONTRIBUTING.md`, and `SECURITY.md` point to valid public repositories.
- Perform final pre-publication checklist with user before flipping visibility on GitHub.

# Contributing to Antigravity IDE Packaging

Thank you for your interest in contributing to the Antigravity IDE packaging project! We welcome contributions that improve distribution support, packaging efficiency, launcher stability, and desktop integration.

---

## Code of Conduct

All contributors are expected to adhere to our [Code of Conduct](file:///home/user/Projects/antigravity-ide/CODE_OF_CONDUCT.md). Please treat all members of the community with respect and courtesy.

---

## Development & Local Testing

### Prerequisites
To build and test RPM packages locally, ensure your Fedora or Rocky Linux machine has the necessary packaging tools:
```bash
sudo dnf install -y rpm-build rpm-sign createrepo_c git
```

### Local Build Workflow
1. **Fork and Clone**:
   ```bash
   git clone https://github.com/steve-rock-wheelhouser/antigravity-ide.git
   cd antigravity-ide
   ```
2. **Build the Application RPM**:
   ```bash
   ./build_rpm.sh
   ```

---

## Commit Guidelines

We enforce the **Conventional Commits** specification to ensure standardized git history and automated changelog compatibility:

```
<type>(<scope>): <imperative description>

[optional body explaining motivation and changes]
```

### Allowed Types:
- `feat`: New feature (e.g., `feat(rpm): add CentOS Stream 10 support`)
- `fix`: Bug fix (e.g., `fix(desktop): add missing MIME type handler`)
- `sec`: Security enhancement or secret mitigation
- `build`: Packaging or build script adjustments
- `ci`: Automated repository publishing scripts
- `docs`: Documentation updates
- `refactor`: Code refactoring without behavioral change
- `chore`: Maintenance tasks or dependency updates

---

## Pull Request Process

1. Create a descriptive feature branch from `main`:
   ```bash
   git checkout -b feat/add-distro-support
   ```
2. Ensure no sensitive files, credentials, or personal keys are staged.
3. Verify the RPM builds cleanly and passes syntax checks before submitting:
   ```bash
   rpmbuild --nobuild --define "_topdir $(pwd)/rpmbuild" -ba antigravity-ide.spec
   ```
4. Open a Pull Request against `main` with a clear explanation of what changed and what distributions were tested.

---

## Licensing of Contributions

By submitting a Pull Request, you agree that your contributions will be licensed under the [GNU General Public License, Version 3.0](file:///home/user/Projects/antigravity-ide/LICENSE).

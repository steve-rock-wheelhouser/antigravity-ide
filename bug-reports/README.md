# antigravity-ide Bug Reports & QA Ticketing System

This directory maintains the file-based QA and issue tracking history for **antigravity-ide**.
Tickets are created automatically by the Wheelhouser Automated Fleet QA Harness
(`orchestra/scripts/test_candidate_fleet.sh`) or manually filed by maintainers.

## Directory Structure
```text
bug-reports/
├── installation/             # Package installation & dependency errors (DNF, APT, MSIX, DMG)
│   ├── linux/
│   │   ├── debian/          # Debian GNU/Linux
│   │   ├── ubuntu/          # Ubuntu Linux
│   │   ├── fedora/          # Fedora Linux
│   │   ├── rocky/           # Rocky Linux (Enterprise Linux)
│   │   └── almalinux/       # AlmaLinux (Enterprise Linux)
│   ├── windows/             # Windows sideload / MSIX install issues
│   └── macos/               # macOS DMG / App bundle verification issues
├── run-time/                 # Post-installation execution errors (crashes, missing DLLs/so, timeouts)
│   ├── linux/ (distros)
│   ├── windows/
│   └── macos/
└── marketing/                # Store packaging and metadata readiness
    ├── metadata/            # AppStream metainfo.xml, AppxManifest.xml, Info.plist
    ├── assets/              # Icons, banners, screenshot requirements
    └── store-listings/      # Store descriptions, keywords, localized copy
```

## Frontmatter Schema
Each ticket is formatted in standard Markdown with YAML frontmatter:
```yaml
---
ticket_id: "BUG-YYYYMMDD_HHMMSS"
type: "installation"          # installation | run-time | marketing
status: "open"                # open | in-progress | resolved | closed
severity: "high"              # low | medium | high | critical
project: "antigravity-ide"
package: "package-filename.rpm"
os: "linux"                   # linux | windows | macos
distro: "rocky"               # debian | ubuntu | fedora | rocky | almalinux | windows | macos
distro_version: "10.2"
node: "user@10.0.0.166:2202"
commit: "abcdef0"
date: "YYYY-MM-DDTHH:MM:SSZ"
closed_at: "YYYY-MM-DDTHH:MM:SSZ"     # Populated upon resolution
resolved_by: "Explanation or package" # Populated upon resolution
---
```

## Ticket Lifecycle Management
Manage tickets using the central Orchestra CLI tool:
```bash
# List all open bug reports across projects
orchestra/scripts/manage_bugs.py list --status open

# List bugs for this project only
orchestra/scripts/manage_bugs.py list --project antigravity-ide

# Resolve / Close a bug ticket
orchestra/scripts/manage_bugs.py close BUG-YYYYMMDD_HHMMSS --reason "Enabled EPEL 10" --resolved-by "v0.15.0-2"

# Reopen a ticket
orchestra/scripts/manage_bugs.py reopen BUG-YYYYMMDD_HHMMSS
```

#!/bin/bash
set -euo pipefail

# Ensure script runs from its own directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure standard system paths are in the PATH
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:${PATH:-}"

# Parse command line options
TARGET=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target|-t)
            TARGET="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") [--target rocky|fedora]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $(basename "$0") [--target rocky|fedora]"
            exit 1
            ;;
    esac
done

REPO_DIR="$(cd "$SCRIPT_DIR/../wheelhouserllc-repo" && pwd)"

# Verify destination repository exists
if [ ! -d "$REPO_DIR" ]; then
    echo "Error: Target repository directory not found at $REPO_DIR"
    exit 1
fi

echo "Locating the most recent Antigravity IDE RPM build..."
LATEST_RPM=$(ls -t "$SCRIPT_DIR"/antigravity-ide-*.rpm 2>/dev/null | head -n 1)

if [ -z "$LATEST_RPM" ]; then
    echo "Error: No Antigravity IDE RPM build found in $SCRIPT_DIR."
    echo "Please run ./build_rpm.sh first."
    exit 1
fi

RPM_FILENAME=$(basename "$LATEST_RPM")
echo "Found most recent build: $RPM_FILENAME"

# Detect release major version, distro tag, and architecture from RPM headers
RPM_RELEASE=$(rpm -qp --queryformat '%{RELEASE}' "$LATEST_RPM" 2>/dev/null || true)
RPM_ARCH=$(rpm -qp --queryformat '%{ARCH}' "$LATEST_RPM" 2>/dev/null || true)

DISTRO_TAG=$(echo "$RPM_RELEASE" | grep -oE '(el|fc)' || true)
DISTRO_VER=$(echo "$RPM_RELEASE" | grep -oE '(el|fc)[0-9]+' | sed -E 's/^(el|fc)//' || true)

if [ -n "$TARGET" ]; then
    DISTRO_NAME="$TARGET"
elif [ "$DISTRO_TAG" == "el" ]; then
    DISTRO_NAME="rocky"
elif [ "$DISTRO_TAG" == "fc" ]; then
    DISTRO_NAME="fedora"
else
    # Auto-detect from host OS
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [[ "${ID:-}" == "rocky" || "${ID_LIKE:-}" =~ rhel ]]; then
            DISTRO_NAME="rocky"
        elif [[ "${ID:-}" == "fedora" ]]; then
            DISTRO_NAME="fedora"
        else
            DISTRO_NAME="rocky"
        fi
    else
        DISTRO_NAME="rocky"
    fi
fi

if [ -z "$DISTRO_VER" ]; then
    if [ "$DISTRO_NAME" == "rocky" ]; then
        DISTRO_VER="10"
    else
        DISTRO_VER="44"
    fi
fi

echo "Target Distribution: $DISTRO_NAME (Release $DISTRO_VER)"
echo "Repository path: $REPO_DIR"

# Determine target subtrees (e.g., rocky/10/x86_64 and rocky/10/aarch64 for noarch packages)
TARGET_SUBDIRS=()
if [ "$RPM_ARCH" == "noarch" ]; then
    TARGET_SUBDIRS=("$REPO_DIR/$DISTRO_NAME/$DISTRO_VER/x86_64" "$REPO_DIR/$DISTRO_NAME/$DISTRO_VER/aarch64")
else
    TARGET_SUBDIRS=("$REPO_DIR/$DISTRO_NAME/$DISTRO_VER/$RPM_ARCH")
fi

echo "Routing package to target subtrees (${TARGET_SUBDIRS[*]}):"

for dest_dir in "${TARGET_SUBDIRS[@]}"; do
    mkdir -p "$dest_dir"
    echo "Copying $RPM_FILENAME to $dest_dir..."
    cp "$LATEST_RPM" "$dest_dir/"

    # Clean up older antigravity-ide builds in this specific subtree (keeping only the 2 most recent)
    RPM_FILES=("$dest_dir"/antigravity-ide-*.rpm)
    if [ -f "${RPM_FILES[0]}" ]; then
        ls -t "${RPM_FILES[@]}" 2>/dev/null | tail -n +3 | while read -r old_rpm; do
            if [ -f "$old_rpm" ]; then
                echo "Removing older build: $(basename "$old_rpm") from $dest_dir"
                rm -f "$old_rpm"
            fi
        done
    fi
done

# Clean up legacy antigravity (non-ide) builds across the repository
find "$REPO_DIR" -type f -name "antigravity-[0-9]*.rpm" -delete 2>/dev/null || true


# Run the repository update script (which signs, rebuilds metadata, commits and pushes)
if [ -f "$SCRIPT_DIR/../scripts/update_repo.sh" ]; then
    echo "Running ../scripts/update_repo.sh on $REPO_DIR..."
    "$SCRIPT_DIR/../scripts/update_repo.sh" "$REPO_DIR"
elif [ -f "$REPO_DIR/scripts/update_repo.sh" ]; then
    echo "Running scripts/update_repo.sh in $REPO_DIR..."
    "$REPO_DIR/scripts/update_repo.sh"
elif [ -f "$REPO_DIR/update_repo.sh" ]; then
    echo "Running update_repo.sh in $REPO_DIR..."
    (cd "$REPO_DIR" && ./update_repo.sh)
else
    echo "Error: update_repo.sh not found (checked ../scripts/update_repo.sh and $REPO_DIR)"
    exit 1
fi

echo "Publishing complete!"

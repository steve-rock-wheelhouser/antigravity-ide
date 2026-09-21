#!/bin/bash
set -euo pipefail

# Ensure script runs from its own directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure standard system paths are in the PATH
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:${PATH:-}"

# Parse command line options
TARGET="all"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target|-t)
            TARGET="$2"
            shift 2
            ;;
        --all)
            TARGET="all"
            shift
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") [--target rocky|almalinux|fedora|all]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $(basename "$0") [--target rocky|almalinux|fedora|all]"
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

clean_old_rpms() {
    local target_dir="$1"
    local rpm_files=("$target_dir"/antigravity-ide-*.rpm)
    if [ -f "${rpm_files[0]}" ]; then
        ls -t "${rpm_files[@]}" 2>/dev/null | tail -n +3 | while read -r old_rpm; do
            if [ -f "$old_rpm" ]; then
                echo "Removing older build: $(basename "$old_rpm") from $target_dir"
                rm -f "$old_rpm"
            fi
        done
    fi
}

deploy_package() {
    local rpm_path="$1"
    local distro_name="$2"
    local distro_ver="$3"
    local rpm_arch
    rpm_arch="$(rpm -qp --queryformat '%{ARCH}' "$rpm_path" 2>/dev/null || echo "noarch")"
    local rpm_fname
    rpm_fname="$(basename "$rpm_path")"

    local subdirs=()
    if [ "$rpm_arch" == "noarch" ]; then
        subdirs=("$REPO_DIR/$distro_name/$distro_ver/x86_64" "$REPO_DIR/$distro_name/$distro_ver/aarch64")
    else
        subdirs=("$REPO_DIR/$distro_name/$distro_ver/$rpm_arch")
    fi

    for d in "${subdirs[@]}"; do
        mkdir -p "$d"
        echo "Copying $rpm_fname to $d/..."
        cp -f "$rpm_path" "$d/"
        clean_old_rpms "$d"
    done
}

LATEST_EL_RPM=$(ls -t "$SCRIPT_DIR"/antigravity-ide-*el*.rpm 2>/dev/null | head -n 1)
LATEST_FC_RPM=$(ls -t "$SCRIPT_DIR"/antigravity-ide-*fc*.rpm 2>/dev/null | head -n 1)

if [[ "$TARGET" == "all" ]]; then
    echo "Publishing Antigravity IDE across all supported distributions..."
    if [ -n "$LATEST_EL_RPM" ] && [ -f "$LATEST_EL_RPM" ]; then
        echo "Found Enterprise Linux RPM: $(basename "$LATEST_EL_RPM")"
        deploy_package "$LATEST_EL_RPM" "rocky" "10"
        deploy_package "$LATEST_EL_RPM" "almalinux" "10"
    else
        echo "Warning: No Enterprise Linux 10 RPM found in $SCRIPT_DIR."
    fi

    if [ -n "$LATEST_FC_RPM" ] && [ -f "$LATEST_FC_RPM" ]; then
        echo "Found Fedora RPM: $(basename "$LATEST_FC_RPM")"
        deploy_package "$LATEST_FC_RPM" "fedora" "44"
    else
        echo "Warning: No Fedora RPM found in $SCRIPT_DIR."
    fi
elif [[ "$TARGET" == "fedora" ]]; then
    if [ -z "$LATEST_FC_RPM" ]; then
        echo "Error: No Fedora RPM found in $SCRIPT_DIR."
        exit 1
    fi
    deploy_package "$LATEST_FC_RPM" "fedora" "44"
elif [[ "$TARGET" == "almalinux" ]]; then
    if [ -z "$LATEST_EL_RPM" ]; then
        echo "Error: No Enterprise Linux RPM found in $SCRIPT_DIR."
        exit 1
    fi
    deploy_package "$LATEST_EL_RPM" "almalinux" "10"
elif [[ "$TARGET" == "rocky" ]]; then
    if [ -z "$LATEST_EL_RPM" ]; then
        echo "Error: No Enterprise Linux RPM found in $SCRIPT_DIR."
        exit 1
    fi
    deploy_package "$LATEST_EL_RPM" "rocky" "10"
fi

# Clean up legacy antigravity (non-ide) builds across the repository
find "$REPO_DIR" -type f -name "antigravity-[0-9]*.rpm" -delete 2>/dev/null || true


# Run the repository update script (which signs, rebuilds metadata, commits and pushes)
if [ -f "$SCRIPT_DIR/../wheelhouserllc-repo-scripts/update_repo.sh" ]; then
    echo "Running ../wheelhouserllc-repo-scripts/update_repo.sh on $REPO_DIR..."
    "$SCRIPT_DIR/../wheelhouserllc-repo-scripts/update_repo.sh" "$REPO_DIR"
elif [ -f "$SCRIPT_DIR/../scripts/update_repo.sh" ]; then
    echo "Running ../scripts/update_repo.sh on $REPO_DIR..."
    "$SCRIPT_DIR/../scripts/update_repo.sh" "$REPO_DIR"
elif [ -f "$REPO_DIR/scripts/update_repo.sh" ]; then
    echo "Running scripts/update_repo.sh in $REPO_DIR..."
    "$REPO_DIR/scripts/update_repo.sh"
elif [ -f "$REPO_DIR/update_repo.sh" ]; then
    echo "Running update_repo.sh in $REPO_DIR..."
    (cd "$REPO_DIR" && ./update_repo.sh)
else
    echo "Error: update_repo.sh not found (checked ../wheelhouserllc-repo-scripts/update_repo.sh and $REPO_DIR)"
    exit 1
fi

echo "Publishing complete!"

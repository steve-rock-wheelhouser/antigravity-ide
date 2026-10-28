#!/usr/bin/bash
# ==============================================================================
# antigravity-ide - Linux Launcher & Lifecycle Manager for Google Antigravity IDE
#
# Maintained by Wheelhouser LLC <steve.rock@wheelhouser.com>
# Licensed under GNU General Public License v3 (GPL-3.0-or-later)
# ==============================================================================
set -e

WRAPPER_VERSION="1.1.0"

# Remote payload endpoints
GOOGLE_DOWNLOAD_PORTAL="https://antigravity.google/download"
DEFAULT_GOOGLE_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.6.0-5526304964083712/linux-x64/Antigravity%20IDE.tar.gz"
STAGING_URL_PRIMARY="https://staging.wheelhouser.com/downloads/antigravity-ide/Antigravity-IDE.tar.gz"
STAGING_URL_FALLBACK="http://10.0.0.166/downloads/antigravity-ide/Antigravity-IDE.tar.gz"

# Dynamically resolve latest upstream payload URL from official Google portal
resolve_latest_google_url() {
    local discovered_url=""
    discovered_url=$(curl -sL -m 5 "$GOOGLE_DOWNLOAD_PORTAL" 2>/dev/null | grep -o 'https://edgedl\.me\.gvt1\.com/edgedl/release2/[^"'\'' ]*linux-x64/Antigravity%20IDE\.tar\.gz' | head -n 1 || true)
    if [ -n "$discovered_url" ]; then
        echo "$discovered_url"
    else
        echo "$DEFAULT_GOOGLE_URL"
    fi
}

# Resolve installation directory
resolve_target_dir() {
    if [ -n "${ANTIGRAVITY_INSTALL_DIR:-}" ]; then
        echo "$ANTIGRAVITY_INSTALL_DIR"
        return
    fi
    if [ -d "/usr/share/antigravity-ide" ] && { [ -f "/usr/share/antigravity-ide/chrome-sandbox" ] || [ -f "/usr/share/antigravity-ide/bin/antigravity-ide" ]; }; then
        echo "/usr/share/antigravity-ide"
    elif [ -d "$HOME/.local/share/antigravity-ide" ] && { [ -f "$HOME/.local/share/antigravity-ide/chrome-sandbox" ] || [ -f "$HOME/.local/share/antigravity-ide/bin/antigravity-ide" ]; }; then
        echo "$HOME/.local/share/antigravity-ide"
    else
        if [ "$(id -u)" -eq 0 ] || [ -w "/usr/share" ]; then
            echo "/usr/share/antigravity-ide"
        else
            echo "$HOME/.local/share/antigravity-ide"
        fi
    fi
}

# Extract core version string from product.json, package.json, or binary
get_core_version() {
    local target_dir="$1"
    local ver=""
    if [ -f "$target_dir/resources/app/product.json" ]; then
        ver=$(sed -n 's/.*"ideVersion"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$target_dir/resources/app/product.json" 2>/dev/null | head -n 1 || true)
    fi
    if [ -z "$ver" ] && [ -f "$target_dir/resources/app/package.json" ]; then
        ver=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$target_dir/resources/app/package.json" 2>/dev/null | head -n 1 || true)
    fi
    if [ -z "$ver" ] && [ -x "$target_dir/bin/antigravity-ide" ]; then
        ver=$("$target_dir/bin/antigravity-ide" --version 2>/dev/null | head -n 1 || true)
    fi
    echo "${ver:-unknown}"
}

print_wrapper_help() {
    cat <<EOF
Google Antigravity IDE - Linux Launcher & Manager (v${WRAPPER_VERSION})
Usage: antigravity-ide [launcher-options] [editor-arguments]

Launcher Management Commands:
  --update, -u [path|url]     Update or reinstall the Google Antigravity IDE core payload.
                              Optionally pass a local archive path or direct download URL.
  --check-update              Check installed core version against latest available payload.
  --wrapper-version           Display the Wheelhouser Linux launcher wrapper version.
  --help-launcher             Display this launcher wrapper help menu.

Editor Launch Options:
  Pass standard IDE options, files, or folders to launch Antigravity IDE.
  Run 'antigravity-ide --help' to see upstream editor arguments.

EOF
}

check_running_processes() {
    local target_dir="$1"
    local force_flag="${2:-false}"
    local running_pids=""
    if [ -d "$target_dir" ]; then
        running_pids=$(pgrep -f "${target_dir}" 2>/dev/null | grep -v "^$$$" || true)
    fi
    if [ -n "$running_pids" ]; then
        echo "⚠️  Warning: Active processes detected running from ${target_dir} (PIDs: $(echo "$running_pids" | tr '\n' ' '))"
        echo "   Modifying active binaries while running may cause application instability."
        if [ "$force_flag" = true ]; then
            echo "   Terminating running processes (--force)..."
            pkill -f "${target_dir}" 2>/dev/null || true
            sleep 1
        elif [ -t 0 ]; then
            local ans="n"
            read -t 10 -rp "   Terminate running instances now? [y/N]: " ans || ans="n"
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                echo "   Terminating running Antigravity IDE processes..."
                pkill -f "${target_dir}" 2>/dev/null || true
                sleep 1
            fi
        else
            echo "   Continuing update in non-interactive environment..."
        fi
    fi
}

do_check_update() {
    local target_dir
    target_dir=$(resolve_target_dir)
    echo "========================================================================"
    echo "🔍 Antigravity IDE Core Version Check"
    echo "========================================================================"
    echo "Launcher Wrapper Version : v${WRAPPER_VERSION}"
    echo "Installation Directory   : ${target_dir}"
    
    if [ ! -d "$target_dir" ] || [ ! -f "$target_dir/chrome-sandbox" ]; then
        echo "Status                   : No core payload installed (first-run initialization required)"
        exit 0
    fi

    local current_ver
    current_ver=$(get_core_version "$target_dir")
    echo "Installed Core Version   : v${current_ver}"

    echo "Checking Google CDN release channel..."
    local google_url
    google_url=$(resolve_latest_google_url)
    local upstream_ver
    upstream_ver=$(echo "$google_url" | sed -n 's|.*/stable/\([^/-]*\)[^/]*/linux-x64/.*|\1|p')

    local http_headers
    http_headers=$(curl -sI -4 -m 5 "$google_url" 2>/dev/null || true)
    if echo "$http_headers" | grep -qiE "HTTP/.* 200"; then
        local last_mod
        last_mod=$(echo "$http_headers" | grep -i "^last-modified:" | cut -d: -f2- | xargs || true)
        echo "Upstream Core Version    : v${upstream_ver:-unknown} (Last Modified: ${last_mod:-N/A})"
        echo "Upstream Channel Status  : Available"
        if [ -n "$upstream_ver" ] && [ "$current_ver" != "$upstream_ver" ]; then
            echo "Update Status            : ⚠️  Update available (v${current_ver} -> v${upstream_ver})"
        else
            echo "Update Status            : Core payload is up to date"
        fi
    else
        echo "Upstream Channel Status  : Remote check unreachable or cached"
    fi
    echo "========================================================================"
    echo "To update to the latest payload, run: antigravity-ide --update"
    exit 0
}

do_update() {
    local custom_source=""
    local force_flag=false

    # Parse arguments for do_update
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force|-y)
                force_flag=true
                shift
                ;;
            *)
                if [ -z "$custom_source" ]; then
                    custom_source="$1"
                fi
                shift
                ;;
        esac
    done

    local target_dir
    target_dir=$(resolve_target_dir)

    echo "========================================================================"
    echo "🚀 Antigravity IDE: Core Payload Updater"
    echo "========================================================================"
    echo "Target Installation: ${target_dir}"

    # Privilege elevation check for system-wide updates
    if [ "$target_dir" = "/usr/share/antigravity-ide" ] || [[ "$target_dir" =~ ^/usr/ ]]; then
        if [ "$(id -u)" -ne 0 ]; then
            if command -v sudo >/dev/null 2>&1; then
                echo "System installation update requires administrator privileges."
                echo "Re-executing with sudo..."
                exec sudo "$0" "$@"
            else
                echo "❌ Error: Updating system installation ($target_dir) requires root privileges." >&2
                echo "Please run: sudo antigravity-ide --update" >&2
                exit 1
            fi
        fi
    fi

    check_running_processes "$target_dir" "$force_flag"

    local current_ver="none"
    if [ -d "$target_dir" ]; then
        current_ver=$(get_core_version "$target_dir")
    fi
    echo "Current Installed Version: v${current_ver}"

    # Resolve staging directory: ensure at least 2.5GB free space, fallback to /var/tmp if /tmp lacks space
    local tmp_base="${TMPDIR:-/tmp}"
    local free_kb
    free_kb=$(df -k "$tmp_base" 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -n "$free_kb" ] && [ "$free_kb" -lt 2621440 ] && [ -d "/var/tmp" ] && [ -w "/var/tmp" ]; then
        tmp_base="/var/tmp"
    fi

    # Clean up stale orphaned update temp dirs from previous runs if running with root permissions
    if [ "$(id -u)" -eq 0 ]; then
        find /tmp /var/tmp -maxdepth 1 -name "antigravity-update-*" -type d -mmin +5 -exec rm -rf {} + 2>/dev/null || true
    fi

    local temp_dir
    temp_dir=$(mktemp -d -p "$tmp_base" antigravity-update-XXXXXX)
    trap 'rm -rf "$temp_dir"' EXIT INT TERM HUP

    local archive="$temp_dir/Antigravity-IDE.tar.gz"
    local acquired=false

    # 1. Check user-specified custom source (file or URL)
    if [ -n "$custom_source" ]; then
        if [[ "$custom_source" =~ ^https?:// ]]; then
            echo "📥 Fetching payload from custom URL: $custom_source"
            if curl -4 -sSL --retry 3 --retry-delay 2 -o "$archive" "$custom_source" && [ -f "$archive" ] && gzip -t "$archive" 2>/dev/null; then
                acquired=true
            else
                echo "❌ Error: Failed to download valid tarball from custom URL: $custom_source" >&2
                exit 1
            fi
        elif [ -f "$custom_source" ]; then
            echo "📦 Using local payload archive: $custom_source"
            if gzip -t "$custom_source" 2>/dev/null; then
                cp -f "$custom_source" "$archive"
                acquired=true
            else
                echo "❌ Error: Specified file is not a valid gzip tarball: $custom_source" >&2
                exit 1
            fi
        else
            echo "❌ Error: Custom source path or URL not found: $custom_source" >&2
            exit 1
        fi
    fi

    # 2. Check local download caches if not already acquired
    if [ "$acquired" = false ]; then
        for candidate in \
            "$HOME/Downloads/Antigravity IDE.tar.gz" \
            "$HOME/Downloads/Antigravity-IDE.tar.gz" \
            /root/Downloads/"Antigravity IDE.tar.gz" \
            /root/Downloads/"Antigravity-IDE.tar.gz" \
            /home/*/Downloads/"Antigravity IDE.tar.gz" \
            /home/*/Downloads/"Antigravity-IDE.tar.gz"; do
            if [ -f "$candidate" ] && gzip -t "$candidate" 2>/dev/null; then
                echo "✅ Found valid cached payload at $candidate"
                cp -f "$candidate" "$archive"
                acquired=true
                break
            fi
        done
    fi

    # 3. Check Staging Hub & Official CDN
    if [ "$acquired" = false ]; then
        echo "Checking local staging hubs..."
        if curl -s -f -m 3 --connect-timeout 2 -o "$archive" "$STAGING_URL_PRIMARY" 2>/dev/null && [ -f "$archive" ] && gzip -t "$archive" 2>/dev/null; then
            echo "✅ Downloaded payload from Wheelhouser Staging Hub (staging.wheelhouser.com)"
            acquired=true
        elif curl -s -f -m 3 --connect-timeout 2 -o "$archive" "$STAGING_URL_FALLBACK" 2>/dev/null && [ -f "$archive" ] && gzip -t "$archive" 2>/dev/null; then
            echo "✅ Downloaded payload from Wheelhouser Staging Hub (10.0.0.166)"
            acquired=true
        else
            rm -f "$archive"
            echo "📥 Resolving latest payload from Google CDN..."
            local google_url
            google_url=$(resolve_latest_google_url)
            echo "   Source URL: $google_url"
            if curl -4 -sSL --retry 3 --retry-delay 2 -o "$archive" "$google_url" && [ -f "$archive" ] && gzip -t "$archive" 2>/dev/null; then
                echo "✅ Downloaded payload from Google CDN"
                acquired=true
            fi
        fi
    fi

    if [ "$acquired" = false ]; then
        local current_free_kb
        current_free_kb=$(df -k "$temp_dir" 2>/dev/null | awk 'NR==2 {print $4}')
        if [ -n "$current_free_kb" ] && [ "$current_free_kb" -lt 524288 ]; then
            echo "❌ Error: Insufficient disk space in $(dirname "$temp_dir") (${current_free_kb}KB available, ~2.5GB required)." >&2
        else
            echo "❌ Error: Failed to acquire valid Antigravity IDE payload archive." >&2
        fi
        exit 1
    fi

    # Extract to sandbox temp directory to verify contents before touching target
    echo "📦 Extracting payload archive for verification..."
    local extract_dir="$temp_dir/extracted"
    mkdir -p "$extract_dir"
    tar -xzf "$archive" -C "$extract_dir"

    local sandbox_file
    sandbox_file=$(find "$extract_dir" -name "chrome-sandbox" -type f | head -n 1)
    if [ -z "$sandbox_file" ]; then
        echo "❌ Error: Corrupted payload: chrome-sandbox not found in archive." >&2
        exit 1
    fi

    local source_dir
    source_dir=$(dirname "$sandbox_file")
    local new_ver
    new_ver=$(get_core_version "$source_dir")
    echo "✨ Validated incoming payload: Version v${new_ver}"

    # Perform atomic backup & update
    echo "⚙️  Applying update to ${target_dir}..."
    mkdir -p "$target_dir"
    local backup_dir="$temp_dir/backup"
    mkdir -p "$backup_dir"

    # Backup existing installation if non-empty
    if [ -d "$target_dir" ] && [ "$(ls -A "$target_dir" 2>/dev/null)" ]; then
        cp -a "$target_dir/." "$backup_dir/"
    fi

    # Wipe and copy new payload
    rm -rf "$target_dir"/*
    if cp -a "$source_dir/." "$target_dir/"; then
        # Ensure correct file permissions
        chmod -R u+rwX,go+rX "$target_dir"
        chmod +x "$target_dir/antigravity-ide" 2>/dev/null || true
        chmod +x "$target_dir/bin/antigravity-ide" 2>/dev/null || true

        # Set root SUID on chrome-sandbox (mandatory on Linux for Chromium sandbox isolation)
        if [ "$(id -u)" -eq 0 ] && [ -f "$target_dir/chrome-sandbox" ]; then
            chown root:root "$target_dir/chrome-sandbox"
            chmod 4755 "$target_dir/chrome-sandbox"
        fi

        # Update desktop database if available
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database /usr/share/applications 2>/dev/null || true
            update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
        fi

        echo "========================================================================"
        echo "✅ Antigravity IDE Core successfully updated: v${current_ver} -> v${new_ver}"
        echo "📍 Installed in: ${target_dir}"
        echo "========================================================================"
    else
        echo "❌ Error: Failed to copy payload into $target_dir! Rolling back..." >&2
        rm -rf "$target_dir"/*
        if [ "$(ls -A "$backup_dir" 2>/dev/null)" ]; then
            cp -a "$backup_dir/." "$target_dir/"
        fi
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# CLI Argument Dispatcher
# ------------------------------------------------------------------------------
case "${1:-}" in
    --update|-u)
        shift
        do_update "$@"
        exit 0
        ;;
    --check-update)
        do_check_update
        ;;
    --wrapper-version)
        echo "Antigravity IDE Launcher (Wheelhouser packaging): v${WRAPPER_VERSION}"
        target_dir=$(resolve_target_dir)
        if [ -d "$target_dir" ] && [ -f "$target_dir/chrome-sandbox" ]; then
            echo "Installed Google IDE Core: v$(get_core_version "$target_dir") ($target_dir)"
        else
            echo "Installed Google IDE Core: not installed"
        fi
        exit 0
        ;;
    --help-launcher)
        print_wrapper_help
        exit 0
        ;;
    --help|-h)
        # If user asks for help, show brief wrapper note then delegate to core binary if present
        target_dir=$(resolve_target_dir)
        if [ -x "$target_dir/bin/antigravity-ide" ]; then
            echo "Note: Use 'antigravity-ide --update' to update Google IDE core payload."
            echo ""
            exec "$target_dir/bin/antigravity-ide" "$@"
        else
            print_wrapper_help
            exit 0
        fi
        ;;
esac

# ------------------------------------------------------------------------------
# Launch Installed IDE Payload
# ------------------------------------------------------------------------------
# 1. System payload
if [ -x "/usr/share/antigravity-ide/bin/antigravity-ide" ]; then
    exec "/usr/share/antigravity-ide/bin/antigravity-ide" "$@"
elif [ -x "/usr/share/antigravity-ide/antigravity-ide" ]; then
    exec "/usr/share/antigravity-ide/antigravity-ide" "$@"
fi

# 2. User-local payload
if [ -x "$HOME/.local/share/antigravity-ide/bin/antigravity-ide" ]; then
    exec "$HOME/.local/share/antigravity-ide/bin/antigravity-ide" "$@"
elif [ -x "$HOME/.local/share/antigravity-ide/antigravity-ide" ]; then
    exec "$HOME/.local/share/antigravity-ide/antigravity-ide" "$@"
fi

# 3. Fallback: First-run payload deployment
echo "========================================================================"
echo "🚀 Antigravity IDE: First-Run Payload Initialization"
echo "========================================================================"
echo "Payload not found in system or user paths. Initializing payload..."
do_update
target_dir=$(resolve_target_dir)
if [ -x "$target_dir/bin/antigravity-ide" ]; then
    exec "$target_dir/bin/antigravity-ide" "$@"
elif [ -x "$target_dir/antigravity-ide" ]; then
    exec "$target_dir/antigravity-ide" "$@"
else
    echo "❌ Error: Failed to find executable binary after initialization." >&2
    exit 1
fi

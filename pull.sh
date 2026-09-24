#!/bin/bash
# Puller: robustly fetch and pull the current branch

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./pull.sh [-f]

Options:
  -f    Force sync from origin/<current-branch> and overwrite local files.
        Preserves local version values in antigravity-ide.spec.
EOF
}

FORCE_SYNC=false
while getopts ":fh" opt; do
    case "${opt}" in
        f)
            FORCE_SYNC=true
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            echo "❌ Unknown option: -${OPTARG}" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Ensure script runs from its own directory (the repo root where the script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "📥 Fetching latest changes from remotes..."
git fetch --all --prune || echo "⚠️ git fetch had problems; continuing..."

# Determine current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $BRANCH"

REMOTE="origin"
echo "🔍 Checking for origin/$BRANCH..."
if git rev-parse --verify --quiet refs/remotes/$REMOTE/$BRANCH >/dev/null; then
    echo "Found remote branch $REMOTE/$BRANCH"
else
    echo "⚠️ $REMOTE/$BRANCH not found; attempting pull from $REMOTE/$BRANCH anyway."
fi

if [[ "${FORCE_SYNC}" == true ]]; then
    echo "💥 Force mode enabled. Overwriting local checkout from $REMOTE/$BRANCH..."
    git reset --hard "$REMOTE/$BRANCH"
    git clean -fdx
    echo "✅ Force sync complete. Local checkout now matches $REMOTE/$BRANCH."
    exit 0
fi

echo "🔄 Pulling updates from $REMOTE/$BRANCH..."
# Try fast-forward only first to avoid unintended merges
if git pull --ff-only "$REMOTE" "$BRANCH" 2>/dev/null; then
    echo "✅ Successfully fast-forwarded to the latest version!"
    exit 0
fi

# If fast-forward failed, attempt a regular pull and surface errors
if git pull "$REMOTE" "$BRANCH"; then
    echo "✅ Successfully updated to the latest version!"
else
    echo "❌ Error: Pull failed. You may have local conflicts or the remote branch differs."
    exit 1
fi

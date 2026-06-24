#!/usr/bin/env bash
#
# push.sh
# Stages local changes, commits if needed, and pushes the current branch to GitHub.
# Use -f/--force to overwrite remote branch.
# Use --force-with-lease for safer overwrite behavior.
#

clear

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
FORCE_PUSH=false
FORCE_WITH_LEASE=false
COMMIT_MSG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force)
            FORCE_PUSH=true
            shift
            ;;
        --force-with-lease)
            FORCE_WITH_LEASE=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./push.sh [-f|--force|--force-with-lease] [commit message]"
            echo
            echo "Examples:"
            echo "  ./push.sh"
            echo "  ./push.sh \"Fix slideshow startup\""
            echo "  ./push.sh -f \"Overwrite remote with local main\""
            echo "  ./push.sh --force-with-lease \"Safer overwrite with lease\""
            exit 0
            ;;
        *)
            if [[ -n "${COMMIT_MSG}" ]]; then
                COMMIT_MSG+=" "
            fi
            COMMIT_MSG+="$1"
            shift
            ;;
    esac
done

if [[ -z "${COMMIT_MSG}" ]]; then
    MESSAGE="Update: $(date +'%Y-%m-%d %H:%M:%S')"
else
    MESSAGE="${COMMIT_MSG}"
fi

echo "Staging changes..."
git add -A

if git diff --cached --quiet; then
    echo "No staged changes to commit."
else
    echo "Committing changes: ${MESSAGE}"
    git commit -m "${MESSAGE}"
fi

echo "Pushing branch '${BRANCH}' to GitHub..."
if [[ "${FORCE_PUSH}" == true && "${FORCE_WITH_LEASE}" == true ]]; then
    echo "Error: choose either --force or --force-with-lease, not both."
    exit 1
elif [[ "${FORCE_PUSH}" == true ]]; then
    echo "Override enabled: using --force"
    git push --force origin "${BRANCH}"
elif [[ "${FORCE_WITH_LEASE}" == true ]]; then
    echo "Override enabled: using --force-with-lease"
    # Refresh remote-tracking refs so lease info is current.
    git fetch origin "${BRANCH}"
    REMOTE_REF="refs/heads/${BRANCH}"
    REMOTE_OID="$(git rev-parse "origin/${BRANCH}")"

    # Use explicit lease against the fetched remote OID.
    if ! git push --force-with-lease="${REMOTE_REF}:${REMOTE_OID}" origin "${BRANCH}"; then
        echo "Force-with-lease rejected (remote moved). Refreshing lease and retrying once..."
        git fetch origin "${BRANCH}"
        REMOTE_OID="$(git rev-parse "origin/${BRANCH}")"
        git push --force-with-lease="${REMOTE_REF}:${REMOTE_OID}" origin "${BRANCH}"
    fi
else
    if git rev-parse --abbrev-ref --symbolic-full-name "${BRANCH}@{upstream}" >/dev/null 2>&1; then
        git push origin "${BRANCH}"
    else
        git push -u origin "${BRANCH}"
    fi
fi

echo "Push complete."

#!/bin/bash
set -euo pipefail

# Autodetect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID:-}"
else
    DISTRO_ID="fedora"
fi

if [[ "$DISTRO_ID" =~ ^(rocky|rhel|centos|almalinux)$ ]]; then
    REPO_FILE="rocky.repo"
else
    REPO_FILE="fedora.repo"
fi

sudo curl -sL "https://raw.githubusercontent.com/steve-rock-wheelhouser/wheelhouserllc-repo/main/${REPO_FILE}" -o /etc/yum.repos.d/wheelhouser.repo

#!/usr/bin/env bash
# 35-gh.sh — install GitHub CLI (gh) via the official cli.github.com apt repository.

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

DRY_RUN="${LAB_SOE_DRY_RUN:-0}"

KEYRING="/etc/apt/keyrings/githubcli-archive-keyring.gpg"
SOURCES="/etc/apt/sources.list.d/github-cli.list"

if have_cmd gh; then
    log_info "gh: ok, skipping ($(gh --version | head -1))"
    exit 0
fi

if [ "$DRY_RUN" = "1" ]; then
    log_info "would install gh via cli.github.com apt repo"
    exit 0
fi

log_info "installing gh via cli.github.com apt repo"

sudo mkdir -p -m 755 /etc/apt/keyrings

if [ ! -f "$KEYRING" ]; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of="$KEYRING" status=none
    sudo chmod go+r "$KEYRING"
fi

if [ ! -f "$SOURCES" ]; then
    echo "deb [arch=$(dpkg --print-architecture) signed-by=${KEYRING}] https://cli.github.com/packages stable main" \
        | sudo tee "$SOURCES" >/dev/null
fi

sudo apt-get update -qq
sudo apt-get install -y gh

log_info "gh: ok ($(gh --version | head -1))"

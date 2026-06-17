#!/usr/bin/env bash
# 15-node.sh — install Node.js 20 LTS via NodeSource if missing or < 20.

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

NODE_MIN_VERSION="20.0.0"
DRY_RUN="${LAB_SOE_DRY_RUN:-0}"

current_node_version() {
    local v
    if have_cmd node && v=$(node --version 2>/dev/null); then
        printf '%s\n' "${v#v}"
    else
        echo ""
    fi
}

install_node_20() {
    if [ "$DRY_RUN" = "1" ]; then
        log_info "would install Node 20 LTS via NodeSource"
        return 0
    fi
    log_info "installing Node 20 LTS via NodeSource"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get update
    sudo apt-get install -y nodejs
}

current="$(current_node_version)"

if [ -n "$current" ] && version_at_least "$current" "$NODE_MIN_VERSION"; then
    log_info "node v${current}: ok, skipping"
    if ! have_cmd npm || ! have_cmd npx; then
        log_error "node is present but npm/npx are missing; reinstall nodejs package"
        exit 1
    fi
    exit 0
fi

install_node_20

# Verify post-install (skipped in dry-run).
if [ "$DRY_RUN" != "1" ]; then
    have_cmd node || { log_error "node not on PATH after install"; exit 1; }
    have_cmd npm  || { log_error "npm not on PATH after install"; exit 1; }
    have_cmd npx  || { log_error "npx not on PATH after install"; exit 1; }
    log_info "node $(node --version 2>/dev/null || echo '?'): installed"
fi

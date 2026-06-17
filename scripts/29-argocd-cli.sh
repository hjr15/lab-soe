#!/usr/bin/env bash
# 29-argocd-cli.sh — install the Argo CD CLI (host-side tool only; the
# Argo CD server itself runs in its own product cluster).
#
# Pinned to LAB_SOE_ARGOCD_VERSION (default v3.3.8) to match the Helm chart
# version deployed in-cluster (argo-cd 9.5.10 → app v3.3.8).
# Override with: LAB_SOE_ARGOCD_VERSION=vX.Y.Z ./bootstrap.sh

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

DRY_RUN="${LAB_SOE_DRY_RUN:-0}"
ARGOCD_VERSION="${LAB_SOE_ARGOCD_VERSION:-v3.3.8}"

current_argocd_version() {
    local v
    if have_cmd argocd && v=$(argocd version --client 2>/dev/null | grep -m1 -oE 'v[0-9]+\.[0-9]+\.[0-9]+'); then
        printf '%s\n' "$v"
    else
        echo ""
    fi
}

install_argocd_cli() {
    local current desired="$ARGOCD_VERSION"
    current=$(current_argocd_version)
    if [ -n "$current" ]; then
        if [ "$current" = "$desired" ]; then
            log_info "argocd ${desired}: ok, skipping"
            return 0
        fi
        log_warn "argocd ${current} installed but ${desired} requested; leaving as-is (rm /usr/local/bin/argocd and re-run to switch)"
        return 0
    fi
    if [ "$DRY_RUN" = "1" ]; then
        log_info "would install argocd ${desired} from GitHub releases"
        return 0
    fi
    log_info "installing argocd ${desired} from GitHub releases"
    local tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN
    curl -fsSL -o "$tmp/argocd" \
        "https://github.com/argoproj/argo-cd/releases/download/${desired}/argocd-linux-amd64"
    sudo install -m 0555 "$tmp/argocd" /usr/local/bin/argocd
    log_info "argocd ${desired}: installed"
}

install_argocd_cli

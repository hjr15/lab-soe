#!/usr/bin/env bash
# 25-k9s.sh — install k9s (terminal UI for Kubernetes).
# k9s has no Debian/Ubuntu apt repository, so we fetch the latest release
# tarball from GitHub. Uses jq, which 20-k8s-tools.sh installs first.

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

DRY_RUN="${LAB_SOE_DRY_RUN:-0}"

install_k9s() {
    if have_cmd k9s; then
        log_info "k9s: ok, skipping"
        return 0
    fi
    if [ "$DRY_RUN" = "1" ]; then
        log_info "would install k9s from GitHub releases"
        return 0
    fi
    log_info "installing k9s from GitHub releases"
    if ! have_cmd jq; then
        log_error "jq not found; 20-k8s-tools.sh must run first"
        return 1
    fi
    local version tmp
    version=$(curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest | jq -r .tag_name)
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        log_error "could not resolve latest k9s version from GitHub"
        return 1
    fi
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN
    curl -fsSL -o "$tmp/k9s.tar.gz" \
        "https://github.com/derailed/k9s/releases/download/${version}/k9s_Linux_amd64.tar.gz"
    tar -xzf "$tmp/k9s.tar.gz" -C "$tmp"
    sudo install -m 0755 "$tmp/k9s" /usr/local/bin/k9s
    log_info "k9s ${version}: installed"
}

install_k9s

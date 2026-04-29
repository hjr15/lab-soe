#!/usr/bin/env bash
# 20-k8s-tools.sh — install local k8s dev tools: k3d, kubectl, helm, kubectx,
# kubens, jq. Each tool is independently presence-checked and skipped if found.

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

DRY_RUN="${LAB_SOE_DRY_RUN:-0}"

run_or_say() {
    if [ "$DRY_RUN" = "1" ]; then
        log_info "would run: $*"
    else
        "$@"
    fi
}

# --- jq ---------------------------------------------------------------------

install_jq() {
    if have_cmd jq; then
        log_info "jq: ok, skipping"
        return 0
    fi
    log_info "would install jq via apt"
    run_or_say sudo apt-get install -y jq
}

# --- kubectx (provides both kubectx and kubens) -----------------------------

install_kubectx() {
    if have_cmd kubectx && have_cmd kubens; then
        log_info "kubectx: ok, skipping"
        log_info "kubens: ok, skipping"
        return 0
    fi
    log_info "would install kubectx (provides kubens) via apt"
    run_or_say sudo apt-get install -y kubectx
}

# --- kubectl (Kubernetes apt repo) ------------------------------------------

install_kubectl() {
    if have_cmd kubectl; then
        log_info "kubectl: ok, skipping"
        return 0
    fi
    log_info "would install kubectl via Kubernetes apt repo"
    if [ "$DRY_RUN" = "1" ]; then return 0; fi
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
    sudo mkdir -p -m 755 /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
            | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    fi
    if [ ! -f /etc/apt/sources.list.d/kubernetes.list ]; then
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' \
            | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
    fi
    sudo apt-get update
    sudo apt-get install -y kubectl
}

# --- helm (Helm apt repo) ---------------------------------------------------

install_helm() {
    if have_cmd helm; then
        log_info "helm: ok, skipping"
        return 0
    fi
    log_info "would install helm via Helm apt repo"
    if [ "$DRY_RUN" = "1" ]; then return 0; fi
    if [ ! -f /etc/apt/keyrings/helm.gpg ]; then
        curl -fsSL https://baltocdn.com/helm/signing.asc \
            | sudo gpg --dearmor -o /etc/apt/keyrings/helm.gpg
    fi
    if [ ! -f /etc/apt/sources.list.d/helm-stable-debian.list ]; then
        echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main' \
            | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list >/dev/null
    fi
    sudo apt-get update
    sudo apt-get install -y helm
}

# --- k3d (official install script) ------------------------------------------

install_k3d() {
    if have_cmd k3d; then
        log_info "k3d: ok, skipping"
        return 0
    fi
    log_info "would install k3d via get.k3d.io"
    if [ "$DRY_RUN" = "1" ]; then return 0; fi
    curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
}

install_jq
install_kubectx
install_kubectl
install_helm
install_k3d

log_info "k8s tools: done"

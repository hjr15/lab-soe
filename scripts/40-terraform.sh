#!/usr/bin/env bash
# 40-terraform.sh — install Terraform via HashiCorp's official apt repo.

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

DRY_RUN="${LAB_SOE_DRY_RUN:-0}"

install_terraform() {
    if have_cmd terraform; then
        log_info "terraform: ok, skipping"
        return 0
    fi
    if [ "$DRY_RUN" = "1" ]; then
        log_info "would install terraform via HashiCorp apt repo"
        return 0
    fi
    log_info "installing terraform via HashiCorp apt repo"
    sudo mkdir -p -m 755 /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/hashicorp.gpg ]; then
        curl -fsSL https://apt.releases.hashicorp.com/gpg \
            | sudo gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
    fi
    if [ ! -f /etc/apt/sources.list.d/hashicorp.list ]; then
        local codename
        codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com ${codename} main" \
            | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
    fi
    sudo apt-get update
    sudo apt-get install -y terraform
}

install_terraform

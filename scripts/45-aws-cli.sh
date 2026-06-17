#!/usr/bin/env bash
# 45-aws-cli.sh — install AWS CLI v2 via the official bundled installer.
# AWS does not publish an apt source for CLI v2; the bundled installer is
# the upstream-recommended path. Always installs the latest published v2.

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

DRY_RUN="${LAB_SOE_DRY_RUN:-0}"

install_aws_cli() {
    if have_cmd aws; then
        log_info "aws-cli: ok, skipping"
        return 0
    fi
    if [ "$DRY_RUN" = "1" ]; then
        log_info "would install aws-cli v2 from awscli.amazonaws.com"
        return 0
    fi
    log_info "installing aws-cli v2 from awscli.amazonaws.com"
    if ! have_cmd unzip; then
        log_info "installing unzip (required by the AWS CLI installer)"
        sudo apt-get install -y unzip
    fi
    local tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN
    curl -fsSL -o "$tmp/awscliv2.zip" \
        "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    unzip -q "$tmp/awscliv2.zip" -d "$tmp"
    sudo "$tmp/aws/install"
    log_info "aws-cli $(aws --version 2>&1 | head -1): installed"
}

install_aws_cli

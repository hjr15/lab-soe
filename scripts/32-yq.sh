#!/usr/bin/env bash
# 32-yq.sh — install yq (YAML processor) from GitHub releases.
# mikefarah/yq publishes no apt package; direct binary download is the upstream-recommended method.

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

YQ_VERSION="4.44.3"
YQ_BIN="/usr/local/bin/yq"
DRY_RUN="${LAB_SOE_DRY_RUN:-0}"

if have_cmd yq; then
    log_info "yq: ok, skipping ($(yq --version 2>&1 | head -1))"
    exit 0
fi

if [ "$DRY_RUN" = "1" ]; then
    log_info "would install yq v${YQ_VERSION} to ${YQ_BIN}"
    exit 0
fi

log_info "installing yq v${YQ_VERSION}"

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  YQ_ARCH="amd64" ;;
    aarch64) YQ_ARCH="arm64" ;;
    *) log_error "unsupported architecture: $ARCH"; exit 1 ;;
esac

sudo curl -fsSL \
    "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${YQ_ARCH}" \
    -o "${YQ_BIN}"
sudo chmod +x "${YQ_BIN}"

log_info "yq: ok ($(yq --version 2>&1 | head -1))"

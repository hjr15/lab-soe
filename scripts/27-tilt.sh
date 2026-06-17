#!/usr/bin/env bash
# 27-tilt.sh — install Tilt (https://tilt.dev) for local k8s development.
# Tilt has no Debian/Ubuntu apt repository; the upstream install script is
# the recommended path and matches the same pattern we use for k3d.

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

DRY_RUN="${LAB_SOE_DRY_RUN:-0}"

install_tilt() {
    if have_cmd tilt; then
        log_info "tilt: ok, skipping"
        return 0
    fi
    if [ "$DRY_RUN" = "1" ]; then
        log_info "would install tilt via get.tilt.dev"
        return 0
    fi
    log_info "installing tilt via get.tilt.dev"
    curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash
}

install_tilt

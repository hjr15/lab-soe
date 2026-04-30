#!/usr/bin/env bash
# 10-docker.sh — verify Docker is installed, reachable, and usable.
# This script never installs Docker. See README for one-time install steps.

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

if ! have_cmd docker; then
    log_error "docker not found on PATH; install it first (see README)"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    log_error "'docker info' failed; the daemon may be down or your user may not have access"
    exit 1
fi

if ! id -nG | tr ' ' '\n' | grep -qx docker; then
    log_warn "your user is not in the 'docker' group; consider: sudo usermod -aG docker \$USER && newgrp docker"
fi

log_info "docker: ok"

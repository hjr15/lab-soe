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

_in_docker_group() { id -nG | tr ' ' '\n' | grep -qx docker; }

if ! docker info >/dev/null 2>&1; then
    if ! systemctl is-active --quiet docker 2>/dev/null; then
        log_info "docker daemon is not running; attempting 'sudo systemctl start docker'"
        if ! sudo systemctl start docker; then
            log_error "failed to start docker daemon; run: sudo systemctl start docker"
            exit 1
        fi
        if ! docker info >/dev/null 2>&1; then
            log_error "'docker info' still failed after starting daemon; your user may not have access"
            exit 1
        fi
    else
        if ! _in_docker_group; then
            log_info "user '$USER' not in docker group; adding via 'sudo usermod -aG docker $USER'"
            sudo usermod -aG docker "$USER"
            log_warn "added '$USER' to docker group"
            log_error "a new login session is required; run 'exec newgrp docker' or log out and back in, then re-run bootstrap"
            exit 1
        else
            # Docker Desktop installs a custom context pointing to ~/.docker/desktop/docker.sock.
            # When Desktop is absent that socket is gone; switch to the system default and retry.
            if docker context use default >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
                log_warn "switched docker context to 'default'; previous context pointed to an unavailable socket"
            else
                _docker_err=$(docker info 2>&1 | head -1 || true)
                log_error "'docker info' failed: ${_docker_err:-unknown error}"
                if [ -S /var/run/docker.sock ]; then
                    log_error "socket: $(ls -la /var/run/docker.sock)"
                else
                    log_error "socket /var/run/docker.sock not found"
                fi
                exit 1
            fi
        fi
    fi
fi

if ! _in_docker_group; then
    log_warn "your user is not in the 'docker' group; consider: sudo usermod -aG docker $USER && newgrp docker"
fi

log_info "docker: ok"

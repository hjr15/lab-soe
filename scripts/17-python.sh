#!/usr/bin/env bash
# 17-python.sh — ensure the host can create Python virtualenvs and install packages.
#
# Products own their own venv + requirements (e.g. docs-central's data lab);
# lab-soe only guarantees the host *capability*: a python3 whose `venv` module
# can bootstrap pip. On Ubuntu 24.04 a bare python3 ships without `ensurepip`,
# so `python3 -m venv .venv` fails with "ensurepip is not available" until
# python3-venv is installed — this script closes that gap.

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

DRY_RUN="${LAB_SOE_DRY_RUN:-0}"

# `ensurepip` importable == `python3 -m venv` can bootstrap pip into a new venv.
venv_capable() {
    have_cmd python3 && python3 -c 'import ensurepip' >/dev/null 2>&1
}

pip_capable() {
    have_cmd python3 && python3 -m pip --version >/dev/null 2>&1
}

install_python_venv() {
    if [ "$DRY_RUN" = "1" ]; then
        log_info "would install python3-venv + python3-pip via apt"
        return 0
    fi
    log_info "installing python3-venv + python3-pip via apt"
    sudo apt-get update
    sudo apt-get install -y python3-venv python3-pip
}

if ! have_cmd python3; then
    # python3 is part of the Ubuntu 24.04 base; if it is somehow absent that is a
    # broken host, not something this optional installer should paper over.
    log_error "python3 not on PATH — expected on the Ubuntu 24.04 base image"
    exit 1
fi

if venv_capable && pip_capable; then
    log_info "python3 $(python3 --version 2>/dev/null || echo '?'): venv + pip ok, skipping"
    exit 0
fi

install_python_venv

# Verify post-install (skipped in dry-run).
if [ "$DRY_RUN" != "1" ]; then
    venv_capable || { log_error "python3 -m venv still cannot bootstrap pip (ensurepip missing) after install"; exit 1; }
    pip_capable  || { log_error "python3 -m pip unavailable after install"; exit 1; }
    log_info "python3 $(python3 --version 2>/dev/null || echo '?'): venv + pip ready"
fi

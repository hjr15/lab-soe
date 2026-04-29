#!/usr/bin/env bash
# bootstrap.sh — entry point for the lab-soe SOE.
#
# Runs every scripts/[0-9][0-9]-*.sh in sorted order. Each script is
# idempotent and may be re-run safely. Add a new dependency by dropping
# a new numbered script in scripts/ — no edits needed here.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${ROOT}/scripts"

# shellcheck source=scripts/lib.sh
source "${SCRIPTS_DIR}/lib.sh"

require_ubuntu
load_secrets

shopt -s nullglob
mapfile -t INSTALLERS < <(printf '%s\n' "${SCRIPTS_DIR}"/[0-9][0-9]-*.sh | sort)

if [ "${#INSTALLERS[@]}" -eq 0 ]; then
    log_warn "no installer scripts found in ${SCRIPTS_DIR}"
    exit 0
fi

for script in "${INSTALLERS[@]}"; do
    log_info "==> running $(basename "$script")"
    if ! "$script"; then
        log_error "failed: $(basename "$script") (exit $?)"
        exit 1
    fi
done

log_info "lab-soe bootstrap complete"

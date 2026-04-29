#!/usr/bin/env bash
# Shared helpers for lab-soe installer scripts.
# Source from each script with: source "$(dirname "$0")/lib.sh"

# --- Logging ----------------------------------------------------------------

log_info()  { printf '[info] %s\n'  "$*" >&2; }
log_warn()  { printf '[warn] %s\n'  "$*" >&2; }
log_error() { printf '[error] %s\n' "$*" >&2; }

# --- Presence and version checks --------------------------------------------

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# version_at_least <current> <minimum>
# Exit 0 if current >= minimum (semver), 1 otherwise.
# Uses dpkg's version comparator (always present on Ubuntu).
version_at_least() {
    dpkg --compare-versions "$1" ge "$2"
}

# --- Platform gate ----------------------------------------------------------

# Aborts unless running on Ubuntu 24.04.
# Override the os-release path with LAB_SOE_OS_RELEASE for tests.
require_ubuntu() {
    local os_release="${LAB_SOE_OS_RELEASE:-/etc/os-release}"
    if [ ! -r "$os_release" ]; then
        log_error "cannot read $os_release"
        return 1
    fi
    # shellcheck disable=SC1090
    . "$os_release"
    if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "24.04" ]; then
        log_error "lab-soe targets Ubuntu 24.04; detected ID=${ID:-?} VERSION_ID=${VERSION_ID:-?}"
        return 1
    fi
    return 0
}

# --- Secrets ----------------------------------------------------------------

# Sources $LAB_SOE_SECRETS_FILE (default ~/.config/lab-soe/secrets.env).
# Logs a warning and returns 0 if the file is missing — installers that need
# a specific variable check for it themselves and skip cleanly.
load_secrets() {
    local secrets="${LAB_SOE_SECRETS_FILE:-${HOME}/.config/lab-soe/secrets.env}"
    if [ -r "$secrets" ]; then
        # shellcheck disable=SC1090
        . "$secrets"
        log_info "loaded secrets from $secrets"
    else
        log_warn "no secrets file at $secrets — steps that need secrets will be skipped"
    fi
}

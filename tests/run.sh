#!/usr/bin/env bash
# tests/run.sh — run bats with the vendored bats and shellcheck on PATH.
# Forwards all args to bats. Examples:
#   ./tests/run.sh tests/             # run all
#   ./tests/run.sh tests/test_lib.bats # run a single file

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS="${HERE}/.tools"

if [ ! -x "${TOOLS}/bats-core/bin/bats" ] || [ ! -x "${TOOLS}/shellcheck" ]; then
    echo "[run] tools missing — running setup first" >&2
    "${HERE}/setup.sh"
fi

export PATH="${TOOLS}:${TOOLS}/bats-core/bin:${PATH}"
exec bats "$@"

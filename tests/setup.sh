#!/usr/bin/env bash
# tests/setup.sh — vendor bats-core and shellcheck into tests/.tools/.
# Idempotent: skips anything already in place. No sudo required.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS="${HERE}/.tools"
BATS_VERSION="v1.11.0"
SHELLCHECK_VERSION="v0.10.0"

mkdir -p "${TOOLS}"

if [ ! -x "${TOOLS}/bats-core/bin/bats" ]; then
    echo "[setup] cloning bats-core ${BATS_VERSION}"
    git clone --depth=1 --branch "${BATS_VERSION}" \
        https://github.com/bats-core/bats-core.git "${TOOLS}/bats-core" >/dev/null
fi
echo "[setup] bats: $("${TOOLS}/bats-core/bin/bats" --version)"

if [ ! -x "${TOOLS}/shellcheck" ]; then
    echo "[setup] downloading shellcheck ${SHELLCHECK_VERSION}"
    tmp="$(mktemp -d)"
    curl -fsSL \
        -o "${tmp}/sc.tar.xz" \
        "https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_VERSION}/shellcheck-${SHELLCHECK_VERSION}.linux.x86_64.tar.xz"
    tar -xJf "${tmp}/sc.tar.xz" -C "${tmp}"
    mv "${tmp}/shellcheck-${SHELLCHECK_VERSION}/shellcheck" "${TOOLS}/shellcheck"
    rm -rf "${tmp}"
fi
echo "[setup] shellcheck: $("${TOOLS}/shellcheck" --version | sed -n '2p')"

echo "[setup] done"

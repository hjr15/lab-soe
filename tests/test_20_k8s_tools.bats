#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    SCRIPT="${REPO}/scripts/20-k8s-tools.sh"
    TMP="$(mktemp -d)"
    FAKEBIN="$TMP/bin"
    mkdir -p "$FAKEBIN"
}

teardown() {
    rm -rf "$TMP"
}

@test "20-k8s-tools.sh passes shellcheck" {
    shellcheck_script "$SCRIPT"
}

@test "20-k8s-tools.sh skips all installs when every tool is present" {
    for t in k3d kubectl helm kubectx kubens jq; do
        fake_bin "$FAKEBIN" "$t" 0
    done
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"k3d"* ]]
    [[ "$output" == *"kubectl"* ]]
    [[ "$output" == *"helm"* ]]
    [[ "$output" == *"kubectx"* ]]
    [[ "$output" == *"kubens"* ]]
    [[ "$output" == *"jq"* ]]
    # Skip path must not announce any installs.
    [[ "$output" != *"would install"* ]]
    [[ "$output" != *"installing"* ]]
}

@test "20-k8s-tools.sh in dry-run announces install when tools are missing" {
    LAB_SOE_DRY_RUN=1 PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would install"* ]]
    # Dry-run must not log the real-install prefix (e.g. "installing jq via apt").
    [[ "$output" != *"installing jq via apt"* ]]
    [[ "$output" != *"installing kubectl"* ]]
}

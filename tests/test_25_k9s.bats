#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    SCRIPT="${REPO}/scripts/25-k9s.sh"
    TMP="$(mktemp -d)"
    FAKEBIN="$TMP/bin"
    mkdir -p "$FAKEBIN"
}

teardown() {
    rm -rf "$TMP"
}

@test "25-k9s.sh passes shellcheck" {
    shellcheck_script "$SCRIPT"
}

@test "25-k9s.sh skips install when k9s is already present" {
    fake_bin "$FAKEBIN" k9s 0
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"k9s: ok, skipping"* ]]
    [[ "$output" != *"would install"* ]]
    [[ "$output" != *"installing"* ]]
}

@test "25-k9s.sh in dry-run announces install when k9s is missing" {
    isolate_path "$FAKEBIN"
    LAB_SOE_DRY_RUN=1 PATH="$FAKEBIN" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would install k9s"* ]]
}

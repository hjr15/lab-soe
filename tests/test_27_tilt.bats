#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    SCRIPT="${REPO}/scripts/27-tilt.sh"
    TMP="$(mktemp -d)"
    FAKEBIN="$TMP/bin"
    mkdir -p "$FAKEBIN"
}

teardown() {
    rm -rf "$TMP"
}

@test "27-tilt.sh passes shellcheck" {
    shellcheck_script "$SCRIPT"
}

@test "27-tilt.sh skips install when tilt is already present" {
    fake_bin "$FAKEBIN" tilt 0
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tilt: ok, skipping"* ]]
    [[ "$output" != *"would install"* ]]
    [[ "$output" != *"installing"* ]]
}

@test "27-tilt.sh in dry-run announces install when tilt is missing" {
    isolate_path "$FAKEBIN"
    LAB_SOE_DRY_RUN=1 PATH="$FAKEBIN" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would install tilt"* ]]
}

#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    SCRIPT="${REPO}/scripts/45-aws-cli.sh"
    TMP="$(mktemp -d)"
    FAKEBIN="$TMP/bin"
    mkdir -p "$FAKEBIN"
}

teardown() {
    rm -rf "$TMP"
}

@test "45-aws-cli.sh passes shellcheck" {
    shellcheck_script "$SCRIPT"
}

@test "45-aws-cli.sh skips install when aws is already present" {
    fake_bin "$FAKEBIN" aws 0
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"aws-cli: ok, skipping"* ]]
    [[ "$output" != *"would install"* ]]
    [[ "$output" != *"installing"* ]]
}

@test "45-aws-cli.sh in dry-run announces install when aws is missing" {
    isolate_path "$FAKEBIN"
    LAB_SOE_DRY_RUN=1 PATH="$FAKEBIN" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would install aws-cli"* ]]
}

#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    SCRIPT="${REPO}/scripts/40-terraform.sh"
    TMP="$(mktemp -d)"
    FAKEBIN="$TMP/bin"
    mkdir -p "$FAKEBIN"
}

teardown() {
    rm -rf "$TMP"
}

@test "40-terraform.sh passes shellcheck" {
    shellcheck_script "$SCRIPT"
}

@test "40-terraform.sh skips install when terraform is already present" {
    fake_bin "$FAKEBIN" terraform 0
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"terraform: ok, skipping"* ]]
    [[ "$output" != *"would install"* ]]
    [[ "$output" != *"installing"* ]]
}

@test "40-terraform.sh in dry-run announces install when terraform is missing" {
    isolate_path "$FAKEBIN"
    LAB_SOE_DRY_RUN=1 PATH="$FAKEBIN" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would install terraform"* ]]
}

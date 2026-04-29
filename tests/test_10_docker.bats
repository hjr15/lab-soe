#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    SCRIPT="${REPO}/scripts/10-docker.sh"
    TMP="$(mktemp -d)"
    FAKEBIN="$TMP/bin"
    mkdir -p "$FAKEBIN"
}

teardown() {
    rm -rf "$TMP"
}

@test "10-docker.sh passes shellcheck" {
    shellcheck_script "$SCRIPT"
}

@test "10-docker.sh succeeds when docker exists and 'docker info' returns 0" {
    fake_bin "$FAKEBIN" docker 0
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"docker"* ]]
}

@test "10-docker.sh fails when docker is missing from PATH" {
    for cmd in bash dirname id tr grep printf; do
        ln -sf "$(command -v "$cmd")" "$FAKEBIN/$cmd"
    done
    PATH="$FAKEBIN" run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"docker"* ]]
}

@test "10-docker.sh fails when docker exists but 'docker info' returns non-zero" {
    fake_bin "$FAKEBIN" docker 1
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -ne 0 ]
}

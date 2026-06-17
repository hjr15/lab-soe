#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    SCRIPT="${REPO}/scripts/32-yq.sh"
    TMP="$(mktemp -d)"
    FAKEBIN="$TMP/bin"
    mkdir -p "$FAKEBIN"
}

teardown() {
    rm -rf "$TMP"
}

@test "32-yq.sh passes shellcheck" {
    shellcheck_script "$SCRIPT"
}

@test "32-yq.sh skips install when yq is already present" {
    cat >"$FAKEBIN/yq" <<'YQ'
#!/usr/bin/env bash
printf 'yq (https://github.com/mikefarah/yq/) version v4.44.3\n'
YQ
    chmod +x "$FAKEBIN/yq"
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok, skipping"* ]]
}

@test "32-yq.sh reports install plan in dry-run when yq is missing" {
    isolate_path "$FAKEBIN"
    LAB_SOE_DRY_RUN=1 PATH="$FAKEBIN" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would install"* ]]
}

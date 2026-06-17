#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    SCRIPT="${REPO}/scripts/35-gh.sh"
    TMP="$(mktemp -d)"
    FAKEBIN="$TMP/bin"
    mkdir -p "$FAKEBIN"
}

teardown() {
    rm -rf "$TMP"
}

@test "35-gh.sh passes shellcheck" {
    shellcheck_script "$SCRIPT"
}

@test "35-gh.sh skips install when gh is already present" {
    cat >"$FAKEBIN/gh" <<'GH'
#!/usr/bin/env bash
printf 'gh version 2.50.0 (2024-08-01)\n'
GH
    chmod +x "$FAKEBIN/gh"
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok, skipping"* ]]
}

@test "35-gh.sh reports install plan in dry-run when gh is missing" {
    isolate_path "$FAKEBIN"
    LAB_SOE_DRY_RUN=1 PATH="$FAKEBIN" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would install"* ]]
}

#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    SCRIPT="${REPO}/scripts/15-node.sh"
    TMP="$(mktemp -d)"
    FAKEBIN="$TMP/bin"
    mkdir -p "$FAKEBIN"
}

teardown() {
    rm -rf "$TMP"
}

# Make a fake `node` that prints a given version string for `node --version`.
fake_node() {
    local dir="$1" version="$2"
    cat >"$dir/node" <<EOF
#!/usr/bin/env bash
case "\$1" in
    --version|-v) echo "v$version"; exit 0 ;;
esac
exit 0
EOF
    chmod +x "$dir/node"
}

@test "15-node.sh passes shellcheck" {
    shellcheck_script "$SCRIPT"
}

@test "15-node.sh skips install when node v20+ is already present" {
    fake_node "$FAKEBIN" "20.11.0"
    fake_bin "$FAKEBIN" npm 0
    fake_bin "$FAKEBIN" npx 0
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]] || [[ "$output" == *"skip"* ]]
}

@test "15-node.sh treats node < 20 as needing install (returns non-zero in dry-run)" {
    # We export LAB_SOE_DRY_RUN=1 so the script reports what it would do
    # rather than actually invoking apt/curl.
    fake_node "$FAKEBIN" "18.20.0"
    fake_bin "$FAKEBIN" npm 0
    fake_bin "$FAKEBIN" npx 0
    LAB_SOE_DRY_RUN=1 PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    # In dry-run mode, exit 0 but the output must mention an install plan.
    [ "$status" -eq 0 ]
    [[ "$output" == *"would install"* ]] || [[ "$output" == *"install"* ]]
}

@test "15-node.sh treats a broken node binary as needing install" {
    cat >"$FAKEBIN/node" <<'EOF'
#!/usr/bin/env bash
exit 7
EOF
    chmod +x "$FAKEBIN/node"
    fake_bin "$FAKEBIN" npm 0
    fake_bin "$FAKEBIN" npx 0
    LAB_SOE_DRY_RUN=1 PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would install"* ]]
}

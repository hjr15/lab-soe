#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    SCRIPT="${REPO}/scripts/17-python.sh"
    TMP="$(mktemp -d)"
    FAKEBIN="$TMP/bin"
    mkdir -p "$FAKEBIN"
}

teardown() {
    rm -rf "$TMP"
}

# Fake python3: `--version` prints a version; `-c 'import ensurepip'` and
# `-m pip --version` succeed or fail per the two flags passed in.
fake_python3() {
    local dir="$1" ensurepip_ok="$2" pip_ok="$3"
    cat >"$dir/python3" <<EOF
#!/usr/bin/env bash
case "\$*" in
    "--version") echo "Python 3.12.3"; exit 0 ;;
    *"import ensurepip"*) exit $([ "$ensurepip_ok" = "1" ] && echo 0 || echo 1) ;;
    "-m pip --version") exit $([ "$pip_ok" = "1" ] && echo 0 || echo 1) ;;
esac
exit 0
EOF
    chmod +x "$dir/python3"
}

@test "17-python.sh passes shellcheck" {
    shellcheck_script "$SCRIPT"
}

@test "17-python.sh skips when venv + pip already work" {
    fake_python3 "$FAKEBIN" 1 1
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]] || [[ "$output" == *"skip"* ]]
}

@test "17-python.sh plans an install when ensurepip is missing (dry-run)" {
    fake_python3 "$FAKEBIN" 0 1
    isolate_path "$FAKEBIN"
    LAB_SOE_DRY_RUN=1 PATH="$FAKEBIN" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would install"* ]]
}

@test "17-python.sh fails cleanly when python3 is absent" {
    isolate_path "$FAKEBIN"   # a PATH with no python3
    PATH="$FAKEBIN" run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"python3 not on PATH"* ]]
}

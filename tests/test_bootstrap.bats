#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    SCRIPT="${REPO}/bootstrap.sh"
    TMP="$(mktemp -d)"
    # Build a fake repo layout in TMP so we can plant our own scripts/.
    mkdir -p "$TMP/scripts"
    cp "${REPO}/scripts/lib.sh" "$TMP/scripts/lib.sh"
    cp "$SCRIPT" "$TMP/bootstrap.sh"
    # A fake os-release so require_ubuntu passes in the harness.
    cat >"$TMP/os-release" <<'EOF'
NAME="Ubuntu"
VERSION_ID="24.04"
ID=ubuntu
EOF
}

teardown() {
    rm -rf "$TMP"
}

@test "bootstrap.sh passes shellcheck" {
    shellcheck_script "$SCRIPT"
}

@test "bootstrap.sh runs numbered scripts in sorted order" {
    cat >"$TMP/scripts/10-first.sh" <<'EOF'
#!/usr/bin/env bash
echo "first"
EOF
    cat >"$TMP/scripts/20-second.sh" <<'EOF'
#!/usr/bin/env bash
echo "second"
EOF
    chmod +x "$TMP/scripts/"*.sh
    LAB_SOE_OS_RELEASE="$TMP/os-release" \
    LAB_SOE_SECRETS_FILE="$TMP/no-such-file" \
        run bash "$TMP/bootstrap.sh"
    [ "$status" -eq 0 ]
    # Assert "first" appears before "second" in output.
    first_line=$(echo "$output" | grep -n '^first$' | head -1 | cut -d: -f1)
    second_line=$(echo "$output" | grep -n '^second$' | head -1 | cut -d: -f1)
    [ -n "$first_line" ] && [ -n "$second_line" ]
    [ "$first_line" -lt "$second_line" ]
}

@test "bootstrap.sh aborts when a numbered script fails" {
    cat >"$TMP/scripts/10-good.sh" <<'EOF'
#!/usr/bin/env bash
echo "ran-good"
EOF
    cat >"$TMP/scripts/20-bad.sh" <<'EOF'
#!/usr/bin/env bash
echo "ran-bad"
exit 7
EOF
    cat >"$TMP/scripts/30-never.sh" <<'EOF'
#!/usr/bin/env bash
echo "ran-never"
EOF
    chmod +x "$TMP/scripts/"*.sh
    LAB_SOE_OS_RELEASE="$TMP/os-release" \
    LAB_SOE_SECRETS_FILE="$TMP/no-such-file" \
        run bash "$TMP/bootstrap.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ran-good"* ]]
    [[ "$output" == *"ran-bad"* ]]
    [[ "$output" != *"ran-never"* ]]
    [[ "$output" == *"20-bad.sh"* ]]
}

@test "bootstrap.sh aborts when not on Ubuntu 24.04" {
    cat >"$TMP/os-release" <<'EOF'
NAME="Fedora Linux"
VERSION_ID="40"
ID=fedora
EOF
    LAB_SOE_OS_RELEASE="$TMP/os-release" \
    LAB_SOE_SECRETS_FILE="$TMP/no-such-file" \
        run bash "$TMP/bootstrap.sh"
    [ "$status" -ne 0 ]
}

@test "bootstrap.sh propagates the installer's exit code in status and message" {
    cat >"$TMP/scripts/10-fails-with-7.sh" <<'EOF'
#!/usr/bin/env bash
exit 7
EOF
    chmod +x "$TMP/scripts/10-fails-with-7.sh"
    LAB_SOE_OS_RELEASE="$TMP/os-release" \
    LAB_SOE_SECRETS_FILE="$TMP/no-such-file" \
        run bash "$TMP/bootstrap.sh"
    [ "$status" -eq 7 ]
    [[ "$output" == *"exit 7"* ]]
    [[ "$output" == *"10-fails-with-7.sh"* ]]
}

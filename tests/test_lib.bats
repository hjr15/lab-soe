#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    LIB="${REPO}/scripts/lib.sh"
    TMP="$(mktemp -d)"
}

teardown() {
    rm -rf "$TMP"
}

@test "lib.sh passes shellcheck" {
    shellcheck_script "${REPO}/scripts/lib.sh"
}

@test "have_cmd returns 0 when command exists" {
    source "$LIB"
    run have_cmd bash
    [ "$status" -eq 0 ]
}

@test "have_cmd returns 1 when command does not exist" {
    source "$LIB"
    run have_cmd this_command_definitely_does_not_exist_xyzzy
    [ "$status" -eq 1 ]
}

@test "version_at_least: current greater than minimum returns 0" {
    source "$LIB"
    run version_at_least "20.10.5" "20.0.0"
    [ "$status" -eq 0 ]
}

@test "version_at_least: current equal to minimum returns 0" {
    source "$LIB"
    run version_at_least "20.0.0" "20.0.0"
    [ "$status" -eq 0 ]
}

@test "version_at_least: current less than minimum returns 1" {
    source "$LIB"
    run version_at_least "18.20.0" "20.0.0"
    [ "$status" -eq 1 ]
}

@test "log_info writes to stderr with [info] prefix" {
    source "$LIB"
    err=$(log_info "hello world" 2>&1 1>/dev/null)
    [[ "$err" == *"[info]"* ]]
    [[ "$err" == *"hello world"* ]]
}

@test "log_warn writes to stderr with [warn] prefix" {
    source "$LIB"
    err=$(log_warn "careful" 2>&1 1>/dev/null)
    [[ "$err" == *"[warn]"* ]]
    [[ "$err" == *"careful"* ]]
}

@test "log_error writes to stderr with [error] prefix" {
    source "$LIB"
    err=$(log_error "boom" 2>&1 1>/dev/null)
    [[ "$err" == *"[error]"* ]]
    [[ "$err" == *"boom"* ]]
}

@test "require_ubuntu accepts an Ubuntu 24.04 os-release file" {
    cat >"$TMP/os-release" <<'EOF'
NAME="Ubuntu"
VERSION_ID="24.04"
ID=ubuntu
EOF
    LAB_SOE_OS_RELEASE="$TMP/os-release"
    source "$LIB"
    run require_ubuntu
    [ "$status" -eq 0 ]
}

@test "require_ubuntu rejects a non-Ubuntu os-release file" {
    cat >"$TMP/os-release" <<'EOF'
NAME="Fedora Linux"
VERSION_ID="40"
ID=fedora
EOF
    LAB_SOE_OS_RELEASE="$TMP/os-release"
    source "$LIB"
    run require_ubuntu
    [ "$status" -ne 0 ]
}

@test "require_ubuntu rejects Ubuntu 22.04" {
    cat >"$TMP/os-release" <<'EOF'
NAME="Ubuntu"
VERSION_ID="22.04"
ID=ubuntu
EOF
    LAB_SOE_OS_RELEASE="$TMP/os-release"
    source "$LIB"
    run require_ubuntu
    [ "$status" -ne 0 ]
}

@test "load_secrets sources variables from given file" {
    cat >"$TMP/secrets.env" <<'EOF'
TEST_VAR=hello
EOF
    LAB_SOE_SECRETS_FILE="$TMP/secrets.env"
    source "$LIB"
    load_secrets
    [ "$TEST_VAR" = "hello" ]
}

@test "load_secrets logs a warning and continues when file is missing" {
    LAB_SOE_SECRETS_FILE="$TMP/does-not-exist"
    source "$LIB"
    err=$(load_secrets 2>&1 1>/dev/null)
    [[ "$err" == *"[warn]"* ]]
}

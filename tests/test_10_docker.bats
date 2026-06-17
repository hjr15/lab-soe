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
    isolate_path "$FAKEBIN"
    PATH="$FAKEBIN" run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"docker"* ]]
}

@test "10-docker.sh fails when daemon is active, user is in docker group, but docker info fails" {
    fake_bin "$FAKEBIN" docker 1
    fake_bin "$FAKEBIN" systemctl 0   # is-active returns 0 = daemon active
    # Fake id to show user IS in docker group → skips group-add, hits socket error branch
    cat >"$FAKEBIN/id" <<'ID'
#!/usr/bin/env bash
printf 'docker\n'
ID
    chmod +x "$FAKEBIN/id"
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"docker"* ]]
}

@test "10-docker.sh starts stopped daemon and succeeds" {
    CALL_FILE="$TMP/docker_calls"
    printf '0' >"$CALL_FILE"
    cat >"$FAKEBIN/docker" <<EOF
#!/usr/bin/env bash
count=\$(cat "$CALL_FILE")
count=\$((count + 1))
printf '%d' "\$count" >"$CALL_FILE"
[ "\$count" -le 1 ] && exit 1
exit 0
EOF
    chmod +x "$FAKEBIN/docker"

    cat >"$FAKEBIN/systemctl" <<'SCTL'
#!/usr/bin/env bash
case "$*" in *is-active*) exit 1 ;; esac
exit 0
SCTL
    chmod +x "$FAKEBIN/systemctl"

    cat >"$FAKEBIN/sudo" <<EOF
#!/usr/bin/env bash
PATH="$FAKEBIN:/usr/bin:/bin" exec "\$@"
EOF
    chmod +x "$FAKEBIN/sudo"

    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"docker: ok"* ]]
}

@test "10-docker.sh fails when daemon is stopped and systemctl start fails" {
    fake_bin "$FAKEBIN" docker 1
    fake_bin "$FAKEBIN" systemctl 1   # both is-active and start fail

    cat >"$FAKEBIN/sudo" <<EOF
#!/usr/bin/env bash
PATH="$FAKEBIN:/usr/bin:/bin" exec "\$@"
EOF
    chmod +x "$FAKEBIN/sudo"

    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -ne 0 ]
}

@test "10-docker.sh switches to default context when stale Docker Desktop context blocks access" {
    STATE_FILE="$TMP/ctx_switched"
    cat >"$FAKEBIN/docker" <<EOF
#!/usr/bin/env bash
case "\$*" in
    info*)
        [ -f "$STATE_FILE" ] && exit 0
        exit 1
        ;;
    context*)
        touch "$STATE_FILE"
        exit 0
        ;;
esac
exit 0
EOF
    chmod +x "$FAKEBIN/docker"

    fake_bin "$FAKEBIN" systemctl 0

    cat >"$FAKEBIN/id" <<'ID'
#!/usr/bin/env bash
printf 'docker\n'
ID
    chmod +x "$FAKEBIN/id"

    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"docker: ok"* ]]
}

@test "10-docker.sh adds user to docker group and exits with re-login message when group is missing" {
    fake_bin "$FAKEBIN" docker 1     # docker info fails
    fake_bin "$FAKEBIN" systemctl 0  # daemon is active
    fake_bin "$FAKEBIN" usermod 0

    # id: user NOT in docker group
    cat >"$FAKEBIN/id" <<'ID'
#!/usr/bin/env bash
printf 'somegroup\n'
ID
    chmod +x "$FAKEBIN/id"

    cat >"$FAKEBIN/sudo" <<EOF
#!/usr/bin/env bash
PATH="$FAKEBIN:/usr/bin:/bin" exec "\$@"
EOF
    chmod +x "$FAKEBIN/sudo"

    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"added"* ]]
    [[ "$output" == *"log out"* ]]
}

#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    SCRIPT="${REPO}/scripts/29-argocd-cli.sh"
    TMP="$(mktemp -d)"
    FAKEBIN="$TMP/bin"
    mkdir -p "$FAKEBIN"
}

teardown() {
    rm -rf "$TMP"
}

# Make a fake `argocd` whose `argocd version --client` reports the given version.
fake_argocd_version() {
    local dir="$1" version="$2"
    cat >"$dir/argocd" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
    "version --client") echo "argocd: ${version}+abc1234"; exit 0 ;;
esac
exit 0
EOF
    chmod +x "$dir/argocd"
}

@test "29-argocd-cli.sh passes shellcheck" {
    shellcheck_script "$SCRIPT"
}

@test "29-argocd-cli.sh skips install when the pinned version is already present" {
    fake_argocd_version "$FAKEBIN" "v3.3.8"
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"argocd v3.3.8: ok, skipping"* ]]
    [[ "$output" != *"would install"* ]]
    [[ "$output" != *"installing"* ]]
}

@test "29-argocd-cli.sh warns and leaves alone when a different version is present" {
    fake_argocd_version "$FAKEBIN" "v3.2.0"
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"v3.2.0"* ]]
    [[ "$output" == *"v3.3.8"* ]]
    [[ "$output" == *"warn"* ]]
    [[ "$output" != *"installing"* ]]
}

@test "29-argocd-cli.sh in dry-run announces install when argocd is missing" {
    isolate_path "$FAKEBIN"
    LAB_SOE_DRY_RUN=1 PATH="$FAKEBIN" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would install argocd v3.3.8"* ]]
}

@test "29-argocd-cli.sh respects LAB_SOE_ARGOCD_VERSION override" {
    isolate_path "$FAKEBIN"
    LAB_SOE_DRY_RUN=1 LAB_SOE_ARGOCD_VERSION=v2.10.0 PATH="$FAKEBIN" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would install argocd v2.10.0"* ]]
}

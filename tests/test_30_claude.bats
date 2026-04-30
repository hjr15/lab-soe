#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    SCRIPT="${REPO}/scripts/30-claude.sh"
    TMP="$(mktemp -d)"
    FAKEBIN="$TMP/bin"
    mkdir -p "$FAKEBIN"
}

teardown() {
    rm -rf "$TMP"
}

# Build a fake `claude` that records its args and reports everything as
# already installed/configured.
fake_claude_all_installed() {
    local dir="$1"
    cat >"$dir/claude" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
    "plugin marketplace")
        # claude plugin marketplace list: report the official one already added
        if [ "$3" = "list" ]; then
            echo "anthropics/claude-plugins-official"
            exit 0
        fi
        exit 0
        ;;
    "plugin list")
        # claude plugin list: report all required plugins as installed
        echo "superpowers"
        echo "code-review"
        echo "frontend-design"
        exit 0
        ;;
    "mcp list")
        echo "context7"
        echo "playwright"
        echo "github"
        exit 0
        ;;
    "mcp get")
        # Any name we ask about: return 0 (already exists)
        exit 0
        ;;
esac
exit 0
EOF
    chmod +x "$dir/claude"
}

@test "30-claude.sh passes shellcheck" {
    shellcheck_script "$SCRIPT"
}

@test "30-claude.sh skips all install steps when claude reports everything present" {
    fake_bin "$FAKEBIN" node 0
    fake_bin "$FAKEBIN" npm 0
    fake_bin "$FAKEBIN" npx 0
    fake_claude_all_installed "$FAKEBIN"
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"superpowers"* ]]
    [[ "$output" == *"context7"* ]]
    # Skip path must not announce any installs/registrations.
    [[ "$output" != *"would install"* ]]
    [[ "$output" != *"would register"* ]]
    [[ "$output" != *"would add"* ]]
    [[ "$output" != *"installing plugin"* ]]
    [[ "$output" != *"registering mcp"* ]]
    [[ "$output" != *"adding plugin marketplace"* ]]
}

@test "30-claude.sh logs-and-skips github MCP when GITHUB_PAT is unset" {
    fake_bin "$FAKEBIN" node 0
    fake_bin "$FAKEBIN" npm 0
    fake_bin "$FAKEBIN" npx 0
    # claude that reports github as NOT configured (mcp get exits non-zero for github)
    cat >"$FAKEBIN/claude" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
    "plugin marketplace") [ "$3" = "list" ] && echo "anthropics/claude-plugins-official"; exit 0 ;;
    "plugin list") echo "superpowers"; echo "code-review"; echo "frontend-design"; exit 0 ;;
    "mcp list") echo "context7"; echo "playwright"; exit 0 ;;
    "mcp get") [ "$3" = "github" ] && exit 1; exit 0 ;;
esac
exit 0
EOF
    chmod +x "$FAKEBIN/claude"
    unset GITHUB_PAT
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GITHUB_PAT"* ]]
    [[ "$output" == *"skip"* ]] || [[ "$output" == *"warn"* ]]
}

@test "30-claude.sh registers github MCP with Bearer prefix and jq-built JSON when PAT is set" {
    fake_bin "$FAKEBIN" node 0
    fake_bin "$FAKEBIN" npm 0
    fake_bin "$FAKEBIN" npx 0
    # claude that reports github not configured but records `mcp add-json` args.
    cat >"$FAKEBIN/claude" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
    "plugin marketplace") [ "\$3" = "list" ] && echo "anthropics/claude-plugins-official"; exit 0 ;;
    "plugin list") echo "superpowers"; echo "code-review"; echo "frontend-design"; exit 0 ;;
    "mcp list") echo "context7"; echo "playwright"; exit 0 ;;
    "mcp get") [ "\$3" = "github" ] && exit 1; exit 0 ;;
    "mcp add-json")
        # \$3 = "github", \$4 = the JSON payload
        echo "GITHUB_MCP_PAYLOAD=\$4"
        exit 0
        ;;
esac
exit 0
EOF
    chmod +x "$FAKEBIN/claude"
    # Need real jq for the script to build the payload.
    ln -sf "$(command -v jq)" "$FAKEBIN/jq"
    export GITHUB_PAT="ghp_TESTtokenABC123"
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bearer ghp_TESTtokenABC123"* ]]
    [[ "$output" == *"api.githubcopilot.com"* ]]
    # Real-install path must use the active-tense verb, not "would register".
    [[ "$output" == *"registering mcp github"* ]]
    [[ "$output" != *"would register mcp github"* ]]
}

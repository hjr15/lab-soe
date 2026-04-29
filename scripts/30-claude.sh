#!/usr/bin/env bash
# 30-claude.sh — install Claude Code, register the official plugin marketplace,
# install required plugins, and register required MCP servers.

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

DRY_RUN="${LAB_SOE_DRY_RUN:-0}"

PLUGIN_MARKETPLACE="anthropics/claude-plugins-official"
PLUGINS=(superpowers code-review frontend-design)

# --- Claude Code ------------------------------------------------------------

install_claude_code() {
    if have_cmd claude; then
        log_info "claude: ok, skipping"
        return 0
    fi
    log_info "would install claude code via npm"
    if [ "$DRY_RUN" = "1" ]; then return 0; fi
    if ! have_cmd npm; then
        log_error "npm not found; 15-node.sh must run first"
        return 1
    fi
    sudo npm install -g @anthropic-ai/claude-code
}

# --- Plugin marketplace -----------------------------------------------------

ensure_marketplace() {
    if claude plugin marketplace list 2>/dev/null | grep -qx "$PLUGIN_MARKETPLACE"; then
        log_info "marketplace ${PLUGIN_MARKETPLACE}: ok, skipping"
        return 0
    fi
    log_info "adding plugin marketplace ${PLUGIN_MARKETPLACE}"
    [ "$DRY_RUN" = "1" ] && return 0
    claude plugin marketplace add "$PLUGIN_MARKETPLACE"
}

# --- Plugins ----------------------------------------------------------------

ensure_plugin() {
    local name="$1"
    if claude plugin list 2>/dev/null | grep -qx "$name"; then
        log_info "plugin ${name}: ok, skipping"
        return 0
    fi
    log_info "installing plugin ${name}"
    [ "$DRY_RUN" = "1" ] && return 0
    claude plugin install "$name"
}

# --- MCP servers ------------------------------------------------------------

ensure_mcp_simple() {
    local name="$1"; shift
    if claude mcp get "$name" >/dev/null 2>&1; then
        log_info "mcp ${name}: ok, skipping"
        return 0
    fi
    log_info "registering mcp ${name}"
    [ "$DRY_RUN" = "1" ] && return 0
    claude mcp add "$name" "$@"
}

ensure_mcp_github() {
    if claude mcp get github >/dev/null 2>&1; then
        log_info "mcp github: ok, skipping"
        return 0
    fi
    if [ -z "${GITHUB_PAT:-}" ]; then
        log_warn "GITHUB_PAT not set; skipping github MCP — set it in ~/.config/lab-soe/secrets.env and re-run"
        return 0
    fi
    log_info "registering mcp github"
    [ "$DRY_RUN" = "1" ] && return 0
    if ! have_cmd jq; then
        log_error "jq not found; 20-k8s-tools.sh must run first"
        return 1
    fi
    local payload
    payload=$(jq -nc \
        --arg pat "$GITHUB_PAT" \
        '{type:"http", url:"https://api.githubcopilot.com/mcp",
          headers:{Authorization:("Bearer " + $pat)}}')
    claude mcp add-json github "$payload" --scope user
}

# --- Orchestration ----------------------------------------------------------

install_claude_code
ensure_marketplace

for p in "${PLUGINS[@]}"; do
    ensure_plugin "$p"
done

ensure_mcp_simple context7  -- npx -y @upstash/context7-mcp
ensure_mcp_simple playwright -- npx -y @playwright/mcp@latest
ensure_mcp_github

log_info "claude code + plugins + mcp servers: done"

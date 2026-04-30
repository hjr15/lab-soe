# lab-soe Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the idempotent host-side SOE described in `docs/superpowers/specs/2026-04-29-lab-soe-design.md`. A single `bootstrap.sh` runs ordered installer scripts that install Docker (verified), Node 20 LTS, k3d, kubectl, helm, kubectx, kubens, jq, Claude Code, and a fixed set of Claude plugins and MCP servers. Re-running is safe and is the supported way to add a new dependency.

**Architecture:** `bootstrap.sh` sources `scripts/lib.sh` (shared helpers), then executes every `scripts/[0-9][0-9]-*.sh` in sorted order. Each numbered installer presence-checks the tools it owns and skips work when they are already in place. Tests use `bats-core` and `shellcheck`; both are developer-only deps documented in CLAUDE.md, not part of the SOE install.

**Tech Stack:** bash 5+, apt, curl, npm, NodeSource, Helm apt repo, Kubernetes apt repo, bats-core, shellcheck.

---

## File Structure

```
lab-soe/
├── README.md                                 # NEW (Task 9)
├── CLAUDE.md                                 # NEW (Task 10)
├── bootstrap.sh                              # NEW (Task 8)
├── scripts/
│   ├── lib.sh                                # NEW (Task 2)
│   ├── 10-docker.sh                          # NEW (Task 3)
│   ├── 15-node.sh                            # NEW (Task 4)
│   ├── 20-k8s-tools.sh                       # NEW (Task 5)
│   └── 30-claude.sh                          # NEW (Task 6)
├── tests/
│   ├── helpers.bash                          # NEW (Task 1)
│   ├── test_lib.bats                         # NEW (Task 2)
│   ├── test_10_docker.bats                   # NEW (Task 3)
│   ├── test_15_node.bats                     # NEW (Task 4)
│   ├── test_20_k8s_tools.bats                # NEW (Task 5)
│   ├── test_30_claude.bats                   # NEW (Task 6)
│   └── test_bootstrap.bats                   # NEW (Task 8)
├── docs/superpowers/
│   ├── specs/2026-04-29-lab-soe-design.md    # exists
│   └── plans/2026-04-29-lab-soe-bootstrap.md # this file
├── secrets.env.example                       # exists
└── .gitignore                                # exists (Task 7 adds tests/.bats-cache)
```

**Responsibilities:**

- `lib.sh` — pure helpers; no installs, no side effects beyond logging.
- `10-docker.sh` — verify Docker is installed and reachable; never installs.
- `15-node.sh` — install Node 20 LTS via NodeSource if missing/old.
- `20-k8s-tools.sh` — install kubectl, helm, k3d, kubectx (provides kubens), jq.
- `30-claude.sh` — install Claude Code, register marketplace, install plugins, register MCP servers.
- `bootstrap.sh` — entry point; orchestrates the above.

**Test strategy:** `lib.sh` gets real unit tests (its functions are pure and easily exercised). Each installer script gets one bats integration test that proves the **idempotent skip path** by mocking the relevant binaries onto PATH and asserting the script exits 0 with no install attempts. End-to-end verification is a manual run on the developer machine in Task 11.

---

## Pre-flight

The repo vendors its own test tooling — no sudo, no apt. `tests/setup.sh` clones `bats-core` and downloads a static `shellcheck` binary into `tests/.tools/` (gitignored). `tests/run.sh` puts both on PATH and invokes bats. These tools exist only to test lab-soe itself; they are **not** part of what `bootstrap.sh` installs (that boundary is documented in CLAUDE.md, Task 10).

- [ ] **Step 0: Run the tooling setup once, then verify**

```bash
./tests/setup.sh
./tests/run.sh --version    # expect: Bats 1.11.x
```

Re-running `./tests/setup.sh` is a no-op when the tools are already in place.

**Throughout the rest of the plan: `./tests/run.sh tests/...` is used wherever you would normally run `bats tests/...`.** That wrapper is what guarantees the vendored shellcheck is on PATH inside test files.

---

## Task 1: Test infrastructure

**Files:**
- Create: `tests/helpers.bash`
- Create: `tests/smoke.bats`

This task sets up the bats test scaffolding and proves it runs end-to-end before we write any real tests.

- [ ] **Step 1: Write a smoke test that proves bats works**

Create `tests/smoke.bats`:

```bash
#!/usr/bin/env bats

@test "bats is wired up" {
    result=$(( 1 + 1 ))
    [ "$result" -eq 2 ]
}
```

- [ ] **Step 2: Run the smoke test, verify it passes**

```bash
./tests/run.sh tests/smoke.bats
```

Expected output:
```
1..1
ok 1 bats is wired up
```

- [ ] **Step 3: Write `tests/helpers.bash`**

Create `tests/helpers.bash` with shared helpers used by every later test file:

```bash
# Shared bats helpers for lab-soe tests.
# Source this from each test file with: load 'helpers'

# Absolute path to the repo root, regardless of where bats was invoked from.
repo_root() {
    cd "${BATS_TEST_DIRNAME}/.." && pwd
}

# Create an isolated PATH containing only the directories listed.
# Usage: with_path /tmp/fakebin /usr/bin
with_path() {
    PATH="$(IFS=:; echo "$*")"
    export PATH
}

# Make a fake executable in $1 with given name and exit code (default 0).
# Usage: fake_bin /tmp/fakebin docker 0
fake_bin() {
    local dir="$1" name="$2" exit_code="${3:-0}"
    mkdir -p "$dir"
    cat >"$dir/$name" <<EOF
#!/usr/bin/env bash
exit $exit_code
EOF
    chmod +x "$dir/$name"
}

# Run shellcheck on a script; fail the test on any finding.
# Usage: shellcheck_script scripts/10-docker.sh
shellcheck_script() {
    shellcheck -x "$1"
}
```

- [ ] **Step 4: Verify helpers.bash sources cleanly**

```bash
bash -n tests/helpers.bash
```

Expected: no output, exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/helpers.bash tests/smoke.bats
git commit -m "test: scaffold bats test infrastructure"
```

---

## Task 2: `lib.sh` shared helpers (TDD)

**Files:**
- Create: `scripts/lib.sh`
- Create: `tests/test_lib.bats`

`lib.sh` exposes a small set of pure helpers used by every numbered script. All work is testable without touching the system: `have_cmd` uses PATH only, `version_at_least` is pure string compare, log functions write to stderr, `require_ubuntu` reads `/etc/os-release` (overridable via env var), `load_secrets` reads a file path (overridable via env var).

- [ ] **Step 1: Write the failing tests in `tests/test_lib.bats`**

```bash
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
    LAB_SOE_OS_RELEASE="$TMP/os-release" source "$LIB"
    run require_ubuntu
    [ "$status" -eq 0 ]
}

@test "require_ubuntu rejects a non-Ubuntu os-release file" {
    cat >"$TMP/os-release" <<'EOF'
NAME="Fedora Linux"
VERSION_ID="40"
ID=fedora
EOF
    LAB_SOE_OS_RELEASE="$TMP/os-release" source "$LIB"
    run require_ubuntu
    [ "$status" -ne 0 ]
}

@test "require_ubuntu rejects Ubuntu 22.04" {
    cat >"$TMP/os-release" <<'EOF'
NAME="Ubuntu"
VERSION_ID="22.04"
ID=ubuntu
EOF
    LAB_SOE_OS_RELEASE="$TMP/os-release" source "$LIB"
    run require_ubuntu
    [ "$status" -ne 0 ]
}

@test "load_secrets sources variables from given file" {
    cat >"$TMP/secrets.env" <<'EOF'
TEST_VAR=hello
EOF
    LAB_SOE_SECRETS_FILE="$TMP/secrets.env" source "$LIB"
    load_secrets
    [ "$TEST_VAR" = "hello" ]
}

@test "load_secrets logs a warning and continues when file is missing" {
    LAB_SOE_SECRETS_FILE="$TMP/does-not-exist" source "$LIB"
    err=$(load_secrets 2>&1 1>/dev/null)
    [[ "$err" == *"[warn]"* ]]
}
```

- [ ] **Step 2: Run the tests, verify they fail**

```bash
./tests/run.sh tests/test_lib.bats
```

Expected: every test fails (lib.sh does not exist yet, or shellcheck fails on a missing file).

- [ ] **Step 3: Implement `scripts/lib.sh`**

Create `scripts/lib.sh`:

```bash
#!/usr/bin/env bash
# Shared helpers for lab-soe installer scripts.
# Source from each script with: source "$(dirname "$0")/lib.sh"

# --- Logging ----------------------------------------------------------------

log_info()  { printf '[info] %s\n'  "$*" >&2; }
log_warn()  { printf '[warn] %s\n'  "$*" >&2; }
log_error() { printf '[error] %s\n' "$*" >&2; }

# --- Presence and version checks --------------------------------------------

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# version_at_least <current> <minimum>
# Exit 0 if current >= minimum (semver), 1 otherwise.
# Uses dpkg's version comparator (always present on Ubuntu).
version_at_least() {
    dpkg --compare-versions "$1" ge "$2"
}

# --- Platform gate ----------------------------------------------------------

# Aborts unless running on Ubuntu 24.04.
# Override the os-release path with LAB_SOE_OS_RELEASE for tests.
require_ubuntu() {
    local os_release="${LAB_SOE_OS_RELEASE:-/etc/os-release}"
    if [ ! -r "$os_release" ]; then
        log_error "cannot read $os_release"
        return 1
    fi
    # shellcheck disable=SC1090
    . "$os_release"
    if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "24.04" ]; then
        log_error "lab-soe targets Ubuntu 24.04; detected ID=${ID:-?} VERSION_ID=${VERSION_ID:-?}"
        return 1
    fi
    return 0
}

# --- Secrets ----------------------------------------------------------------

# Sources $LAB_SOE_SECRETS_FILE (default ~/.config/lab-soe/secrets.env).
# Logs a warning and returns 0 if the file is missing — installers that need
# a specific variable check for it themselves and skip cleanly.
load_secrets() {
    local secrets="${LAB_SOE_SECRETS_FILE:-${HOME}/.config/lab-soe/secrets.env}"
    if [ -r "$secrets" ]; then
        # shellcheck disable=SC1090
        . "$secrets"
        log_info "loaded secrets from $secrets"
    else
        log_warn "no secrets file at $secrets — steps that need secrets will be skipped"
    fi
}
```

- [ ] **Step 4: Run the tests, verify they pass**

```bash
./tests/run.sh tests/test_lib.bats
```

Expected: all 13 tests pass.

- [ ] **Step 5: Run shellcheck explicitly**

```bash
./tests/.tools/shellcheck -x scripts/lib.sh
```

Expected: no output, exit 0.

- [ ] **Step 6: Commit**

```bash
git add scripts/lib.sh tests/test_lib.bats
git commit -m "feat: add lib.sh shared helpers with tests"
```

---

## Task 3: `10-docker.sh` (verify-only)

**Files:**
- Create: `scripts/10-docker.sh`
- Create: `tests/test_10_docker.bats`

This script does **not** install Docker. It verifies presence, daemon reachability, and group membership, and warns (but does not fail) if the user is not in the `docker` group.

- [ ] **Step 1: Write the failing tests in `tests/test_10_docker.bats`**

```bash
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
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"docker"* ]]
}

@test "10-docker.sh fails when docker exists but 'docker info' returns non-zero" {
    fake_bin "$FAKEBIN" docker 1
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run the tests, verify they fail**

```bash
./tests/run.sh tests/test_10_docker.bats
```

Expected: all 4 tests fail (script does not exist).

- [ ] **Step 3: Implement `scripts/10-docker.sh`**

Create `scripts/10-docker.sh`:

```bash
#!/usr/bin/env bash
# 10-docker.sh — verify Docker is installed, reachable, and usable.
# This script never installs Docker. See README for one-time install steps.

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

if ! have_cmd docker; then
    log_error "docker not found on PATH; install it first (see README)"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    log_error "'docker info' failed; the daemon may be down or your user may not have access"
    exit 1
fi

if ! id -nG | tr ' ' '\n' | grep -qx docker; then
    log_warn "your user is not in the 'docker' group; consider: sudo usermod -aG docker \$USER && newgrp docker"
fi

log_info "docker: ok"
```

- [ ] **Step 4: Make the script executable**

```bash
chmod +x scripts/10-docker.sh
```

- [ ] **Step 5: Run the tests, verify they pass**

```bash
./tests/run.sh tests/test_10_docker.bats
```

Expected: all 4 tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/10-docker.sh tests/test_10_docker.bats
git commit -m "feat: add 10-docker.sh Docker verification script"
```

---

## Task 4: `15-node.sh` (Node 20 LTS via NodeSource)

**Files:**
- Create: `scripts/15-node.sh`
- Create: `tests/test_15_node.bats`

The script's idempotent skip path is fully testable without actually installing anything: when `node` is on PATH and reports a version >= 20, the script exits 0 with no `apt` calls. The install path is exercised in the end-to-end run (Task 11).

- [ ] **Step 1: Write the failing tests in `tests/test_15_node.bats`**

```bash
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
```

- [ ] **Step 2: Run the tests, verify they fail**

```bash
./tests/run.sh tests/test_15_node.bats
```

Expected: all 3 tests fail (script does not exist).

- [ ] **Step 3: Implement `scripts/15-node.sh`**

Create `scripts/15-node.sh`:

```bash
#!/usr/bin/env bash
# 15-node.sh — install Node.js 20 LTS via NodeSource if missing or < 20.

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

NODE_MIN_VERSION="20.0.0"
DRY_RUN="${LAB_SOE_DRY_RUN:-0}"

current_node_version() {
    if have_cmd node; then
        node --version 2>/dev/null | sed 's/^v//'
    else
        echo ""
    fi
}

install_node_20() {
    if [ "$DRY_RUN" = "1" ]; then
        log_info "would install Node 20 LTS via NodeSource"
        return 0
    fi
    log_info "installing Node 20 LTS via NodeSource"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
}

current="$(current_node_version)"

if [ -n "$current" ] && version_at_least "$current" "$NODE_MIN_VERSION"; then
    log_info "node v${current}: ok, skipping"
    if ! have_cmd npm || ! have_cmd npx; then
        log_error "node is present but npm/npx are missing; reinstall nodejs package"
        exit 1
    fi
    exit 0
fi

install_node_20

# Verify post-install (skipped in dry-run).
if [ "$DRY_RUN" != "1" ]; then
    have_cmd node || { log_error "node not on PATH after install"; exit 1; }
    have_cmd npm  || { log_error "npm not on PATH after install"; exit 1; }
    have_cmd npx  || { log_error "npx not on PATH after install"; exit 1; }
    log_info "node $(node --version): installed"
fi
```

- [ ] **Step 4: Make the script executable**

```bash
chmod +x scripts/15-node.sh
```

- [ ] **Step 5: Run the tests, verify they pass**

```bash
./tests/run.sh tests/test_15_node.bats
```

Expected: all 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/15-node.sh tests/test_15_node.bats
git commit -m "feat: add 15-node.sh Node 20 LTS installer"
```

---

## Task 5: `20-k8s-tools.sh` (k3d, kubectl, helm, kubectx, kubens, jq)

**Files:**
- Create: `scripts/20-k8s-tools.sh`
- Create: `tests/test_20_k8s_tools.bats`

Each tool gets its own presence check. The skip path is testable. The install path is dry-run testable.

- [ ] **Step 1: Write the failing tests in `tests/test_20_k8s_tools.bats`**

```bash
#!/usr/bin/env bats

load 'helpers'

setup() {
    REPO="$(repo_root)"
    SCRIPT="${REPO}/scripts/20-k8s-tools.sh"
    TMP="$(mktemp -d)"
    FAKEBIN="$TMP/bin"
    mkdir -p "$FAKEBIN"
}

teardown() {
    rm -rf "$TMP"
}

@test "20-k8s-tools.sh passes shellcheck" {
    shellcheck_script "$SCRIPT"
}

@test "20-k8s-tools.sh skips all installs when every tool is present" {
    for t in k3d kubectl helm kubectx kubens jq; do
        fake_bin "$FAKEBIN" "$t" 0
    done
    PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"k3d"* ]]
    [[ "$output" == *"kubectl"* ]]
    [[ "$output" == *"helm"* ]]
    [[ "$output" == *"kubectx"* ]]
    [[ "$output" == *"kubens"* ]]
    [[ "$output" == *"jq"* ]]
}

@test "20-k8s-tools.sh in dry-run announces install when tools are missing" {
    LAB_SOE_DRY_RUN=1 PATH="$FAKEBIN:/usr/bin:/bin" run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would install"* ]]
}
```

- [ ] **Step 2: Run the tests, verify they fail**

```bash
./tests/run.sh tests/test_20_k8s_tools.bats
```

Expected: all 3 tests fail.

- [ ] **Step 3: Implement `scripts/20-k8s-tools.sh`**

Create `scripts/20-k8s-tools.sh`:

```bash
#!/usr/bin/env bash
# 20-k8s-tools.sh — install local k8s dev tools: k3d, kubectl, helm, kubectx,
# kubens, jq. Each tool is independently presence-checked and skipped if found.

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

DRY_RUN="${LAB_SOE_DRY_RUN:-0}"

run_or_say() {
    if [ "$DRY_RUN" = "1" ]; then
        log_info "would run: $*"
    else
        "$@"
    fi
}

# --- jq ---------------------------------------------------------------------

install_jq() {
    if have_cmd jq; then
        log_info "jq: ok, skipping"
        return 0
    fi
    log_info "would install jq via apt"
    run_or_say sudo apt-get install -y jq
}

# --- kubectx (provides both kubectx and kubens) -----------------------------

install_kubectx() {
    if have_cmd kubectx && have_cmd kubens; then
        log_info "kubectx: ok, skipping"
        log_info "kubens: ok, skipping"
        return 0
    fi
    log_info "would install kubectx (provides kubens) via apt"
    run_or_say sudo apt-get install -y kubectx
}

# --- kubectl (Kubernetes apt repo) ------------------------------------------

install_kubectl() {
    if have_cmd kubectl; then
        log_info "kubectl: ok, skipping"
        return 0
    fi
    log_info "would install kubectl via Kubernetes apt repo"
    if [ "$DRY_RUN" = "1" ]; then return 0; fi
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
    sudo mkdir -p -m 755 /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
            | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    fi
    if [ ! -f /etc/apt/sources.list.d/kubernetes.list ]; then
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' \
            | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
    fi
    sudo apt-get update
    sudo apt-get install -y kubectl
}

# --- helm (Helm apt repo) ---------------------------------------------------

install_helm() {
    if have_cmd helm; then
        log_info "helm: ok, skipping"
        return 0
    fi
    log_info "would install helm via Helm apt repo"
    if [ "$DRY_RUN" = "1" ]; then return 0; fi
    if [ ! -f /etc/apt/keyrings/helm.gpg ]; then
        curl -fsSL https://baltocdn.com/helm/signing.asc \
            | sudo gpg --dearmor -o /etc/apt/keyrings/helm.gpg
    fi
    if [ ! -f /etc/apt/sources.list.d/helm-stable-debian.list ]; then
        echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main' \
            | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list >/dev/null
    fi
    sudo apt-get update
    sudo apt-get install -y helm
}

# --- k3d (official install script) ------------------------------------------

install_k3d() {
    if have_cmd k3d; then
        log_info "k3d: ok, skipping"
        return 0
    fi
    log_info "would install k3d via get.k3d.io"
    if [ "$DRY_RUN" = "1" ]; then return 0; fi
    curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
}

install_jq
install_kubectx
install_kubectl
install_helm
install_k3d

log_info "k8s tools: done"
```

- [ ] **Step 4: Make the script executable**

```bash
chmod +x scripts/20-k8s-tools.sh
```

- [ ] **Step 5: Run the tests, verify they pass**

```bash
./tests/run.sh tests/test_20_k8s_tools.bats
```

Expected: all 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/20-k8s-tools.sh tests/test_20_k8s_tools.bats
git commit -m "feat: add 20-k8s-tools.sh installer for k3d/kubectl/helm/kubectx/jq"
```

---

## Task 6: `30-claude.sh` (Claude Code, plugins, MCP servers)

**Files:**
- Create: `scripts/30-claude.sh`
- Create: `tests/test_30_claude.bats`

Special concerns:
- Claude Code is installed via `npm install -g @anthropic-ai/claude-code`. Requires Node 20 LTS (from Task 4).
- Plugins go through `claude plugin marketplace add` then `claude plugin install <name>`. Each is guarded by checking `claude plugin list` for the name.
- MCP servers go through `claude mcp add` (and `claude mcp add-json` for the GitHub HTTP MCP). Each is guarded by checking `claude mcp get <name>` exit code.
- The GitHub MCP needs `GITHUB_PAT`; if absent in the loaded environment, the step is logged-and-skipped, the rest of the script continues.

- [ ] **Step 1: Write the failing tests in `tests/test_30_claude.bats`**

```bash
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
```

- [ ] **Step 2: Run the tests, verify they fail**

```bash
./tests/run.sh tests/test_30_claude.bats
```

Expected: all 3 tests fail.

- [ ] **Step 3: Implement `scripts/30-claude.sh`**

Create `scripts/30-claude.sh`:

```bash
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
    claude mcp add-json github \
        '{"type":"http","url":"https://api.githubcopilot.com/mcp","headers":{"Authorization":"'"$GITHUB_PAT"'"}}' \
        --scope user
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
```

> **Note for the implementer:** the exact `claude plugin` and `claude mcp` subcommand names match Claude Code's current public CLI. If a Claude Code release renames any of these, update only this script.

- [ ] **Step 4: Make the script executable**

```bash
chmod +x scripts/30-claude.sh
```

- [ ] **Step 5: Run the tests, verify they pass**

```bash
./tests/run.sh tests/test_30_claude.bats
```

Expected: all 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/30-claude.sh tests/test_30_claude.bats
git commit -m "feat: add 30-claude.sh Claude Code, plugins, and MCP installer"
```

---

## Task 7: ~~Update `.gitignore` for test artifacts~~ (completed during Pre-flight)

The Pre-flight tooling vendoring already added `tests/.tools/`, `.bats-cache/`, and `tests/.bats-cache/` to `.gitignore`. Skip this task.

---

## Task 8: `bootstrap.sh` entry point

**Files:**
- Create: `bootstrap.sh`
- Create: `tests/test_bootstrap.bats`

`bootstrap.sh` is the user-facing entry point. It sources `lib.sh`, gates on Ubuntu 24.04, loads secrets, then runs every numbered installer in sorted order. Failure of any installer aborts immediately with a clear message.

- [ ] **Step 1: Write the failing tests in `tests/test_bootstrap.bats`**

```bash
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
```

- [ ] **Step 2: Run the tests, verify they fail**

```bash
./tests/run.sh tests/test_bootstrap.bats
```

Expected: all 4 tests fail.

- [ ] **Step 3: Implement `bootstrap.sh`**

Create `bootstrap.sh`:

```bash
#!/usr/bin/env bash
# bootstrap.sh — entry point for the lab-soe SOE.
#
# Runs every scripts/[0-9][0-9]-*.sh in sorted order. Each script is
# idempotent and may be re-run safely. Add a new dependency by dropping
# a new numbered script in scripts/ — no edits needed here.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${ROOT}/scripts"

# shellcheck source=scripts/lib.sh
source "${SCRIPTS_DIR}/lib.sh"

require_ubuntu
load_secrets

shopt -s nullglob
mapfile -t INSTALLERS < <(printf '%s\n' "${SCRIPTS_DIR}"/[0-9][0-9]-*.sh | sort)

if [ "${#INSTALLERS[@]}" -eq 0 ]; then
    log_warn "no installer scripts found in ${SCRIPTS_DIR}"
    exit 0
fi

for script in "${INSTALLERS[@]}"; do
    log_info "==> running $(basename "$script")"
    if ! "$script"; then
        log_error "failed: $(basename "$script") (exit $?)"
        exit 1
    fi
done

log_info "lab-soe bootstrap complete"
```

- [ ] **Step 4: Make the script executable**

```bash
chmod +x bootstrap.sh
```

- [ ] **Step 5: Run the tests, verify they pass**

```bash
./tests/run.sh tests/test_bootstrap.bats
```

Expected: all 4 tests pass.

- [ ] **Step 6: Run the full bats suite to make sure nothing regressed**

```bash
./tests/run.sh tests/
```

Expected: every test in every file passes.

- [ ] **Step 7: Commit**

```bash
git add bootstrap.sh tests/test_bootstrap.bats
git commit -m "feat: add bootstrap.sh entry point with ordered installer execution"
```

---

## Task 9: `README.md`

**Files:**
- Create: `README.md`

Keep it short. ~40 lines.

- [ ] **Step 1: Write `README.md`**

```markdown
# lab-soe

Idempotent host-side Standard Operating Environment for local Kubernetes-based product development on Ubuntu 24.04.

Each product gets its own local k3d cluster in its own repo. `lab-soe` only installs the **tools needed to run the lab** — anything that runs *inside* a cluster (CI/CD, observability, registries) is its own product.

## Prerequisites

- Ubuntu 24.04 LTS, x86_64
- Docker installed and the current user in the `docker` group
- `sudo` access

## Install

```bash
git clone https://github.com/hjr15/lab-soe.git ~/Documents/Code/lab-soe
cd ~/Documents/Code/lab-soe

# One-time: place secrets outside the repo
mkdir -p ~/.config/lab-soe
cp secrets.env.example ~/.config/lab-soe/secrets.env
chmod 600 ~/.config/lab-soe/secrets.env
$EDITOR ~/.config/lab-soe/secrets.env   # set GITHUB_PAT

./bootstrap.sh
```

Re-run `./bootstrap.sh` any time to pick up new tools.

## What it installs

- **Docker** — verified only (must already be installed)
- **Node.js 20 LTS** + npm + npx (NodeSource apt)
- **k3d**, **kubectl**, **helm**, **kubectx** (provides `kubens`), **jq**
- **Claude Code** + plugins: `superpowers`, `code-review`, `frontend-design`
- **MCP servers**: `context7`, `playwright`, `github`

## Per-project usage

`lab-soe` does not own product configs. Each product owns its own cluster and chart. Typical pattern:

```bash
cd ~/code/myproduct
k3d cluster create myproduct --port "8080:80@loadbalancer"
kubectx k3d-myproduct
helm install myapp ./chart
```

Switch contexts: `kubectx`. Switch namespaces: `kubens`.

## Contributing

- Run tests: `./tests/run.sh tests/`
- Lint: covered automatically by the test suite (each script's bats file runs shellcheck via `shellcheck_script`).
- Add a new dependency: drop a new `scripts/NN-<topic>.sh`. Out of scope: anything that runs inside a cluster.
```

- [ ] **Step 2: Verify length**

```bash
wc -l README.md
```

Expected: roughly 40 lines (acceptable up to ~50).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

---

## Task 10: `CLAUDE.md`

**Files:**
- Create: `CLAUDE.md`

Keep it short. ~20 lines. These are rules for any Claude (or human) working in this repo.

- [ ] **Step 1: Write `CLAUDE.md`**

```markdown
# Rules for working in lab-soe

## Scope

`lab-soe` installs **host-side prerequisites only** for the local k8s lab on Ubuntu 24.04. It does not host product configs, charts, or in-cluster workloads.

**Out of scope:** anything that runs inside a Kubernetes cluster — CI/CD (Jenkins, ArgoCD), observability (Prometheus, Grafana), ingress controllers, shared registries. Each of those belongs in its own product repo with its own k3d cluster.

## Editing rules

- Every script must be idempotent: presence-check first, skip if already done.
- All scripts use helpers from `scripts/lib.sh`. Don't reimplement logging, presence checks, or version comparisons.
- Adding a new dependency = create a **new** numbered script `scripts/NN-<topic>.sh`. Do **not** edit existing scripts to add unrelated tools.
- No destructive operations. Never `rm -rf`, never reset Docker or k8s state.
- Prefer official apt repositories over `curl | sh` when both exist; use `curl | sh` only when the upstream publishes no apt source (e.g. k3d).
- Keep `README.md` and this file short. Detail belongs in `docs/superpowers/specs/`.
- Never commit secrets. Real secrets live only in `~/.config/lab-soe/secrets.env`.

## Tests

- Run all tests: `./tests/run.sh tests/`
- Lint: covered automatically by the test suite (each script's bats file runs shellcheck via `shellcheck_script`).
- Every new installer script must come with a `tests/test_NN_<topic>.bats` covering at minimum: shellcheck passes, and the skip path is taken when the tool is already present.

## Design references

- Spec: `docs/superpowers/specs/2026-04-29-lab-soe-design.md`
- Plan: `docs/superpowers/plans/2026-04-29-lab-soe-bootstrap.md`
```

- [ ] **Step 2: Verify length**

```bash
wc -l CLAUDE.md
```

Expected: roughly 25 lines (acceptable up to ~35).

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md rules for working in lab-soe"
```

---

## Task 11: End-to-end run on the developer machine

**Files:**
- None (verification only)

This task verifies the spec's success criteria on the actual workstation. It is **not** automatable in tests because it modifies the host (apt installs, npm globals).

- [ ] **Step 1: Ensure secrets file exists**

```bash
mkdir -p ~/.config/lab-soe
[ -f ~/.config/lab-soe/secrets.env ] || cp secrets.env.example ~/.config/lab-soe/secrets.env
chmod 600 ~/.config/lab-soe/secrets.env
```

If `GITHUB_PAT=ghp_replace_me` is still the value, **revoke the old leaked PAT on GitHub**, generate a fresh one, paste it in.

- [ ] **Step 2: Run bootstrap**

```bash
./bootstrap.sh 2>&1 | tee /tmp/lab-soe-bootstrap.log
```

Expected last line: `[info] lab-soe bootstrap complete`.

- [ ] **Step 3: Verify success criterion 1 — toolchain is usable**

```bash
docker info >/dev/null && echo OK
node --version    # expect: v20.x.x
k3d version
kubectl version --client --output=yaml | head -5
helm version --short
kubectx --help >/dev/null && echo kubectx OK
kubens --help >/dev/null && echo kubens OK
jq --version
claude --version
claude plugin list
claude mcp list
```

Every command must succeed and report a sensible value.

- [ ] **Step 4: Verify success criterion 2 — re-run is a no-op**

```bash
./bootstrap.sh 2>&1 | tee /tmp/lab-soe-bootstrap-rerun.log
grep -E '(installing|would install|adding)' /tmp/lab-soe-bootstrap-rerun.log || echo "no install actions on rerun: OK"
```

Expected: every tool logs `ok, skipping`. No new install attempts.

- [ ] **Step 5: Smoke-test cluster creation**

```bash
k3d cluster create lab-soe-smoke --port "18080:80@loadbalancer"
kubectl get nodes
kubectx
kubectx k3d-lab-soe-smoke
k3d cluster delete lab-soe-smoke
```

All commands must succeed.

- [ ] **Step 6: If any verification step fails**

Diagnose, fix the relevant installer, re-run its bats tests, re-run `./bootstrap.sh`, then re-run the verification steps from Step 3. Commit any fix as a separate commit referencing the verification step it addresses.

- [ ] **Step 7: Final tag**

```bash
git tag -a v0.1.0 -m "lab-soe v0.1.0 — initial idempotent SOE bootstrap"
```

(Push the tag with `git push origin v0.1.0` once the remote is reachable.)

---

## Spec coverage matrix

| Spec section | Implementing task |
|---|---|
| Repo layout | Tasks 1–10 |
| Idempotency model | Tasks 2–8 (every installer + bootstrap) |
| `lib.sh` helpers | Task 2 |
| `10-docker.sh` verify-only | Task 3 |
| `15-node.sh` Node 20 LTS | Task 4 |
| `20-k8s-tools.sh` k3d/kubectl/helm/kubectx/jq | Task 5 |
| `30-claude.sh` Claude Code + plugins + MCP | Task 6 |
| `bootstrap.sh` orchestration | Task 8 |
| Secrets handling (`load_secrets`, GITHUB_PAT skip path) | Tasks 2, 6 |
| README contents | Task 9 |
| CLAUDE.md contents | Task 10 |
| Future extension pattern (numbered scripts) | Documented in Task 10's CLAUDE.md |
| Success criteria 1, 2 | Task 11 (Steps 3 & 4) |
| Success criterion 3 (new tool = new numbered script only) | Bootstrap design (Task 8) |
| Success criterion 4 (no secrets in repo) | `.gitignore` (already present) + Task 11 reminder |
| Migration: remove ad-hoc note files | Already done before initial commit |

No spec section is unimplemented.

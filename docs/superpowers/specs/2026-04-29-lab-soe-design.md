# lab-soe Design Spec

**Date:** 2026-04-29
**Status:** Approved (brainstorm)
**Owner:** ryan@howman.me

## Purpose

`lab-soe` is the Standard Operating Environment for local Kubernetes-based product development on this workstation. It installs the **host-side prerequisites** needed to run the lab — nothing more.

Each product under development gets its own local k3d cluster, deployed via Helm, in its own repository. `lab-soe` does not own those clusters, charts, or product workflows; it only ensures the tools to run them are present and working.

## Scope

### In scope

- One idempotent bootstrap script that installs and verifies the local k8s dev toolchain.
- Sanity-check of an existing Docker installation (k3d's runtime).
- Install of Claude Code, a fixed set of Claude plugins, and a fixed set of MCP servers.
- A short README, a short CLAUDE.md, and this design spec.
- A pattern for adding new host-side dependencies as they appear (append-only numbered scripts).

### Out of scope

- Per-product Helm charts, cluster definitions, or `Makefile`s — those live in each product's own repo.
- Any workload that runs **inside** a Kubernetes cluster: CI/CD systems (Jenkins, ArgoCD), observability stacks (Prometheus, Grafana), ingress controllers, shared local registries, service meshes. Each of those is itself a product, with its own repo and its own k3d cluster.
- Cross-cluster orchestration tooling. `kubectx` is sufficient for switching contexts.
- Platform support beyond Ubuntu 24.04 on x86_64.

## Context

- Workstation: Dell Precision T7610, Ubuntu 24.04 LTS, x86_64.
- Docker is already installed and working.
- No other k8s tooling is currently installed.
- A sibling project `service-platform/` runs personal services via docker-compose and is independent of `lab-soe`.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Local cluster runtime | **k3d** | Lightweight, Docker-backed, fast to create/destroy, runs concurrently. |
| Cluster model | **One cluster per product, run concurrently** | Strong isolation; matches how products will eventually be deployed. |
| Context switching | **`kubectx` + `kubens`** | Simple, well-known, no custom wrapper needed. |
| Repo structure | **Toolchain only** (Option B from brainstorm) | `lab-soe` does not host product configs; each product is self-contained. |
| Per-project workflow | **Raw tools** (Option A from brainstorm) | Each product owns its own `Makefile` (or equivalent). No central CLI to maintain. |
| Idempotency mechanism | **Shell scripts using presence checks (and version checks where a known minimum applies)** | No new runtime dependency (no Ansible/Nix). Re-runnable by design. |
| Secrets location | **`~/.config/lab-soe/secrets.env`** (mode 0600, gitignored) | Out of repo, single source for tokens used by installers. |

## Components Installed

| Component | Purpose | Source |
|---|---|---|
| Docker | k3d node runtime | Already present; script verifies presence, daemon reachability, and group membership (does not install). |
| Node.js (LTS) + npm + npx | Runtime for Claude Code and several MCP servers | NodeSource official apt repository (Node 20 LTS). |
| k3d | Local k3s cluster runner | Official install script (`get.k3d.io`). |
| kubectl | Kubernetes CLI | Kubernetes official apt repository. |
| helm | Chart deployer | Helm official apt repository. |
| kubectx | Cluster context switcher | apt (`kubectx` package). |
| kubens | Namespace switcher | apt (ships with `kubectx`). |
| jq | JSON helper used by installer scripts | apt. |
| Claude Code | Dev assistant CLI | `npm install -g @anthropic-ai/claude-code`. |
| Claude plugin: `superpowers` | Workflow skills | `claude-plugins-official` marketplace. |
| Claude plugin: `code-review` | Code review skill | `claude-plugins-official` marketplace. |
| Claude plugin: `frontend-design` | Frontend skill | `claude-plugins-official` marketplace. |
| MCP server: `context7` | Upstash Context7 docs lookup | `claude mcp add`. |
| MCP server: `playwright` | Microsoft Playwright browser automation | `claude mcp add`. |
| MCP server: `github` | GitHub API access | `claude mcp add-json`, reads `GITHUB_PAT` from `secrets.env`. |

If a Claude Code release renames or moves a subcommand, that change is contained to `30-claude.sh`.

## Repository Layout

```
lab-soe/
├── README.md                              # ~40 lines: what / install / usage
├── CLAUDE.md                              # ~20 lines: rules for Claude in this repo
├── bootstrap.sh                           # entry point; sources lib.sh, runs scripts/*.sh
├── scripts/
│   ├── lib.sh                             # shared helpers
│   ├── 10-docker.sh                       # verify only
│   ├── 15-node.sh                         # Node.js 20 LTS + npm + npx
│   ├── 20-k8s-tools.sh                    # k3d, kubectl, helm, kubectx, kubens, jq
│   └── 30-claude.sh                       # Claude Code + plugins + MCP servers
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-04-29-lab-soe-design.md   # this file
├── secrets.env.example                    # template; real file lives in ~/.config/lab-soe/
└── .gitignore                             # excludes secrets.env, *.env
```

## Bootstrap Script Design

### `lib.sh` (shared helpers)

Provides functions used by every numbered script. Concretely:

- `log_info`, `log_warn`, `log_error` — consistent prefixed output to stderr.
- `have_cmd <name>` — returns 0 if `<name>` is on PATH.
- `version_at_least <current> <minimum>` — semver comparison.
- `require_ubuntu` — aborts cleanly if not on Ubuntu 24.04.
- `load_secrets` — sources `~/.config/lab-soe/secrets.env` if present; logs a warning if absent.

### `bootstrap.sh`

1. `set -euo pipefail`.
2. Source `scripts/lib.sh`.
3. `require_ubuntu`.
4. `load_secrets`.
5. For each `scripts/[0-9][0-9]-*.sh` in sorted order: execute it. Any non-zero exit aborts the whole run with a clear message naming the failing script.
6. On success, print a short summary of what was installed vs. what was already present.

### Numbered installer contract

Every `scripts/NN-*.sh` follows the same shape:

1. For each tool it manages:
   - If `have_cmd <tool>` and (where applicable) version meets minimum → log "ok, skipping" and continue.
   - Otherwise install via the canonical method, then verify.
2. Never modifies state outside its own concern.
3. Never prompts interactively (assumes `sudo -n` is OK or that the user has run `sudo -v` recently; bootstrap will document this).
4. Exits non-zero with a clear message on failure.

### `10-docker.sh`

- Verifies `docker` is on PATH.
- Verifies the daemon is reachable (`docker info` succeeds).
- Verifies the user is in the `docker` group (warns if not, does not auto-add).
- Does **not** install Docker. Installation is a one-time manual step (the existing `docker-install` note documents the apt packages used).

### `15-node.sh`

- If `node` is on PATH and reports a version `>= 20`, log "ok, skipping" and return.
- Otherwise, add the NodeSource Node 20 LTS apt repository if not already present, then `apt install -y nodejs`.
- Verify `node`, `npm`, and `npx` are all on PATH after install.

### `20-k8s-tools.sh`

- Adds the Kubernetes apt repository if missing, installs `kubectl`.
- Adds the Helm apt repository if missing, installs `helm`.
- Installs `k3d` via the official install script if missing.
- `apt install` `kubectx` (which provides both `kubectx` and `kubens`) and `jq`.

### `30-claude.sh`

- Installs Claude Code via `npm install -g @anthropic-ai/claude-code` if `claude` is not on PATH (relies on `15-node.sh` having run first).
- Adds the `anthropics/claude-plugins-official` marketplace if not already added.
- For each plugin (`superpowers`, `code-review`, `frontend-design`): install if not already installed (idempotent guard).
- For each MCP server (`context7`, `playwright`): add via `claude mcp add` if not already configured.
- For the GitHub MCP: if `GITHUB_PAT` is set in the loaded secrets, add via `claude mcp add-json`. If not set, log a warning naming the variable and the file, and continue (the rest of the SOE still completes).

## Secrets Handling

- Real secrets file: `~/.config/lab-soe/secrets.env`, mode `0600`.
- Format: shell variable assignments, e.g. `GITHUB_PAT=ghp_xxx`.
- Repo includes `secrets.env.example` showing every variable any installer reads, with placeholder values.
- `bootstrap.sh` sources the real file once, early, via `load_secrets`.
- Installers that need a secret check for it explicitly and skip cleanly with a clear log line if absent. Re-running `bootstrap.sh` after adding the secret will then complete the skipped step.
- `.gitignore` excludes `secrets.env` and `*.env` (defensive).

### Migration note

The leaked `GITHUB_PAT` currently in `lab-soe/claude-commands` must be revoked on GitHub before rollout. The replacement PAT goes into `~/.config/lab-soe/secrets.env`. The `claude-commands` and `docker-install` ad-hoc note files in the repo root will be removed by the implementation; their content is captured in `30-claude.sh` and the `10-docker.sh` documentation respectively.

## Documentation

### `README.md` (~40 lines)

- One-sentence purpose.
- Prerequisites: Ubuntu 24.04, Docker installed, sudo access.
- Install steps: clone, populate `~/.config/lab-soe/secrets.env` (copy from `secrets.env.example`), run `./bootstrap.sh`.
- Bullet list of what gets installed.
- Three-line per-project example using `k3d cluster create`, `kubectx`, `helm install`.
- "Re-run `./bootstrap.sh` any time to pick up new tools."

### `CLAUDE.md` (~20 lines)

- All scripts must be idempotent and use helpers from `lib.sh`.
- New host-side tooling = new numbered script in `scripts/`. Never edit existing scripts to add unrelated tools.
- **Out of scope: anything that runs inside a k8s cluster.** CI/CD, observability, registries, ingress are products in their own repos.
- No destructive operations. Never `rm -rf`, never reset Docker or k8s state.
- Prefer official apt repositories over `curl | sh` when both exist; use `curl | sh` only for tools that publish no apt source (e.g. k3d).
- Keep `README.md` and `CLAUDE.md` short. Add detail to the design spec instead.
- Never commit secrets; secrets live in `~/.config/lab-soe/secrets.env` only.

## Per-Project Workflow (informational only)

`lab-soe` does not enforce any per-project structure. The README documents the typical pattern as an example only:

```bash
# inside the product's own repo
k3d cluster create myproduct --port "8080:80@loadbalancer"
kubectx k3d-myproduct
helm install myapp ./chart
```

Each product chooses its own conventions for cluster naming, port mapping, and chart layout.

## Future Extension Pattern

Adding a new host-side dependency:

1. Create a new numbered script `scripts/NN-<topic>.sh` following the installer contract.
2. Re-run `./bootstrap.sh`.

That is the only supported extension mechanism for `lab-soe`. Anything that runs inside a cluster — including Jenkins, ArgoCD, Prometheus/Grafana, and shared registries — is explicitly **not** added here. Those become their own products with their own k3d clusters and Helm charts in their own repositories.

## Success Criteria

1. On a fresh Ubuntu 24.04 machine with Docker installed, `git clone … && ./bootstrap.sh` completes successfully and the user can run `k3d cluster create test && kubectl get nodes && kubectx` without further setup.
2. Re-running `./bootstrap.sh` on an already-installed machine completes without errors and without reinstalling anything that is already present at an acceptable version.
3. Adding a new tool requires only a new numbered script — no edits to `bootstrap.sh`, `lib.sh`, or any other existing installer.
4. No secret values are ever written to the repository.

## Open Questions

None at brainstorm close. Implementation may surface specifics (e.g. exact `claude` plugin subcommand syntax for the current release); those are resolved in `30-claude.sh` without changing this design.

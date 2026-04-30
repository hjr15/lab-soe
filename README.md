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

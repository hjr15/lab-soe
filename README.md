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

./bootstrap.sh 2>&1 | tee /tmp/lab-soe-bootstrap.log
```

You'll be prompted for `sudo` once for the apt installs. Re-run `./bootstrap.sh` any time to pick up new tools — already-installed steps log `ok, skipping`.

None of the bundled installers require a secret. If you add a custom `scripts/NN-*.sh` that needs one, copy `secrets.env.example` to `~/.config/lab-soe/secrets.env` (mode `0600`) and `bootstrap.sh` will source it automatically.

## What it installs

- **Docker** — verified only (must already be installed)
- **Node.js 20 LTS** + npm + npx (NodeSource apt)
- **Python venv capability** — `python3-venv` (ensurepip) + `python3-pip`, so any product can build its own virtualenv (products own their venv + requirements; lab-soe only guarantees the host *can*)
- **k3d**, **kubectl**, **helm**, **kubectx** (provides `kubens`), **jq**
- **k9s** (terminal UI for Kubernetes — GitHub releases)
- **Tilt** (live-reload local k8s dev — get.tilt.dev installer)
- **argocd CLI** pinned to `v3.3.8` (override with `LAB_SOE_ARGOCD_VERSION`)
- **Terraform** (HashiCorp apt)
- **AWS CLI v2** (official bundled installer)

## Per-project usage

`lab-soe` does not own product configs. Each product owns its own cluster and chart. Typical pattern:

```bash
cd ~/code/myproduct
k3d cluster create myproduct --port "8080:80@loadbalancer"
kubectx k3d-myproduct
helm install myapp ./chart
```

Switch contexts: `kubectx`. Switch namespaces: `kubens`.

One product that uses `lab-soe` as its recommended host prerequisite is **[service-platform-template](https://github.com/hjr15/service-platform-template)** — a fork-and-run ArgoCD + cert-manager GitOps lab. It validates its required tools against this repo's [`tools.yaml`](tools.yaml) (see its `tests/contract.sh`), so the dependency between the two stays honest as both evolve.

## Tool manifest

[`tools.yaml`](tools.yaml) is the machine-readable list of what `bootstrap.sh` installs (`name` + `version` + `role`). It's the single source of truth downstream consumers diff against — keep it in sync when you add or repin a tool.

## Contributing

- Run tests: `./tests/run.sh tests/`
- Lint: covered automatically by the test suite (each script's bats file runs shellcheck via `shellcheck_script`).
- Add a new dependency: drop a new `scripts/NN-<topic>.sh`. Out of scope: anything that runs inside a cluster.

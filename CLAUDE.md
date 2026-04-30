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

# Shared bats helpers for lab-soe tests.
# Source this from each test file with: load 'helpers'

# Absolute path to the repo root, regardless of where bats was invoked from.
repo_root() {
    cd "${BATS_TEST_DIRNAME}/.." && pwd
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

# Symlink a baseline of system utilities into $1 so a script can run with
# PATH limited to that directory. Pass extra utility names as additional args.
# Usage: isolate_path "$FAKEBIN" awk sed
isolate_path() {
    local dir="$1"; shift
    mkdir -p "$dir"
    local cmd
    for cmd in bash dirname id tr grep printf "$@"; do
        ln -sf "$(command -v "$cmd")" "$dir/$cmd"
    done
}

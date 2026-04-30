#!/usr/bin/env bats

load 'helpers'

@test "helpers.bash passes shellcheck" {
    shellcheck "$(repo_root)/tests/helpers.bash"
}

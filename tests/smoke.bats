#!/usr/bin/env bats

@test "bats is wired up" {
    result=$(( 1 + 1 ))
    [ "$result" -eq 2 ]
}

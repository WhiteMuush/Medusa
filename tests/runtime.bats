#!/usr/bin/env bats
# tests/runtime.bats - lib/core.sh: container runtime + compose detection,
# including podman on Fedora-family hosts. No container is launched here.

load 'test_helper'

setup() {
    load_libs
}

@test "container_cmd_for: maps a compose command to its runtime" {
    [ "$(_container_cmd_for 'docker compose')" = "docker" ]
    [ "$(_container_cmd_for 'docker-compose')" = "docker" ]
    [ "$(_container_cmd_for 'podman compose')" = "podman" ]
    [ "$(_container_cmd_for 'podman-compose')" = "podman" ]
}

@test "container_cmd_for: empty compose command yields empty runtime" {
    [ -z "$(_container_cmd_for '')" ]
}

@test "detect_compose_cmd: CONTAINER_CMD stays consistent with COMPOSE_CMD" {
    detect_compose_cmd
    if [[ -n "$COMPOSE_CMD" ]]; then
        [ "$CONTAINER_CMD" = "$(_container_cmd_for "$COMPOSE_CMD")" ]
        [[ "$CONTAINER_CMD" =~ ^(docker|podman)$ ]]
    else
        [ -z "$CONTAINER_CMD" ]
    fi
}

@test "detect_compose_cmd: recognises podman-compose when only podman exists" {
    # Stub command_exists/podman so detection runs without a real runtime.
    command_exists() { case "$1" in podman|podman-compose) return 0 ;; *) return 1 ;; esac; }
    podman() { return 1; }   # 'podman compose version' fails -> falls back to podman-compose
    detect_compose_cmd
    [ "$COMPOSE_CMD" = "podman-compose" ]
    [ "$CONTAINER_CMD" = "podman" ]
}

@test "detect_compose_cmd: prefers docker when both are present" {
    command_exists() { return 0; }          # everything present
    docker() { return 0; }                   # 'docker compose version' succeeds
    detect_compose_cmd
    [ "$COMPOSE_CMD" = "docker compose" ]
    [ "$CONTAINER_CMD" = "docker" ]
}

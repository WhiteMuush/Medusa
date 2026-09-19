#!/usr/bin/env bats
# tests/core.bats - lib/core.sh: tool-name validation and tool_dir safety.

load 'test_helper'

setup() {
    load_libs
    TOOLS_DIR="/tmp/medusa-test-tools"
}

@test "core: load guard is set after sourcing" {
    [ "$_CORE_SH_LOADED" = "1" ]
}

@test "validate: accepts plain tool names" {
    run _validate_tool_name "wazuh"
    [ "$status" -eq 0 ]
    run _validate_tool_name "opencti"
    [ "$status" -eq 0 ]
    run _validate_tool_name "misp_2"
    [ "$status" -eq 0 ]
    run _validate_tool_name "some-tool.v1"
    [ "$status" -eq 0 ]
}

@test "validate: rejects an empty name" {
    run _validate_tool_name ""
    [ "$status" -ne 0 ]
}

@test "validate: rejects path traversal" {
    run _validate_tool_name ".."
    [ "$status" -ne 0 ]
    run _validate_tool_name "../../etc"
    [ "$status" -ne 0 ]
    run _validate_tool_name "a/../b"
    [ "$status" -ne 0 ]
}

@test "validate: rejects a name containing a slash" {
    run _validate_tool_name "sub/dir"
    [ "$status" -ne 0 ]
    run _validate_tool_name "/etc"
    [ "$status" -ne 0 ]
}

@test "validate: rejects shell metacharacters and spaces" {
    run _validate_tool_name 'a b'
    [ "$status" -ne 0 ]
    run _validate_tool_name 'a;rm'
    [ "$status" -ne 0 ]
    run _validate_tool_name 'a$b'
    [ "$status" -ne 0 ]
}

@test "tool_dir: returns TOOLS_DIR/name for a valid tool" {
    run tool_dir "wazuh"
    [ "$status" -eq 0 ]
    [ "$output" = "/tmp/medusa-test-tools/wazuh" ]
}

@test "tool_dir: refuses an invalid name instead of building an escaping path" {
    run tool_dir ".."
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

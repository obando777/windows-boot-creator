#!/bin/bash
# 01-shell-executor.sh - Test basic shell execution
# Tests the underlying shell commands that ShellExecutor.swift uses

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-helpers.sh"

print_section "TEST: 01-shell-executor.sh"

# ============================================================================
# Test: Simple Command Execution
# ============================================================================
test_simple_command() {
    start_test "test_simple_command"

    local output
    output=$(echo "hello")
    local exit_code=$?

    log_detail "Command: echo hello"
    log_detail "Exit code: $exit_code"

    assert_equals "hello" "$output" "Simple echo should output 'hello'"
}

# ============================================================================
# Test: Command with Arguments
# ============================================================================
test_command_with_args() {
    start_test "test_command_with_args"

    local output
    output=$(ls -la /tmp 2>&1)
    local exit_code=$?

    log_detail "Command: ls -la /tmp"
    log_detail "Exit code: $exit_code"

    if [[ $exit_code -eq 0 ]] && [[ -n "$output" ]]; then
        pass_test "Command with args executed successfully"
    else
        fail_test "Command with args failed"
    fi
}

# ============================================================================
# Test: Command Failure
# ============================================================================
test_command_failure() {
    start_test "test_command_failure"

    false
    local exit_code=$?

    log_detail "Command: false"
    log_detail "Exit code: $exit_code"

    assert_exit_code 1 "$exit_code" "Command 'false' should exit with code 1"
}

# ============================================================================
# Test: Command Output Capture
# ============================================================================
test_output_capture() {
    start_test "test_output_capture"

    local output
    output=$(printf "line1\nline2\nline3")

    log_detail "Command: printf with newlines"

    if [[ "$output" == *"line1"* ]] && [[ "$output" == *"line2"* ]] && [[ "$output" == *"line3"* ]]; then
        pass_test "Multi-line output captured correctly"
    else
        fail_test "Output capture failed"
    fi
}

# ============================================================================
# Test: Command Error Capture
# ============================================================================
test_error_capture() {
    start_test "test_error_capture"

    local stderr_output
    stderr_output=$(ls /nonexistent_path_12345 2>&1)
    local exit_code=$?

    log_detail "Command: ls /nonexistent_path_12345"
    log_detail "Exit code: $exit_code"

    if [[ $exit_code -ne 0 ]] && [[ "$stderr_output" == *"No such file"* ]]; then
        pass_test "Error output captured correctly"
    else
        fail_test "Error capture failed"
    fi
}

# ============================================================================
# Test: Zsh Execution (as used by ShellExecutor)
# ============================================================================
test_zsh_execution() {
    start_test "test_zsh_execution"

    local output
    output=$(/bin/zsh -c "echo 'zsh works'" 2>&1)
    local exit_code=$?

    log_detail "Command: /bin/zsh -c 'echo zsh works'"
    log_detail "Exit code: $exit_code"

    assert_equals "zsh works" "$output" "Zsh should execute commands correctly"
}

# ============================================================================
# Test: Pipe Commands
# ============================================================================
test_pipe_commands() {
    start_test "test_pipe_commands"

    local output
    output=$(echo "hello world" | tr 'h' 'H')
    local exit_code=$?

    log_detail "Command: echo 'hello world' | tr 'h' 'H'"
    log_detail "Output: $output"

    assert_equals "Hello world" "$output" "Pipe commands should work"
}

# ============================================================================
# Run All Tests
# ============================================================================
run_tests() {
    test_simple_command
    test_command_with_args
    test_command_failure
    test_output_capture
    test_error_capture
    test_zsh_execution
    test_pipe_commands
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi

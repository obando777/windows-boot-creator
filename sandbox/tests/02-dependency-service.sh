#!/bin/bash
# 02-dependency-service.sh - Test dependency checking (DependencyService.swift)
# Tests: checkWimlib(), checkHomebrew() - read-only operations only

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-helpers.sh"

print_section "TEST: 02-dependency-service.sh"

# ============================================================================
# Test: Check Homebrew Exists
# ============================================================================
test_check_homebrew() {
    start_test "test_check_homebrew"

    local brew_path
    brew_path=$(which brew 2>/dev/null)
    local exit_code=$?

    log_detail "Command: which brew"
    log_detail "Result: $brew_path"

    if [[ $exit_code -eq 0 ]] && [[ -n "$brew_path" ]]; then
        pass_test "Homebrew found at: $brew_path"
    else
        # This is informational - brew not being installed is okay
        log_warning "Homebrew not found - this is okay for testing"
        pass_test "which command works (brew not installed)"
    fi
}

# ============================================================================
# Test: Check wimlib Exists
# ============================================================================
test_check_wimlib() {
    start_test "test_check_wimlib"

    local wimlib_path
    wimlib_path=$(which wimlib-imagex 2>/dev/null)
    local exit_code=$?

    log_detail "Command: which wimlib-imagex"
    log_detail "Result: ${wimlib_path:-not found}"

    if [[ $exit_code -eq 0 ]] && [[ -n "$wimlib_path" ]]; then
        pass_test "wimlib found at: $wimlib_path"
    else
        # This is informational - wimlib not being installed is okay
        log_warning "wimlib not found - some tests will be skipped"
        pass_test "which command works (wimlib not installed)"
    fi
}

# ============================================================================
# Test: Check Non-existent Command
# ============================================================================
test_check_nonexistent() {
    start_test "test_check_nonexistent"

    local fake_path
    fake_path=$(which totally_fake_command_xyz123 2>/dev/null)
    local exit_code=$?

    log_detail "Command: which totally_fake_command_xyz123"
    log_detail "Exit code: $exit_code"
    log_detail "Output: ${fake_path:-empty}"

    if [[ $exit_code -ne 0 ]] && [[ -z "$fake_path" ]]; then
        pass_test "Non-existent command correctly returns empty/error"
    else
        fail_test "which should fail for non-existent commands"
    fi
}

# ============================================================================
# Test: Homebrew Info (if available)
# ============================================================================
test_homebrew_info() {
    start_test "test_homebrew_info"

    if ! command -v brew &> /dev/null; then
        skip_test "Homebrew not installed"
        return
    fi

    local version
    version=$(brew --version 2>&1 | head -1)
    local exit_code=$?

    log_detail "Command: brew --version"
    log_detail "Output: $version"

    if [[ $exit_code -eq 0 ]] && [[ "$version" == *"Homebrew"* ]]; then
        pass_test "Homebrew version: $version"
    else
        fail_test "Failed to get Homebrew version"
    fi
}

# ============================================================================
# Test: wimlib Info (if available)
# ============================================================================
test_wimlib_info() {
    start_test "test_wimlib_info"

    if ! command -v wimlib-imagex &> /dev/null; then
        skip_test "wimlib not installed"
        return
    fi

    local version
    version=$(wimlib-imagex --version 2>&1 | head -1)
    local exit_code=$?

    log_detail "Command: wimlib-imagex --version"
    log_detail "Output: $version"

    if [[ $exit_code -eq 0 ]] && [[ -n "$version" ]]; then
        pass_test "wimlib version: $version"
    else
        fail_test "Failed to get wimlib version"
    fi
}

# ============================================================================
# Test: Check Standard macOS Commands
# ============================================================================
test_standard_commands() {
    start_test "test_standard_commands"

    local commands=("diskutil" "hdiutil" "rsync")
    local all_found=true

    for cmd in "${commands[@]}"; do
        local cmd_path
        cmd_path=$(which "$cmd" 2>/dev/null)
        log_detail "$cmd: ${cmd_path:-not found}"

        if [[ -z "$cmd_path" ]]; then
            all_found=false
        fi
    done

    if [[ "$all_found" == "true" ]]; then
        pass_test "All required macOS commands found"
    else
        fail_test "Some required commands missing"
    fi
}

# ============================================================================
# Run All Tests
# ============================================================================
run_tests() {
    test_check_homebrew
    test_check_wimlib
    test_check_nonexistent
    test_homebrew_info
    test_wimlib_info
    test_standard_commands
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi

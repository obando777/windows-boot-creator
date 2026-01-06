#!/bin/bash
# test-helpers.sh - Common test functions
# Part of WindowsBootCreator sandbox testing

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
CURRENT_TEST=""

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_detail() {
    echo -e "         ${CYAN}$1${NC}"
}

# ============================================================================
# Test Lifecycle Functions
# ============================================================================

start_test() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    echo ""
    echo -e "  ${BOLD}[TEST]${NC} $test_name"
}

pass_test() {
    local message="${1:-}"
    echo -e "         ${GREEN}✓ PASSED${NC} ${message}"
    ((TESTS_PASSED++))
}

fail_test() {
    local message="${1:-}"
    echo -e "         ${RED}✗ FAILED${NC} ${message}"
    ((TESTS_FAILED++))
}

skip_test() {
    local reason="${1:-}"
    echo -e "         ${YELLOW}⊘ SKIPPED${NC} ${reason}"
    ((TESTS_SKIPPED++))
}

# ============================================================================
# Assertion Functions
# ============================================================================

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"

    log_detail "Expected: \"$expected\""
    log_detail "Actual:   \"$actual\""

    if [[ "$expected" == "$actual" ]]; then
        pass_test "$message"
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"

    log_detail "Value: \"$value\""

    if [[ -n "$value" ]]; then
        pass_test "$message"
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

assert_empty() {
    local value="$1"
    local message="${2:-Value should be empty}"

    log_detail "Value: \"$value\""

    if [[ -z "$value" ]]; then
        pass_test "$message"
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

assert_file_exists() {
    local path="$1"
    local message="${2:-File should exist}"

    log_detail "Path: $path"

    if [[ -f "$path" ]]; then
        pass_test "$message"
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

assert_dir_exists() {
    local path="$1"
    local message="${2:-Directory should exist}"

    log_detail "Path: $path"

    if [[ -d "$path" ]]; then
        pass_test "$message"
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

assert_command_succeeds() {
    local command="$1"
    local message="${2:-Command should succeed}"

    log_detail "Command: $command"

    if eval "$command" > /dev/null 2>&1; then
        pass_test "$message"
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

assert_command_fails() {
    local command="$1"
    local message="${2:-Command should fail}"

    log_detail "Command: $command"

    if ! eval "$command" > /dev/null 2>&1; then
        pass_test "$message"
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"

    log_detail "Looking for: \"$needle\""
    log_detail "In: \"${haystack:0:100}...\""

    if [[ "$haystack" == *"$needle"* ]]; then
        pass_test "$message"
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Exit code should match}"

    log_detail "Expected exit code: $expected"
    log_detail "Actual exit code:   $actual"

    if [[ "$expected" -eq "$actual" ]]; then
        pass_test "$message"
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

# ============================================================================
# Utility Functions
# ============================================================================

run_command() {
    local command="$1"
    local timeout_seconds="${2:-30}"

    log_detail "Running: $command"

    local output
    local exit_code

    if command -v timeout &> /dev/null; then
        output=$(timeout "$timeout_seconds" bash -c "$command" 2>&1)
        exit_code=$?
    else
        # macOS doesn't have timeout by default
        output=$(bash -c "$command" 2>&1)
        exit_code=$?
    fi

    echo "$output"
    return $exit_code
}

timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

print_section() {
    local title="$1"
    echo ""
    echo "--------------------------------------------------------------------------------"
    echo "  $title"
    echo "--------------------------------------------------------------------------------"
}

print_header() {
    local title="$1"
    echo ""
    echo "================================================================================"
    echo "  $title"
    echo "================================================================================"
}

print_summary() {
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

    print_header "SUMMARY"
    echo ""
    echo "  Total Tests: $total"
    echo -e "  ${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC} $TESTS_FAILED"
    echo -e "  ${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}All tests passed!${NC}"
    else
        echo -e "  ${RED}${BOLD}Some tests failed.${NC}"
    fi

    echo "================================================================================"
}

# ============================================================================
# Cleanup Functions
# ============================================================================

CLEANUP_PATHS=()

register_cleanup() {
    local path="$1"
    CLEANUP_PATHS+=("$path")
}

cleanup_all() {
    log_info "Cleaning up test artifacts..."

    for path in "${CLEANUP_PATHS[@]}"; do
        if [[ -e "$path" ]]; then
            rm -rf "$path" 2>/dev/null && log_detail "Removed: $path"
        fi
    done
}

# Set trap for cleanup on exit
trap cleanup_all EXIT

# Export test counters for subshells
export TESTS_PASSED TESTS_FAILED TESTS_SKIPPED

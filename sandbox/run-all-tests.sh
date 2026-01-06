#!/bin/bash
# run-all-tests.sh - Master test runner for WindowsBootCreator sandbox tests
# Usage: ./run-all-tests.sh [test-name]

# Don't use set -e as we want tests to continue even if some fail

RUNNER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$RUNNER_DIR"

# Source helpers
source "$RUNNER_DIR/lib/test-helpers.sh"
source "$RUNNER_DIR/lib/mock-data.sh"

# ============================================================================
# Main
# ============================================================================

main() {
    local start_time=$(date +%s)
    local specific_test="$1"

    print_header "WINDOWS BOOT CREATOR - SANDBOX TESTS"
    echo ""
    log_info "Starting test suite at $(timestamp)"
    log_info "Script directory: $RUNNER_DIR"
    echo ""

    # Initialize mock data
    log_info "Initializing mock test data..."
    mkdir -p "$FIXTURES_DIR"
    mkdir -p "$RUNNER_DIR/results"

    # Find all test scripts
    local test_scripts=()
    if [[ -n "$specific_test" ]]; then
        # Run specific test
        if [[ -f "$RUNNER_DIR/tests/$specific_test" ]]; then
            test_scripts=("$RUNNER_DIR/tests/$specific_test")
        elif [[ -f "$RUNNER_DIR/tests/${specific_test}.sh" ]]; then
            test_scripts=("$RUNNER_DIR/tests/${specific_test}.sh")
        else
            log_error "Test not found: $specific_test"
            exit 1
        fi
    else
        # Run all tests in order
        for script in "$RUNNER_DIR/tests/"*.sh; do
            if [[ -f "$script" ]]; then
                test_scripts+=("$script")
            fi
        done
    fi

    # Sort tests by filename (they're numbered)
    IFS=$'\n' test_scripts=($(sort <<<"${test_scripts[*]}"))
    unset IFS

    log_info "Found ${#test_scripts[@]} test script(s) to run"
    echo ""

    # Run each test script
    for script in "${test_scripts[@]}"; do
        local script_name=$(basename "$script")
        chmod +x "$script"

        # Source the test script to run in same process (share counters)
        source "$script"
        run_tests
    done

    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Print summary
    print_summary
    echo "  Duration: ${duration} seconds"
    echo ""

    # Save results
    local results_file="$RUNNER_DIR/results/test-results-$(date +%Y%m%d-%H%M%S).txt"
    {
        echo "Test Results - $(timestamp)"
        echo "=============================="
        echo "Passed: $TESTS_PASSED"
        echo "Failed: $TESTS_FAILED"
        echo "Skipped: $TESTS_SKIPPED"
        echo "Duration: ${duration}s"
    } > "$results_file"

    log_info "Results saved to: $results_file"

    # Cleanup
    cleanup_mock_data

    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

# ============================================================================
# Help
# ============================================================================

show_help() {
    echo "Usage: $0 [OPTIONS] [TEST_NAME]"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo "  -l, --list    List available tests"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run all tests"
    echo "  $0 01-shell-executor  # Run specific test"
    echo ""
}

list_tests() {
    echo "Available tests:"
    for script in "$RUNNER_DIR/tests/"*.sh; do
        if [[ -f "$script" ]]; then
            echo "  - $(basename "$script" .sh)"
        fi
    done
}

# ============================================================================
# Entry Point
# ============================================================================

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -l|--list)
        list_tests
        exit 0
        ;;
    *)
        main "$1"
        ;;
esac

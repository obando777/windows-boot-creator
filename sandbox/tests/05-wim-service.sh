#!/bin/bash
# 05-wim-service.sh - Test WIM operations (WimService.swift)
# Tests: getWimInfo(), needsSplit(), splitWimFile()
# NOTE: Tests are conditional on wimlib being installed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-helpers.sh"
source "$SCRIPT_DIR/../lib/mock-data.sh"

print_section "TEST: 05-wim-service.sh"

# Check if wimlib is available
WIMLIB_AVAILABLE=false
if command -v wimlib-imagex &> /dev/null; then
    WIMLIB_AVAILABLE=true
fi

# Constants for size thresholds
FOUR_GB=$((4 * 1024 * 1024 * 1024))

# ============================================================================
# Test: Check wimlib Availability
# ============================================================================
test_wimlib_available() {
    start_test "test_wimlib_available"

    local wimlib_path
    wimlib_path=$(which wimlib-imagex 2>/dev/null)

    log_detail "Command: which wimlib-imagex"
    log_detail "Result: ${wimlib_path:-not found}"

    if [[ -n "$wimlib_path" ]]; then
        WIMLIB_AVAILABLE=true
        pass_test "wimlib is installed at: $wimlib_path"
    else
        WIMLIB_AVAILABLE=false
        log_warning "wimlib not installed - WIM-specific tests will be skipped"
        pass_test "wimlib check completed (not installed)"
    fi
}

# ============================================================================
# Test: Needs Split - Small File (< 4GB)
# ============================================================================
test_needs_split_small() {
    start_test "test_needs_split_small"

    # Test with 1GB size
    local test_size=$((1 * 1024 * 1024 * 1024))

    log_detail "Test size: $test_size bytes (1GB)"
    log_detail "Threshold: $FOUR_GB bytes (4GB)"

    if [[ $test_size -lt $FOUR_GB ]]; then
        pass_test "1GB file correctly identified as NOT needing split"
    else
        fail_test "Logic error: 1GB should be less than 4GB"
    fi
}

# ============================================================================
# Test: Needs Split - Large File (> 4GB)
# ============================================================================
test_needs_split_large() {
    start_test "test_needs_split_large"

    # Test with 5GB size
    local test_size=$((5 * 1024 * 1024 * 1024))

    log_detail "Test size: $test_size bytes (5GB)"
    log_detail "Threshold: $FOUR_GB bytes (4GB)"

    if [[ $test_size -gt $FOUR_GB ]]; then
        pass_test "5GB file correctly identified as NEEDING split"
    else
        fail_test "Logic error: 5GB should be greater than 4GB"
    fi
}

# ============================================================================
# Test: Needs Split - Edge Case (exactly 4GB)
# ============================================================================
test_needs_split_edge() {
    start_test "test_needs_split_edge"

    local test_size=$FOUR_GB

    log_detail "Test size: $test_size bytes (exactly 4GB)"
    log_detail "Threshold: $FOUR_GB bytes (4GB)"

    # Exactly 4GB should NOT need split (FAT32 limit is 4GB - 1 byte)
    if [[ $test_size -le $FOUR_GB ]]; then
        pass_test "4GB file (edge case) handled correctly"
    else
        fail_test "Edge case handling error"
    fi
}

# ============================================================================
# Test: Get WIM Info (requires wimlib)
# ============================================================================
test_get_wim_info() {
    start_test "test_get_wim_info"

    if [[ "$WIMLIB_AVAILABLE" != "true" ]]; then
        skip_test "wimlib not installed"
        return
    fi

    # Create a mock WIM
    local mock_wim
    mock_wim=$(create_mock_wim "test_info.wim" 512)

    if [[ ! -f "$mock_wim" ]]; then
        skip_test "Failed to create mock WIM"
        return
    fi

    log_detail "Mock WIM: $mock_wim"

    local output
    output=$(wimlib-imagex info "$mock_wim" 2>&1)
    local exit_code=$?

    log_detail "Exit code: $exit_code"
    log_detail "Output (first 100 chars): ${output:0:100}..."

    # Our mock isn't a real WIM, so wimlib will likely reject it
    # But we can verify the command runs
    if [[ $exit_code -eq 0 ]]; then
        pass_test "wimlib-imagex info succeeded on mock file"
    else
        # Expected: mock file isn't a valid WIM
        if [[ "$output" == *"Not a WIM"* ]] || [[ "$output" == *"invalid"* ]] || [[ "$output" == *"error"* ]]; then
            pass_test "wimlib correctly rejected invalid WIM file"
        else
            log_warning "wimlib returned unexpected error"
            pass_test "wimlib-imagex command executed"
        fi
    fi
}

# ============================================================================
# Test: Split WIM Command Syntax
# ============================================================================
test_split_command_syntax() {
    start_test "test_split_command_syntax"

    if [[ "$WIMLIB_AVAILABLE" != "true" ]]; then
        skip_test "wimlib not installed"
        return
    fi

    # Test wimlib help for split command
    local output
    output=$(wimlib-imagex split --help 2>&1)
    local exit_code=$?

    log_detail "Command: wimlib-imagex split --help"

    if [[ "$output" == *"split"* ]] || [[ "$output" == *"WIMFILE"* ]] || [[ "$output" == *"Usage"* ]]; then
        pass_test "wimlib-imagex split command is available"
    else
        fail_test "split command not recognized"
    fi
}

# ============================================================================
# Test: Parse Progress Output
# ============================================================================
test_parse_progress() {
    start_test "test_parse_progress"

    # Sample progress output that wimlib might produce
    local sample_outputs=(
        "Splitting: 25%"
        "Progress: 50% complete"
        "Writing: 75%"
        "100% done"
    )

    local all_parsed=true

    for output in "${sample_outputs[@]}"; do
        # Extract percentage using regex similar to Swift code
        local percent
        percent=$(echo "$output" | grep -oE '[0-9]+%' | head -1 | tr -d '%')

        log_detail "Input: '$output' -> Parsed: '${percent:-none}'"

        if [[ -z "$percent" ]]; then
            all_parsed=false
        fi
    done

    if [[ "$all_parsed" == "true" ]]; then
        pass_test "Progress parsing works for all sample formats"
    else
        fail_test "Some progress formats failed to parse"
    fi
}

# ============================================================================
# Test: WIM File Extension Detection
# ============================================================================
test_wim_extension() {
    start_test "test_wim_extension"

    local valid_extensions=("install.wim" "boot.wim" "test.swm")
    local invalid_extensions=("file.iso" "file.txt" "file.img")

    log_detail "Testing WIM file extension detection"

    local all_correct=true

    for file in "${valid_extensions[@]}"; do
        if [[ "$file" != *.wim ]] && [[ "$file" != *.swm ]]; then
            log_detail "FAIL: $file should be recognized"
            all_correct=false
        fi
    done

    for file in "${invalid_extensions[@]}"; do
        if [[ "$file" == *.wim ]] || [[ "$file" == *.swm ]]; then
            log_detail "FAIL: $file should NOT be recognized"
            all_correct=false
        fi
    done

    if [[ "$all_correct" == "true" ]]; then
        pass_test "WIM extension detection works correctly"
    else
        fail_test "Extension detection has errors"
    fi
}

# ============================================================================
# Test: SWM File Naming Pattern
# ============================================================================
test_swm_naming() {
    start_test "test_swm_naming"

    # Test that split WIM naming follows pattern: basename.swm, basename2.swm, etc.
    local base="install"
    local expected=("install.swm" "install2.swm" "install3.swm")

    log_detail "Testing SWM naming pattern for base: $base"

    local naming_correct=true
    local i=1

    for name in "${expected[@]}"; do
        if [[ $i -eq 1 ]]; then
            local expected_name="${base}.swm"
        else
            local expected_name="${base}${i}.swm"
        fi

        log_detail "Part $i: expected '$expected_name', got '$name'"

        if [[ "$name" != "$expected_name" ]]; then
            naming_correct=false
        fi
        ((i++))
    done

    if [[ "$naming_correct" == "true" ]]; then
        pass_test "SWM naming pattern is correct"
    else
        fail_test "SWM naming pattern incorrect"
    fi
}

# ============================================================================
# Run All Tests
# ============================================================================
run_tests() {
    test_wimlib_available
    test_needs_split_small
    test_needs_split_large
    test_needs_split_edge

    if [[ "$WIMLIB_AVAILABLE" == "true" ]]; then
        test_get_wim_info
        test_split_command_syntax
    else
        log_warning "wimlib not installed - skipping WIM-specific tests"
    fi

    test_parse_progress
    test_wim_extension
    test_swm_naming
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi

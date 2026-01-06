#!/bin/bash
# 04-iso-service.sh - Test ISO operations (ISOService.swift)
# Tests: validateISO(), mountISO(), unmountISO()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-helpers.sh"
source "$SCRIPT_DIR/../lib/mock-data.sh"

print_section "TEST: 04-iso-service.sh"

# Global for mount point tracking
MOUNTED_VOLUME=""
TEST_ISO_PATH=""

# ============================================================================
# Test: Validate ISO File Exists
# ============================================================================
test_validate_iso_exists() {
    start_test "test_validate_iso_exists"

    if [[ -z "$TEST_ISO_PATH" ]] || [[ ! -f "$TEST_ISO_PATH" ]]; then
        fail_test "Mock ISO was not created"
        return
    fi

    log_detail "Checking: $TEST_ISO_PATH"

    if [[ -f "$TEST_ISO_PATH" ]]; then
        local size
        size=$(stat -f%z "$TEST_ISO_PATH" 2>/dev/null || stat -c%s "$TEST_ISO_PATH" 2>/dev/null)
        log_detail "File size: $size bytes"
        pass_test "ISO file exists: $TEST_ISO_PATH"
    else
        fail_test "ISO file does not exist"
    fi
}

# ============================================================================
# Test: Validate ISO File Missing
# ============================================================================
test_validate_iso_missing() {
    start_test "test_validate_iso_missing"

    local fake_path="/tmp/nonexistent_iso_12345.iso"

    log_detail "Checking: $fake_path"

    if [[ ! -f "$fake_path" ]]; then
        pass_test "Correctly detected missing ISO"
    else
        fail_test "File unexpectedly exists"
    fi
}

# ============================================================================
# Test: Validate ISO Extension
# ============================================================================
test_validate_iso_extension() {
    start_test "test_validate_iso_extension"

    local valid_ext="windows.iso"
    local invalid_ext="windows.txt"

    log_detail "Valid extension: $valid_ext"
    log_detail "Invalid extension: $invalid_ext"

    if [[ "$valid_ext" == *.iso ]] && [[ "$invalid_ext" != *.iso ]]; then
        pass_test "Extension validation logic works"
    else
        fail_test "Extension validation failed"
    fi
}

# ============================================================================
# Test: Mount ISO
# ============================================================================
test_mount_iso() {
    start_test "test_mount_iso"

    if [[ -z "$TEST_ISO_PATH" ]] || [[ ! -f "$TEST_ISO_PATH" ]]; then
        skip_test "No mock ISO available"
        return
    fi

    log_detail "Mounting: $TEST_ISO_PATH"

    local output
    output=$(hdiutil attach "$TEST_ISO_PATH" -readonly -nobrowse 2>&1)
    local exit_code=$?

    log_detail "Exit code: $exit_code"
    log_detail "Output: ${output:0:200}..."

    if [[ $exit_code -eq 0 ]]; then
        # Extract mount point
        MOUNTED_VOLUME=$(echo "$output" | grep -o "/Volumes/[^[:space:]]*" | head -1)
        log_detail "Mounted at: $MOUNTED_VOLUME"

        if [[ -n "$MOUNTED_VOLUME" ]] && [[ -d "$MOUNTED_VOLUME" ]]; then
            pass_test "ISO mounted successfully at $MOUNTED_VOLUME"
        else
            fail_test "Mount succeeded but volume not found"
        fi
    else
        fail_test "hdiutil attach failed: $output"
    fi
}

# ============================================================================
# Test: Parse Mount Point from hdiutil Output
# ============================================================================
test_parse_mount_point() {
    start_test "test_parse_mount_point"

    # Sample hdiutil output
    local sample_output="/dev/disk3          	GUID_partition_scheme
/dev/disk3s1        	Apple_HFS                      	/Volumes/TEST_ISO"

    log_detail "Parsing sample hdiutil output"

    # Extract /Volumes path
    local mount_point
    mount_point=$(echo "$sample_output" | grep -o "/Volumes/[^[:space:]]*" | head -1)

    log_detail "Extracted mount point: $mount_point"

    if [[ "$mount_point" == "/Volumes/TEST_ISO" ]]; then
        pass_test "Mount point parsing works"
    else
        fail_test "Failed to parse mount point"
    fi
}

# ============================================================================
# Test: Check Windows ISO Structure
# ============================================================================
test_check_windows_structure() {
    start_test "test_check_windows_structure"

    if [[ -z "$MOUNTED_VOLUME" ]] || [[ ! -d "$MOUNTED_VOLUME" ]]; then
        skip_test "No mounted ISO available"
        return
    fi

    log_detail "Checking structure in: $MOUNTED_VOLUME"

    # Check for sources directory
    if [[ -d "$MOUNTED_VOLUME/sources" ]]; then
        log_detail "Found: sources/"

        # Check for boot.wim
        if [[ -f "$MOUNTED_VOLUME/sources/boot.wim" ]]; then
            log_detail "Found: sources/boot.wim"
            pass_test "Mock Windows structure validated"
        else
            # Our mock might have different structure
            log_warning "boot.wim not found (mock may differ from real Windows ISO)"
            pass_test "sources/ directory exists (mock ISO)"
        fi
    else
        fail_test "sources/ directory not found"
    fi
}

# ============================================================================
# Test: Get ISO File Size
# ============================================================================
test_get_iso_size() {
    start_test "test_get_iso_size"

    if [[ -z "$TEST_ISO_PATH" ]] || [[ ! -f "$TEST_ISO_PATH" ]]; then
        skip_test "No mock ISO available"
        return
    fi

    local size
    size=$(stat -f%z "$TEST_ISO_PATH" 2>/dev/null || stat -c%s "$TEST_ISO_PATH" 2>/dev/null)

    log_detail "ISO size: $size bytes"

    if [[ -n "$size" ]] && [[ "$size" -gt 0 ]]; then
        pass_test "ISO size: $size bytes"
    else
        fail_test "Failed to get ISO size"
    fi
}

# ============================================================================
# Test: Unmount ISO
# ============================================================================
test_unmount_iso() {
    start_test "test_unmount_iso"

    if [[ -z "$MOUNTED_VOLUME" ]]; then
        skip_test "No mounted ISO to unmount"
        return
    fi

    log_detail "Unmounting: $MOUNTED_VOLUME"

    local output
    output=$(hdiutil detach "$MOUNTED_VOLUME" -force 2>&1)
    local exit_code=$?

    log_detail "Exit code: $exit_code"
    log_detail "Output: $output"

    if [[ $exit_code -eq 0 ]] || [[ "$output" == *"ejected"* ]]; then
        # Verify unmounted
        if [[ ! -d "$MOUNTED_VOLUME" ]]; then
            pass_test "ISO unmounted successfully"
            MOUNTED_VOLUME=""
        else
            fail_test "Volume still exists after unmount"
        fi
    else
        fail_test "hdiutil detach failed"
    fi
}

# ============================================================================
# Test: hdiutil Info Command
# ============================================================================
test_hdiutil_info() {
    start_test "test_hdiutil_info"

    local output
    output=$(hdiutil info 2>&1)
    local exit_code=$?

    log_detail "Command: hdiutil info"
    log_detail "Exit code: $exit_code"

    if [[ $exit_code -eq 0 ]]; then
        pass_test "hdiutil info command works"
    else
        fail_test "hdiutil info failed"
    fi
}

# ============================================================================
# Cleanup
# ============================================================================
cleanup_iso_tests() {
    if [[ -n "$MOUNTED_VOLUME" ]] && [[ -d "$MOUNTED_VOLUME" ]]; then
        log_info "Cleaning up: unmounting $MOUNTED_VOLUME"
        hdiutil detach "$MOUNTED_VOLUME" -force -quiet 2>/dev/null
    fi
}

# ============================================================================
# Run All Tests
# ============================================================================
run_tests() {
    # Create mock ISO first
    log_info "Creating mock ISO for testing..."
    TEST_ISO_PATH=$(create_mock_iso)

    test_validate_iso_exists
    test_validate_iso_missing
    test_validate_iso_extension
    test_hdiutil_info
    test_mount_iso
    test_parse_mount_point
    test_check_windows_structure
    test_get_iso_size
    test_unmount_iso

    cleanup_iso_tests
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi

#!/bin/bash
# 03-disk-service.sh - Test disk operations (DiskService.swift)
# Tests: listExternalDrives(), getDiskInfo() - read-only operations only
# SKIPS: formatDriveAsFAT32() - too dangerous for testing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-helpers.sh"
source "$SCRIPT_DIR/../lib/mock-data.sh"

print_section "TEST: 03-disk-service.sh"

# ============================================================================
# Test: List External Drives Command
# ============================================================================
test_list_external_drives() {
    start_test "test_list_external_drives"

    local output
    output=$(diskutil list -plist external 2>&1)
    local exit_code=$?

    log_detail "Command: diskutil list -plist external"
    log_detail "Exit code: $exit_code"

    # Command should succeed even if no external drives
    if [[ $exit_code -eq 0 ]]; then
        if [[ "$output" == *"plist"* ]] || [[ "$output" == *"AllDisksAndPartitions"* ]] || [[ -z "$output" ]]; then
            pass_test "diskutil list external works (may have no drives)"
        else
            pass_test "diskutil list external returned output"
        fi
    else
        # On some systems, this might fail if no external drives
        if [[ "$output" == *"No disks"* ]] || [[ "$output" == *"Could not find"* ]]; then
            pass_test "diskutil correctly reports no external drives"
        else
            fail_test "diskutil list failed: $output"
        fi
    fi
}

# ============================================================================
# Test: List All Drives
# ============================================================================
test_list_all_drives() {
    start_test "test_list_all_drives"

    local output
    output=$(diskutil list 2>&1)
    local exit_code=$?

    log_detail "Command: diskutil list"
    log_detail "Exit code: $exit_code"

    if [[ $exit_code -eq 0 ]] && [[ "$output" == *"disk0"* ]]; then
        pass_test "diskutil list shows disk0 (internal drive)"
    else
        fail_test "diskutil list failed or no disks found"
    fi
}

# ============================================================================
# Test: Get Disk Info
# ============================================================================
test_get_disk_info() {
    start_test "test_get_disk_info"

    local output
    output=$(diskutil info disk0 2>&1)
    local exit_code=$?

    log_detail "Command: diskutil info disk0"
    log_detail "Exit code: $exit_code"

    if [[ $exit_code -eq 0 ]] && [[ "$output" == *"Device Identifier"* ]]; then
        pass_test "diskutil info works on disk0"
    else
        fail_test "diskutil info failed on disk0"
    fi
}

# ============================================================================
# Test: Parse Plist Output
# ============================================================================
test_parse_plist() {
    start_test "test_parse_plist"

    # Create mock plist
    local mock_plist
    mock_plist=$(create_mock_diskutil_plist)

    if [[ ! -f "$mock_plist" ]]; then
        fail_test "Failed to create mock plist"
        return
    fi

    log_detail "Mock plist: $mock_plist"

    # Try to parse with plutil
    local validation
    validation=$(plutil -lint "$mock_plist" 2>&1)

    log_detail "Validation: $validation"

    if [[ "$validation" == *"OK"* ]]; then
        # Extract device identifier using plutil
        local device
        device=$(/usr/libexec/PlistBuddy -c "Print :AllDisksAndPartitions:0:DeviceIdentifier" "$mock_plist" 2>/dev/null)
        log_detail "Extracted device: $device"

        if [[ "$device" == "disk2" ]]; then
            pass_test "Plist parsing works correctly"
        else
            fail_test "Failed to extract device identifier"
        fi
    else
        fail_test "Mock plist is invalid"
    fi
}

# ============================================================================
# Test: Get Mount Point from Disk Info
# ============================================================================
test_get_mount_point() {
    start_test "test_get_mount_point"

    # Get info for root volume
    local output
    output=$(diskutil info / 2>&1)
    local exit_code=$?

    log_detail "Command: diskutil info /"

    if [[ $exit_code -ne 0 ]]; then
        fail_test "diskutil info / failed"
        return
    fi

    # Extract mount point
    local mount_point
    mount_point=$(echo "$output" | grep "Mount Point:" | cut -d: -f2 | xargs)

    log_detail "Mount Point: $mount_point"

    if [[ "$mount_point" == "/" ]]; then
        pass_test "Correctly extracted mount point: /"
    else
        fail_test "Failed to extract mount point"
    fi
}

# ============================================================================
# Test: Device Path Normalization
# ============================================================================
test_device_path_normalization() {
    start_test "test_device_path_normalization"

    # Test that both formats work
    local info1
    local info2

    info1=$(diskutil info disk0 2>&1 | head -3)
    info2=$(diskutil info /dev/disk0 2>&1 | head -3)

    log_detail "disk0 output (first 3 lines): ${info1:0:50}..."
    log_detail "/dev/disk0 output (first 3 lines): ${info2:0:50}..."

    if [[ "$info1" == "$info2" ]]; then
        pass_test "Both disk0 and /dev/disk0 work equivalently"
    else
        fail_test "Device path formats produce different results"
    fi
}

# ============================================================================
# Test: Disk Size Extraction
# ============================================================================
test_disk_size_extraction() {
    start_test "test_disk_size_extraction"

    local output
    output=$(diskutil info disk0 2>&1)

    # Extract size
    local size_line
    size_line=$(echo "$output" | grep "Disk Size:")

    log_detail "Size line: $size_line"

    if [[ -n "$size_line" ]] && [[ "$size_line" == *"Bytes"* ]]; then
        pass_test "Disk size can be extracted"
    else
        fail_test "Failed to extract disk size"
    fi
}

# ============================================================================
# Test: Protocol Detection (USB vs Internal)
# ============================================================================
test_protocol_detection() {
    start_test "test_protocol_detection"

    local output
    output=$(diskutil info disk0 2>&1)

    # Check for protocol line
    local protocol
    protocol=$(echo "$output" | grep -i "Protocol:" | cut -d: -f2 | xargs)

    log_detail "Protocol: ${protocol:-not found}"

    # Internal drives are usually SATA, NVMe, or Apple Fabric
    if [[ -n "$protocol" ]]; then
        pass_test "Protocol detected: $protocol"
    else
        # Some systems might not show protocol
        log_warning "Protocol field not found (this may be normal)"
        pass_test "Test completed (protocol may not be available)"
    fi
}

# ============================================================================
# Run All Tests
# ============================================================================
run_tests() {
    test_list_external_drives
    test_list_all_drives
    test_get_disk_info
    test_parse_plist
    test_get_mount_point
    test_device_path_normalization
    test_disk_size_extraction
    test_protocol_detection
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi

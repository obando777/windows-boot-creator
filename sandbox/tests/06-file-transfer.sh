#!/bin/bash
# 06-file-transfer.sh - Test file transfer operations (FileTransferService.swift)
# Tests: copyWindowsFiles(), copySplitWimFiles()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-helpers.sh"
source "$SCRIPT_DIR/../lib/mock-data.sh"

print_section "TEST: 06-file-transfer.sh"

# Test paths
SOURCE_DIR=""
DEST_DIR=""
SWM_DIR=""

# ============================================================================
# Test: rsync Command Availability
# ============================================================================
test_rsync_available() {
    start_test "test_rsync_available"

    local rsync_path
    rsync_path=$(which rsync 2>/dev/null)

    log_detail "Command: which rsync"
    log_detail "Result: ${rsync_path:-not found}"

    if [[ -n "$rsync_path" ]]; then
        local version
        version=$(rsync --version | head -1)
        log_detail "Version: $version"
        pass_test "rsync available at: $rsync_path"
    else
        fail_test "rsync not found (required for file transfers)"
    fi
}

# ============================================================================
# Test: Copy Files with rsync
# ============================================================================
test_copy_files() {
    start_test "test_copy_files"

    if [[ -z "$SOURCE_DIR" ]] || [[ -z "$DEST_DIR" ]]; then
        skip_test "Mock directories not created"
        return
    fi

    log_detail "Source: $SOURCE_DIR"
    log_detail "Destination: $DEST_DIR"

    # Run rsync
    local output
    output=$(rsync -av "$SOURCE_DIR/" "$DEST_DIR/" 2>&1)
    local exit_code=$?

    log_detail "Exit code: $exit_code"

    if [[ $exit_code -eq 0 ]]; then
        # Verify some files were copied
        local copied_count
        copied_count=$(find "$DEST_DIR" -type f | wc -l | xargs)
        log_detail "Files copied: $copied_count"

        if [[ "$copied_count" -gt 0 ]]; then
            pass_test "rsync copied $copied_count files successfully"
        else
            fail_test "rsync succeeded but no files copied"
        fi
    else
        fail_test "rsync failed: $output"
    fi
}

# ============================================================================
# Test: Copy with Exclude Pattern
# ============================================================================
test_copy_with_exclude() {
    start_test "test_copy_with_exclude"

    if [[ -z "$SOURCE_DIR" ]]; then
        skip_test "Mock source not created"
        return
    fi

    # Create a new destination for this test
    local exclude_dest="$FIXTURES_DIR/exclude_test_dest"
    mkdir -p "$exclude_dest"
    register_cleanup "$exclude_dest"

    log_detail "Testing exclude pattern for install.wim"

    # Create a file to exclude
    mkdir -p "$SOURCE_DIR/sources"
    echo "This should be excluded" > "$SOURCE_DIR/sources/install.wim"

    # Run rsync with exclude
    local output
    output=$(rsync -av --exclude='sources/install.wim' "$SOURCE_DIR/" "$exclude_dest/" 2>&1)
    local exit_code=$?

    log_detail "Exit code: $exit_code"

    if [[ $exit_code -eq 0 ]]; then
        # Check that install.wim was NOT copied
        if [[ ! -f "$exclude_dest/sources/install.wim" ]]; then
            pass_test "Exclude pattern worked - install.wim not copied"
        else
            fail_test "Exclude failed - install.wim was copied"
        fi
    else
        fail_test "rsync with exclude failed"
    fi
}

# ============================================================================
# Test: Calculate Total Size
# ============================================================================
test_calculate_size() {
    start_test "test_calculate_size"

    if [[ -z "$SOURCE_DIR" ]]; then
        skip_test "Mock source not created"
        return
    fi

    log_detail "Calculating size of: $SOURCE_DIR"

    # Method 1: du command
    local du_size
    du_size=$(du -sk "$SOURCE_DIR" 2>/dev/null | cut -f1)
    log_detail "du -sk result: ${du_size}KB"

    # Method 2: rsync dry-run stats
    local rsync_output
    rsync_output=$(rsync -an --stats "$SOURCE_DIR/" /dev/null 2>/dev/null | grep "Total file size")
    log_detail "rsync stats: $rsync_output"

    if [[ -n "$du_size" ]] && [[ "$du_size" -gt 0 ]]; then
        pass_test "Size calculation works: ${du_size}KB"
    else
        fail_test "Failed to calculate directory size"
    fi
}

# ============================================================================
# Test: Parse rsync Progress Output
# ============================================================================
test_parse_rsync_progress() {
    start_test "test_parse_rsync_progress"

    # Sample rsync progress output
    local sample_outputs=(
        "    1,234,567 100%   12.34MB/s    0:00:00"
        "      524,288  50%    5.00MB/s    0:00:01"
        "  123,456,789  75%   50.00MB/s    0:00:02"
    )

    local all_parsed=true

    for output in "${sample_outputs[@]}"; do
        # Extract bytes (first number with commas)
        local bytes
        bytes=$(echo "$output" | awk '{print $1}' | tr -d ',')

        log_detail "Input: '$output'"
        log_detail "Parsed bytes: ${bytes:-none}"

        if [[ -z "$bytes" ]] || ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
            all_parsed=false
        fi
    done

    if [[ "$all_parsed" == "true" ]]; then
        pass_test "rsync progress parsing works"
    else
        fail_test "Some progress outputs failed to parse"
    fi
}

# ============================================================================
# Test: Copy SWM Files
# ============================================================================
test_copy_swm_files() {
    start_test "test_copy_swm_files"

    if [[ -z "$SWM_DIR" ]]; then
        skip_test "Mock SWM directory not created"
        return
    fi

    # Create destination with sources directory
    local swm_dest="$FIXTURES_DIR/swm_copy_dest"
    mkdir -p "$swm_dest/sources"
    register_cleanup "$swm_dest"

    log_detail "SWM source: $SWM_DIR"
    log_detail "Destination: $swm_dest/sources"

    # Copy each .swm file
    local copied=0
    for swm in "$SWM_DIR"/*.swm; do
        if [[ -f "$swm" ]]; then
            local filename=$(basename "$swm")
            rsync -av "$swm" "$swm_dest/sources/$filename" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                ((copied++))
            fi
        fi
    done

    log_detail "SWM files copied: $copied"

    if [[ "$copied" -gt 0 ]]; then
        # Verify files exist
        local found
        found=$(find "$swm_dest/sources" -name "*.swm" | wc -l | xargs)
        log_detail "SWM files at destination: $found"

        if [[ "$found" -eq "$copied" ]]; then
            pass_test "Copied $copied SWM files successfully"
        else
            fail_test "Copy count mismatch"
        fi
    else
        fail_test "No SWM files copied"
    fi
}

# ============================================================================
# Test: Verify Copied Files
# ============================================================================
test_verify_copied_files() {
    start_test "test_verify_copied_files"

    if [[ -z "$DEST_DIR" ]]; then
        skip_test "Mock destination not created"
        return
    fi

    log_detail "Verifying files in: $DEST_DIR"

    # Check for expected structure
    local checks_passed=0
    local total_checks=3

    # Check 1: sources directory exists
    if [[ -d "$DEST_DIR/sources" ]]; then
        log_detail "✓ sources/ directory exists"
        ((checks_passed++))
    else
        log_detail "✗ sources/ directory missing"
    fi

    # Check 2: boot directory exists
    if [[ -d "$DEST_DIR/boot" ]]; then
        log_detail "✓ boot/ directory exists"
        ((checks_passed++))
    else
        log_detail "✗ boot/ directory missing"
    fi

    # Check 3: At least one file exists
    local file_count
    file_count=$(find "$DEST_DIR" -type f | wc -l | xargs)
    if [[ "$file_count" -gt 0 ]]; then
        log_detail "✓ Found $file_count files"
        ((checks_passed++))
    else
        log_detail "✗ No files found"
    fi

    if [[ "$checks_passed" -eq "$total_checks" ]]; then
        pass_test "All $total_checks verification checks passed"
    else
        fail_test "Only $checks_passed/$total_checks checks passed"
    fi
}

# ============================================================================
# Test: rsync with Progress Flag
# ============================================================================
test_rsync_progress_flag() {
    start_test "test_rsync_progress_flag"

    if [[ -z "$SOURCE_DIR" ]]; then
        skip_test "Mock source not created"
        return
    fi

    local progress_dest="$FIXTURES_DIR/progress_test_dest"
    mkdir -p "$progress_dest"
    register_cleanup "$progress_dest"

    # Test that --progress flag is accepted
    local output
    output=$(rsync -av --progress "$SOURCE_DIR/" "$progress_dest/" 2>&1)
    local exit_code=$?

    log_detail "Exit code: $exit_code"

    if [[ $exit_code -eq 0 ]]; then
        pass_test "rsync --progress flag works"
    else
        fail_test "rsync --progress failed"
    fi
}

# ============================================================================
# Test: File Size After Copy
# ============================================================================
test_file_size_preservation() {
    start_test "test_file_size_preservation"

    if [[ -z "$SOURCE_DIR" ]]; then
        skip_test "Mock source directory not available"
        return
    fi

    # Use fresh destination directory to get accurate size comparison
    local fresh_dest="$FIXTURES_DIR/size_test_dest"
    rm -rf "$fresh_dest" 2>/dev/null
    mkdir -p "$fresh_dest"
    register_cleanup "$fresh_dest"

    # Copy files to fresh destination
    rsync -a "$SOURCE_DIR/" "$fresh_dest/" 2>/dev/null

    # Get source size
    local source_size
    source_size=$(du -sk "$SOURCE_DIR" 2>/dev/null | cut -f1)

    # Get destination size
    local dest_size
    dest_size=$(du -sk "$fresh_dest" 2>/dev/null | cut -f1)

    log_detail "Source size: ${source_size}KB"
    log_detail "Destination size: ${dest_size}KB"

    # Sizes should be approximately equal (allowing for filesystem differences)
    local diff=$((source_size - dest_size))
    diff=${diff#-}  # Absolute value

    if [[ "$diff" -lt 100 ]]; then  # Within 100KB tolerance
        pass_test "File sizes preserved (diff: ${diff}KB)"
    else
        fail_test "Size mismatch: ${diff}KB difference"
    fi
}

# ============================================================================
# Run All Tests
# ============================================================================
run_tests() {
    # Create mock data first
    log_info "Creating mock data for file transfer tests..."
    SOURCE_DIR=$(create_mock_windows_dir)
    DEST_DIR=$(create_mock_destination)
    SWM_DIR=$(create_mock_split_wim_files)

    test_rsync_available
    test_copy_files
    test_copy_with_exclude
    test_calculate_size
    test_parse_rsync_progress
    test_copy_swm_files
    test_verify_copied_files
    test_rsync_progress_flag
    test_file_size_preservation
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi

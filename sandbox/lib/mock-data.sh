#!/bin/bash
# mock-data.sh - Functions to create mock test data
# Part of WindowsBootCreator sandbox testing

SANDBOX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES_DIR="$SANDBOX_DIR/fixtures"
MOCK_ISO_PATH=""
MOCK_WIN_DIR=""
MOCK_WIM_PATH=""
MOCK_DEST_DIR=""

# ============================================================================
# Mock ISO Creation
# ============================================================================

create_mock_iso() {
    local iso_name="${1:-test.iso}"
    local temp_dir="$FIXTURES_DIR/mock_win_contents"
    MOCK_ISO_PATH="$FIXTURES_DIR/$iso_name"

    log_info "Creating mock ISO at $MOCK_ISO_PATH..." >&2

    # Create directory structure mimicking Windows ISO
    mkdir -p "$temp_dir/sources"
    mkdir -p "$temp_dir/boot"
    mkdir -p "$temp_dir/efi/boot"

    # Create fake Windows files
    echo "Mock boot.wim content - this simulates the Windows boot image" > "$temp_dir/sources/boot.wim"
    echo "Mock bootmgr content" > "$temp_dir/bootmgr"
    echo "Mock bootmgr.efi content" > "$temp_dir/efi/boot/bootx64.efi"

    # Create a small fake install.wim (not >4GB, just for testing)
    dd if=/dev/zero of="$temp_dir/sources/install.wim" bs=1024 count=100 2>/dev/null
    echo "MSWIM" | dd of="$temp_dir/sources/install.wim" bs=1 count=5 conv=notrunc 2>/dev/null

    # Create ISO using hdiutil (outputs .dmg file)
    local dmg_path="${MOCK_ISO_PATH%.iso}.dmg"
    if hdiutil create -srcfolder "$temp_dir" -format UDRO -o "${dmg_path%.dmg}" -quiet 2>/dev/null; then
        # Rename .dmg to .iso for test compatibility
        mv "$dmg_path" "$MOCK_ISO_PATH" 2>/dev/null
        log_success "Mock ISO created: $MOCK_ISO_PATH" >&2
        register_cleanup "$MOCK_ISO_PATH"
        register_cleanup "$temp_dir"
        echo "$MOCK_ISO_PATH"
        return 0
    else
        log_error "Failed to create mock ISO" >&2
        return 1
    fi
}

# ============================================================================
# Mock Windows Directory Structure
# ============================================================================

create_mock_windows_dir() {
    local dir_name="${1:-mock_mounted_iso}"
    MOCK_WIN_DIR="$FIXTURES_DIR/$dir_name"

    log_info "Creating mock Windows directory at $MOCK_WIN_DIR..." >&2

    # Create directory structure
    mkdir -p "$MOCK_WIN_DIR/sources"
    mkdir -p "$MOCK_WIN_DIR/boot"
    mkdir -p "$MOCK_WIN_DIR/efi/boot"
    mkdir -p "$MOCK_WIN_DIR/support"

    # Create mock files with some content
    echo "Boot Windows Image Manager" > "$MOCK_WIN_DIR/sources/boot.wim"
    dd if=/dev/zero of="$MOCK_WIN_DIR/sources/install.wim" bs=1024 count=500 2>/dev/null

    echo "Windows Boot Manager" > "$MOCK_WIN_DIR/bootmgr"
    echo "EFI Boot" > "$MOCK_WIN_DIR/efi/boot/bootx64.efi"

    # Create some additional files for transfer testing
    for i in {1..5}; do
        echo "Support file $i content" > "$MOCK_WIN_DIR/support/file$i.txt"
    done

    register_cleanup "$MOCK_WIN_DIR"
    log_success "Mock Windows directory created" >&2
    echo "$MOCK_WIN_DIR"
}

# ============================================================================
# Mock WIM File
# ============================================================================

create_mock_wim() {
    local wim_name="${1:-test.wim}"
    local size_kb="${2:-1024}"  # Default 1MB
    MOCK_WIM_PATH="$FIXTURES_DIR/$wim_name"

    log_info "Creating mock WIM file at $MOCK_WIM_PATH (${size_kb}KB)..." >&2

    # Create a file with WIM-like header
    dd if=/dev/zero of="$MOCK_WIM_PATH" bs=1024 count="$size_kb" 2>/dev/null

    # Write WIM magic header "MSWIM\0\0\0" at beginning
    printf 'MSWIM\x00\x00\x00' | dd of="$MOCK_WIM_PATH" bs=1 count=8 conv=notrunc 2>/dev/null

    register_cleanup "$MOCK_WIM_PATH"
    log_success "Mock WIM file created" >&2
    echo "$MOCK_WIM_PATH"
}

# ============================================================================
# Mock Destination Directory
# ============================================================================

create_mock_destination() {
    local dir_name="${1:-mock_usb_dest}"
    MOCK_DEST_DIR="$FIXTURES_DIR/$dir_name"

    log_info "Creating mock destination directory at $MOCK_DEST_DIR..." >&2

    mkdir -p "$MOCK_DEST_DIR"

    register_cleanup "$MOCK_DEST_DIR"
    log_success "Mock destination directory created" >&2
    echo "$MOCK_DEST_DIR"
}

# ============================================================================
# Mock Split WIM Files
# ============================================================================

create_mock_split_wim_files() {
    local dir_name="${1:-mock_split_wims}"
    local split_dir="$FIXTURES_DIR/$dir_name"

    log_info "Creating mock split WIM files at $split_dir..." >&2

    mkdir -p "$split_dir"

    # Create 3 fake .swm files
    for i in {1..3}; do
        local swm_file="$split_dir/install$i.swm"
        dd if=/dev/zero of="$swm_file" bs=1024 count=100 2>/dev/null
        printf 'MSWIM\x00\x00\x00' | dd of="$swm_file" bs=1 count=8 conv=notrunc 2>/dev/null
    done

    register_cleanup "$split_dir"
    log_success "Mock split WIM files created" >&2
    echo "$split_dir"
}

# ============================================================================
# Sample diskutil Output
# ============================================================================

create_mock_diskutil_plist() {
    local output_file="$FIXTURES_DIR/mock_diskutil.plist"

    log_info "Creating mock diskutil plist..." >&2

    cat > "$output_file" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AllDisksAndPartitions</key>
    <array>
        <dict>
            <key>DeviceIdentifier</key>
            <string>disk2</string>
            <key>Size</key>
            <integer>16000000000</integer>
            <key>VolumeName</key>
            <string>SANDISK</string>
            <key>Content</key>
            <string>FDisk_partition_scheme</string>
        </dict>
    </array>
</dict>
</plist>
EOF

    register_cleanup "$output_file"
    log_success "Mock diskutil plist created" >&2
    echo "$output_file"
}

# ============================================================================
# Initialize All Mock Data
# ============================================================================

init_all_mock_data() {
    log_info "Initializing all mock test data..." >&2

    # Ensure fixtures directory exists
    mkdir -p "$FIXTURES_DIR"

    create_mock_iso
    create_mock_windows_dir
    create_mock_wim
    create_mock_destination
    create_mock_diskutil_plist

    log_success "All mock data initialized" >&2
}

# ============================================================================
# Cleanup Mock Data
# ============================================================================

cleanup_mock_data() {
    log_info "Cleaning up mock data..." >&2

    # Unmount any mounted ISOs first
    if [[ -n "$MOCK_ISO_PATH" ]]; then
        local mount_point
        mount_point=$(hdiutil info | grep -A 1 "$MOCK_ISO_PATH" | grep "/Volumes" | awk '{print $1}')
        if [[ -n "$mount_point" ]]; then
            hdiutil detach "$mount_point" -quiet 2>/dev/null
        fi
    fi

    # Remove fixtures directory
    if [[ -d "$FIXTURES_DIR" ]]; then
        rm -rf "$FIXTURES_DIR"/*
    fi

    log_success "Mock data cleaned up" >&2
}

# Export paths for use in tests
export FIXTURES_DIR MOCK_ISO_PATH MOCK_WIN_DIR MOCK_WIM_PATH MOCK_DEST_DIR

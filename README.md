# Windows Boot Creator

A native macOS application that creates bootable Windows 10/11 USB installation drives from ISO files. Built with SwiftUI, it provides a guided wizard interface that handles the complexities of formatting, file transfer, and large file splitting automatically.

## Features

- **Guided Wizard Interface** — Step-by-step process with clear progress indicators
- **Automatic Large File Handling** — Splits WIM/ESD files larger than 4GB for FAT32 compatibility
- **Real-time Progress Tracking** — Live updates showing file transfer progress and byte counts
- **Smart Validation** — Validates ISO files, checks USB drive capacity (8GB minimum), and verifies Windows installation files
- **Dependency Management** — Automatically detects and offers to install wimlib via Homebrew
- **Safe Operations** — Only shows external drives, requires confirmation before formatting

## Requirements

- macOS 13.0 (Ventura) or later
- [Homebrew](https://brew.sh) (for installing wimlib)
- A Windows 10 or 11 ISO file
- USB drive with at least 8GB capacity

## Installation

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/windows-boot-creator.git
cd windows-boot-creator

# Build the application
./build.sh release

# Run the application
./build.sh run-release
```

### Build Commands

| Command | Description |
|---------|-------------|
| `./build.sh debug` | Build debug version (default) |
| `./build.sh release` | Build optimized release version |
| `./build.sh run` | Build and run debug version |
| `./build.sh run-release` | Build and run release version |
| `./build.sh clean` | Remove build artifacts |
| `./build.sh test` | Run integration tests |

## Usage

1. **Launch the application** and wait for dependency check
2. **Select your Windows ISO** file using the file picker
3. **Choose your USB drive** from the list of available external drives
4. **Review and confirm** your selections
5. **Wait for completion** — the app will format, copy files, and handle large file splitting
6. **Eject the drive** when finished

> **Note:** The application requires administrator privileges to format drives and copy system files.

## How It Works

Windows Boot Creator automates the process of creating a bootable Windows USB:

1. **Formats the USB drive** as FAT32 with MBR partition scheme (required for UEFI boot)
2. **Mounts the Windows ISO** using macOS hdiutil
3. **Copies all files** from the ISO to the USB drive using rsync
4. **Splits large files** — Windows install images (install.wim/esd) often exceed FAT32's 4GB file limit; the app uses wimlib to split these automatically
5. **Cleans up** by unmounting the ISO and optionally ejecting the USB

## Project Structure

```
windows-boot-creator/
├── WindowsBootCreator/
│   ├── Models/          # Data structures (WizardStep, USBDrive, CreationProgress)
│   ├── ViewModels/      # State management (BootCreatorViewModel)
│   ├── Views/           # SwiftUI screens for each wizard step
│   ├── Services/        # Business logic (Disk, ISO, WIM, FileTransfer)
│   └── Utilities/       # Shell execution and disk parsing
├── Package.swift        # Swift Package Manager configuration
├── build.sh            # Build automation script
└── sandbox/tests/      # Integration test suites
```

## Technologies

- **Swift 5.9+** with modern async/await concurrency
- **SwiftUI** for the user interface
- **Swift Package Manager** for building
- **Actor pattern** for thread-safe service operations

### External Tools Used

- `diskutil` — macOS disk management
- `hdiutil` — ISO mounting/unmounting
- `rsync` — File copying with progress
- `wimlib-imagex` — WIM file splitting (installed via Homebrew)

## Testing

Run the integration test suite:

```bash
./build.sh test
```

Tests cover all core services:
- ShellExecutor
- DependencyService
- DiskService
- ISOService
- WimService
- FileTransferService

## License

MIT License — See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

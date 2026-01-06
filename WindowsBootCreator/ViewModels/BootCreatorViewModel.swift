import Foundation
import SwiftUI

@MainActor
class BootCreatorViewModel: ObservableObject {

    @Published var currentStep: WizardStep = .welcome
    @Published var availableDrives: [USBDrive] = []
    @Published var selectedDrive: USBDrive?
    @Published var selectedISOPath: String?
    @Published var isoInfo: ISOInfo?
    @Published var progress: CreationProgress = CreationProgress()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    @Published var wimlibStatus: DependencyStatus = .notInstalled
    @Published var isInstallingWimlib = false
    @Published var installProgress: String = ""

    private var tempDirectory: String?

    init() {
        Task {
            await checkDependencies()
        }
    }

    func checkDependencies() async {
        wimlibStatus = await DependencyService.shared.checkWimlib()
    }

    func installWimlib() async {
        isInstallingWimlib = true
        installProgress = "Checking Homebrew..."

        do {
            try await DependencyService.shared.installWimlib { [weak self] progress in
                Task { @MainActor in
                    self?.installProgress = progress
                }
            }
            wimlibStatus = .installed
            installProgress = "Installation complete!"
        } catch {
            wimlibStatus = .installFailed(error.localizedDescription)
            showError(error.localizedDescription)
        }

        isInstallingWimlib = false
    }

    func refreshDrives() async {
        isLoading = true
        defer { isLoading = false }

        do {
            availableDrives = try await DiskService.shared.listExternalDrives()
            if let selected = selectedDrive,
               !availableDrives.contains(where: { $0.id == selected.id }) {
                selectedDrive = nil
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    func selectISO(at url: URL) async {
        isLoading = true
        defer { isLoading = false }

        do {
            selectedISOPath = url.path
            isoInfo = try await ISOService.shared.validateISO(at: url.path)
        } catch {
            selectedISOPath = nil
            isoInfo = nil
            showError(error.localizedDescription)
        }
    }

    func goToNextStep() {
        guard let next = currentStep.nextStep else { return }
        currentStep = next

        if next == .selectUSB {
            Task { await refreshDrives() }
        }
    }

    func goToPreviousStep() {
        guard currentStep.canGoBack, let prev = currentStep.previousStep else { return }
        currentStep = prev
    }

    func startCreation() async {
        guard let isoPath = selectedISOPath,
              let drive = selectedDrive else {
            showError("Please select both an ISO and a USB drive")
            return
        }

        currentStep = .progress
        progress = CreationProgress()

        do {
            progress.updateStage(.formatting)
            try await DiskService.shared.formatDriveAsFAT32(deviceNode: drive.deviceNode)

            try await Task.sleep(nanoseconds: 2_000_000_000)

            progress.updateStage(.mountingISO)
            let mountedISO = try await ISOService.shared.mountISO(at: isoPath)

            guard let isoMount = mountedISO.mountPoint else {
                throw CreationError.isoMountFailed
            }

            let partition = try await DiskService.shared.getFirstPartition(of: drive.deviceNode)
            guard let usbMount = try await DiskService.shared.getMountPoint(for: partition) else {
                throw CreationError.usbNotMounted
            }

            progress.updateStage(.copyingBootFiles)
            try await FileTransferService.shared.copyWindowsFiles(
                from: isoMount,
                to: usbMount,
                excludeInstallWim: mountedISO.needsWimSplit
            ) { [weak self] transferred, total, file in
                Task { @MainActor in
                    self?.progress.updateProgress(transferred: transferred, total: total, file: file)
                }
            }

            if mountedISO.needsWimSplit {
                progress.updateStage(.splittingWIM)

                let tempDir = NSTemporaryDirectory() + "WindowsBootCreator_\(UUID().uuidString)"
                tempDirectory = tempDir
                try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

                let wimPath = "\(isoMount)/sources/install.wim"
                let esdPath = "\(isoMount)/sources/install.esd"
                let sourcePath = FileManager.default.fileExists(atPath: wimPath) ? wimPath : esdPath

                try await WimService.shared.splitWimFile(
                    sourcePath: sourcePath,
                    destinationDirectory: tempDir
                ) { [weak self] splitProgress, status in
                    Task { @MainActor in
                        self?.progress.stageProgress = splitProgress
                        self?.progress.currentFile = status
                    }
                }

                progress.updateStage(.copyingWIM)
                try await FileTransferService.shared.copySplitWimFiles(
                    from: tempDir,
                    to: usbMount
                ) { [weak self] transferred, total, file in
                    Task { @MainActor in
                        self?.progress.updateProgress(transferred: transferred, total: total, file: file)
                    }
                }

                try? FileManager.default.removeItem(atPath: tempDir)
                tempDirectory = nil
            }

            progress.updateStage(.finalizing)
            try await ISOService.shared.unmountISO(at: isoPath)

            progress.updateStage(.complete)
            currentStep = .complete

        } catch {
            progress.fail(with: error.localizedDescription)
            showError(error.localizedDescription)
        }
    }

    func cancelCreation() async {
        await FileTransferService.shared.cancelTransfer()

        if let isoPath = selectedISOPath {
            try? await ISOService.shared.unmountISO(at: isoPath)
        }

        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        progress.fail(with: "Operation cancelled by user")
    }

    func reset() {
        currentStep = .welcome
        selectedDrive = nil
        selectedISOPath = nil
        isoInfo = nil
        progress = CreationProgress()
        errorMessage = nil
        showError = false
    }

    func ejectDrive() async {
        guard let drive = selectedDrive else { return }

        do {
            try await DiskService.shared.ejectDisk(deviceNode: drive.deviceNode)
        } catch {
            showError(error.localizedDescription)
        }
    }

    var canProceedFromWelcome: Bool {
        wimlibStatus == .installed
    }

    var canProceedFromISO: Bool {
        isoInfo != nil
    }

    var canProceedFromUSB: Bool {
        selectedDrive != nil && (selectedDrive?.isValidForWindows ?? false)
    }

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

enum CreationError: Error, LocalizedError {
    case isoMountFailed
    case usbNotMounted
    case copyFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .isoMountFailed:
            return "Failed to mount the Windows ISO"
        case .usbNotMounted:
            return "USB drive is not mounted after formatting"
        case .copyFailed:
            return "Failed to copy files to USB"
        case .cancelled:
            return "Operation was cancelled"
        }
    }
}

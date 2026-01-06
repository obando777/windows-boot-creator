import Foundation

actor FileTransferService {
    static let shared = FileTransferService()

    private var isCancelled = false

    private init() {}

    func cancelTransfer() {
        isCancelled = true
    }

    func resetCancellation() {
        isCancelled = false
    }

    func copyWindowsFiles(
        from sourceMount: String,
        to destinationMount: String,
        excludeInstallWim: Bool = true,
        progressHandler: @escaping (UInt64, UInt64, String) -> Void
    ) async throws {
        isCancelled = false

        let excludeArgs = excludeInstallWim
            ? "--exclude='sources/install.wim' --exclude='sources/install.esd'"
            : ""

        let totalSize = try await calculateTotalSize(at: sourceMount, excludeInstallWim: excludeInstallWim)
        progressHandler(0, totalSize, "Starting file copy...")

        let command = "rsync -av --progress \(excludeArgs) \"\(sourceMount)/\" \"\(destinationMount)/\""

        var bytesCopied: UInt64 = 0

        let result = try await ShellExecutor.shared.executeWithOutput(command) { output in
            if self.isCancelled {
                return
            }

            if let (transferred, filename) = self.parseRsyncProgress(from: output) {
                bytesCopied = transferred
                progressHandler(bytesCopied, totalSize, filename)
            }
        }

        if isCancelled {
            throw FileTransferError.cancelled
        }

        if !result.succeeded && !result.error.isEmpty {
            let filteredError = result.error.components(separatedBy: .newlines)
                .filter { !$0.contains("failed to set permissions") }
                .joined(separator: "\n")

            if !filteredError.isEmpty && !filteredError.contains("some files") {
                throw FileTransferError.copyFailed(filteredError)
            }
        }

        progressHandler(totalSize, totalSize, "Copy complete")
    }

    func copySplitWimFiles(
        from splitDirectory: String,
        to destinationMount: String,
        progressHandler: @escaping (UInt64, UInt64, String) -> Void
    ) async throws {
        isCancelled = false

        let fileManager = FileManager.default
        let sourcesDir = "\(destinationMount)/sources"

        if !fileManager.fileExists(atPath: sourcesDir) {
            try fileManager.createDirectory(atPath: sourcesDir, withIntermediateDirectories: true)
        }

        let swmFiles = try fileManager.contentsOfDirectory(atPath: splitDirectory)
            .filter { $0.hasSuffix(".swm") }
            .sorted()

        guard !swmFiles.isEmpty else {
            throw FileTransferError.noFilesToCopy
        }

        var totalSize: UInt64 = 0
        for file in swmFiles {
            let path = "\(splitDirectory)/\(file)"
            let attrs = try fileManager.attributesOfItem(atPath: path)
            totalSize += attrs[.size] as? UInt64 ?? 0
        }

        var bytesCopied: UInt64 = 0

        for file in swmFiles {
            if isCancelled {
                throw FileTransferError.cancelled
            }

            let sourcePath = "\(splitDirectory)/\(file)"
            let destPath = "\(sourcesDir)/\(file)"

            progressHandler(bytesCopied, totalSize, file)

            let command = "rsync -av --progress \"\(sourcePath)\" \"\(destPath)\""

            let result = try await ShellExecutor.shared.executeWithOutput(command) { output in
                if let (fileProgress, _) = self.parseRsyncProgress(from: output) {
                    progressHandler(bytesCopied + fileProgress, totalSize, file)
                }
            }

            if !result.succeeded {
                throw FileTransferError.copyFailed("Failed to copy \(file): \(result.error)")
            }

            let attrs = try fileManager.attributesOfItem(atPath: sourcePath)
            bytesCopied += attrs[.size] as? UInt64 ?? 0
        }

        progressHandler(totalSize, totalSize, "SWM files copied")
    }

    private func calculateTotalSize(at path: String, excludeInstallWim: Bool) async throws -> UInt64 {
        let excludeArg = excludeInstallWim
            ? "--exclude='sources/install.wim' --exclude='sources/install.esd'"
            : ""

        let command = "rsync -an --stats \(excludeArg) \"\(path)/\" /dev/null 2>/dev/null | grep 'Total file size' | awk '{print $4}' | tr -d ','"

        let result = try await ShellExecutor.shared.execute(command)

        if result.succeeded, let size = UInt64(result.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return size
        }

        return try await calculateSizeRecursively(at: path, excludeInstallWim: excludeInstallWim)
    }

    private func calculateSizeRecursively(at path: String, excludeInstallWim: Bool) async throws -> UInt64 {
        var totalSize: UInt64 = 0
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return 0
        }

        while let file = enumerator.nextObject() as? String {
            if excludeInstallWim && (file == "sources/install.wim" || file == "sources/install.esd") {
                continue
            }

            let fullPath = "\(path)/\(file)"
            if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
               let fileType = attrs[.type] as? FileAttributeType,
               fileType == .typeRegular {
                totalSize += attrs[.size] as? UInt64 ?? 0
            }
        }

        return totalSize
    }

    private func parseRsyncProgress(from output: String) -> (UInt64, String)? {
        let lines = output.components(separatedBy: .newlines)

        for line in lines.reversed() {
            if line.contains("%") {
                let components = line.trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }

                if components.count >= 1 {
                    let sizeStr = components[0].replacingOccurrences(of: ",", with: "")
                    if let bytes = UInt64(sizeStr) {
                        return (bytes, "")
                    }
                }
            }

            if !line.trimmingCharacters(in: .whitespaces).isEmpty
                && !line.contains("%")
                && !line.contains("sending")
                && !line.contains("total") {
                return (0, line.trimmingCharacters(in: .whitespaces))
            }
        }

        return nil
    }
}

enum FileTransferError: Error, LocalizedError {
    case copyFailed(String)
    case cancelled
    case noFilesToCopy

    var errorDescription: String? {
        switch self {
        case .copyFailed(let message):
            return "File copy failed: \(message)"
        case .cancelled:
            return "File transfer was cancelled"
        case .noFilesToCopy:
            return "No files to copy"
        }
    }
}

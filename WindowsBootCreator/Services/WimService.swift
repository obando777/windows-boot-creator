import Foundation

actor WimService {
    static let shared = WimService()

    private init() {}

    func splitWimFile(
        sourcePath: String,
        destinationDirectory: String,
        maxSizeMB: Int = 3800,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws {
        let sourceFileName = (sourcePath as NSString).lastPathComponent
        let baseName = (sourceFileName as NSString).deletingPathExtension
        let destPattern = "\(destinationDirectory)/\(baseName).swm"

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sourcePath) else {
            throw WimError.sourceNotFound
        }

        if !fileManager.fileExists(atPath: destinationDirectory) {
            try fileManager.createDirectory(atPath: destinationDirectory, withIntermediateDirectories: true)
        }

        progressHandler(0.0, "Starting WIM split...")

        let command = "wimlib-imagex split \"\(sourcePath)\" \"\(destPattern)\" \(maxSizeMB)"

        var lastProgress = 0.0

        let result = try await ShellExecutor.shared.executeWithOutput(command) { output in
            if let progress = self.parseProgress(from: output) {
                lastProgress = progress
                progressHandler(progress, "Splitting: \(Int(progress * 100))%")
            }
        }

        if !result.succeeded {
            if result.error.contains("wimlib-imagex: command not found") {
                throw WimError.wimlibNotInstalled
            }
            throw WimError.splitFailed(result.error)
        }

        let splitFiles = try fileManager.contentsOfDirectory(atPath: destinationDirectory)
            .filter { $0.hasPrefix(baseName) && $0.hasSuffix(".swm") }

        if splitFiles.isEmpty {
            throw WimError.splitFailed("No split files were created")
        }

        progressHandler(1.0, "Split complete: \(splitFiles.count) files created")
    }

    func getWimInfo(at path: String) async throws -> WimInfo {
        let command = "wimlib-imagex info \"\(path)\""
        let result = try await ShellExecutor.shared.execute(command)

        if !result.succeeded {
            if result.error.contains("command not found") {
                throw WimError.wimlibNotInstalled
            }
            throw WimError.infoFailed(result.error)
        }

        return parseWimInfo(from: result.output, path: path)
    }

    private func parseProgress(from output: String) -> Double? {
        if let range = output.range(of: #"(\d+)%"#, options: .regularExpression) {
            let percentStr = output[range].dropLast()
            if let percent = Double(percentStr) {
                return percent / 100.0
            }
        }
        return nil
    }

    private func parseWimInfo(from output: String, path: String) -> WimInfo {
        var imageCount = 0
        var totalBytes: UInt64 = 0

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Image Count:") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    imageCount = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                }
            } else if line.contains("Total Bytes:") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    totalBytes = UInt64(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                }
            }
        }

        return WimInfo(path: path, imageCount: imageCount, totalBytes: totalBytes)
    }

    func needsSplit(fileSize: UInt64) -> Bool {
        return fileSize > 4 * 1024 * 1024 * 1024
    }
}

struct WimInfo {
    let path: String
    let imageCount: Int
    let totalBytes: UInt64

    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalBytes))
    }
}

enum WimError: Error, LocalizedError {
    case sourceNotFound
    case wimlibNotInstalled
    case splitFailed(String)
    case infoFailed(String)

    var errorDescription: String? {
        switch self {
        case .sourceNotFound:
            return "WIM file not found"
        case .wimlibNotInstalled:
            return "wimlib is not installed. Please install it via Homebrew."
        case .splitFailed(let message):
            return "Failed to split WIM file: \(message)"
        case .infoFailed(let message):
            return "Failed to get WIM info: \(message)"
        }
    }
}

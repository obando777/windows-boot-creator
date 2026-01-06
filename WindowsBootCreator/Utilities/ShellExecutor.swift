import Foundation

enum ShellError: Error, LocalizedError {
    case executionFailed(String)
    case commandNotFound(String)
    case permissionDenied(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Command failed: \(message)"
        case .commandNotFound(let command):
            return "Command not found: \(command)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .timeout:
            return "Command timed out"
        }
    }
}

struct ShellResult {
    let output: String
    let error: String
    let exitCode: Int32

    var succeeded: Bool {
        exitCode == 0
    }
}

actor ShellExecutor {
    static let shared = ShellExecutor()

    private init() {}

    func execute(_ command: String, arguments: [String] = []) async throws -> ShellResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ShellError.executionFailed(error.localizedDescription)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        return ShellResult(
            output: output.trimmingCharacters(in: .whitespacesAndNewlines),
            error: errorOutput.trimmingCharacters(in: .whitespacesAndNewlines),
            exitCode: process.terminationStatus
        )
    }

    func executeWithPrivileges(_ command: String) async throws -> ShellResult {
        let script = """
        do shell script "\(command.replacingOccurrences(of: "\"", with: "\\\""))" with administrator privileges
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            throw ShellError.executionFailed("Failed to create AppleScript")
        }

        let result = appleScript.executeAndReturnError(&error)

        if let error = error {
            let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            if errorMessage.contains("canceled") {
                throw ShellError.permissionDenied("User cancelled authorization")
            }
            throw ShellError.executionFailed(errorMessage)
        }

        return ShellResult(
            output: result.stringValue ?? "",
            error: "",
            exitCode: 0
        )
    }

    func executeWithOutput(_ command: String, outputHandler: @escaping (String) -> Void) async throws -> ShellResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                outputHandler(str)
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ShellError.executionFailed(error.localizedDescription)
        }

        outputPipe.fileHandleForReading.readabilityHandler = nil

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        return ShellResult(
            output: "",
            error: errorOutput.trimmingCharacters(in: .whitespacesAndNewlines),
            exitCode: process.terminationStatus
        )
    }
}

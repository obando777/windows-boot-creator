import Foundation

actor DiskService {
    static let shared = DiskService()

    private init() {}

    func listExternalDrives() async throws -> [USBDrive] {
        let result = try await ShellExecutor.shared.execute("diskutil list -plist external")

        guard result.succeeded else {
            if result.error.contains("No disks") || result.output.isEmpty {
                return []
            }
            throw DiskError.listFailed(result.error)
        }

        guard let data = result.output.data(using: .utf8) else {
            return []
        }

        return DiskUtilParser.parseExternalDisks(from: data)
    }

    func getDiskInfo(deviceNode: String) async throws -> String {
        let result = try await ShellExecutor.shared.execute("diskutil info \(deviceNode)")

        guard result.succeeded else {
            throw DiskError.infoFailed(result.error)
        }

        return result.output
    }

    func formatDriveAsFAT32(deviceNode: String, volumeName: String = "WININSTALL") async throws {
        let cleanDevice = deviceNode.hasPrefix("/dev/") ? deviceNode : "/dev/\(deviceNode)"

        let command = "diskutil eraseDisk FAT32 \(volumeName) MBRFormat \(cleanDevice)"

        do {
            let result = try await ShellExecutor.shared.executeWithPrivileges(command)

            if !result.succeeded {
                throw DiskError.formatFailed(result.error)
            }
        } catch let error as ShellError {
            throw DiskError.formatFailed(error.localizedDescription)
        }
    }

    func unmountDisk(deviceNode: String) async throws {
        let cleanDevice = deviceNode.hasPrefix("/dev/") ? deviceNode : "/dev/\(deviceNode)"

        let result = try await ShellExecutor.shared.execute("diskutil unmountDisk \(cleanDevice)")

        if !result.succeeded && !result.error.contains("not mounted") {
            throw DiskError.unmountFailed(result.error)
        }
    }

    func getMountPoint(for deviceNode: String) async throws -> String? {
        let result = try await ShellExecutor.shared.execute("diskutil info \(deviceNode)")

        guard result.succeeded else {
            return nil
        }

        let lines = result.output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Mount Point:") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    let mountPoint = parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
                    return mountPoint.isEmpty ? nil : mountPoint
                }
            }
        }

        return nil
    }

    func getFirstPartition(of diskDevice: String) async throws -> String {
        let diskId = diskDevice.replacingOccurrences(of: "/dev/", with: "")

        let result = try await ShellExecutor.shared.execute("diskutil list \(diskDevice)")

        guard result.succeeded else {
            throw DiskError.listFailed(result.error)
        }

        let lines = result.output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("\(diskId)s1") {
                return "/dev/\(diskId)s1"
            }
        }

        return "\(diskDevice)s1"
    }

    func ejectDisk(deviceNode: String) async throws {
        let cleanDevice = deviceNode.hasPrefix("/dev/") ? deviceNode : "/dev/\(deviceNode)"

        let result = try await ShellExecutor.shared.execute("diskutil eject \(cleanDevice)")

        if !result.succeeded {
            throw DiskError.ejectFailed(result.error)
        }
    }
}

enum DiskError: Error, LocalizedError {
    case listFailed(String)
    case infoFailed(String)
    case formatFailed(String)
    case unmountFailed(String)
    case mountFailed(String)
    case ejectFailed(String)
    case driveNotFound

    var errorDescription: String? {
        switch self {
        case .listFailed(let message):
            return "Failed to list drives: \(message)"
        case .infoFailed(let message):
            return "Failed to get drive info: \(message)"
        case .formatFailed(let message):
            return "Failed to format drive: \(message)"
        case .unmountFailed(let message):
            return "Failed to unmount drive: \(message)"
        case .mountFailed(let message):
            return "Failed to mount drive: \(message)"
        case .ejectFailed(let message):
            return "Failed to eject drive: \(message)"
        case .driveNotFound:
            return "Drive not found"
        }
    }
}

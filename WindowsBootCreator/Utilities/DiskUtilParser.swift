import Foundation

struct DiskUtilParser {

    struct DiskInfo {
        let deviceNode: String
        let volumeName: String
        let size: UInt64
        let isExternal: Bool
        let isRemovable: Bool
        let isWholeDisk: Bool
        let mediaType: String
    }

    static func parseExternalDisks(from plistData: Data) -> [USBDrive] {
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let disksAndPartitions = plist["AllDisksAndPartitions"] as? [[String: Any]] else {
            return []
        }

        var drives: [USBDrive] = []

        for disk in disksAndPartitions {
            guard let deviceNode = disk["DeviceIdentifier"] as? String,
                  let size = disk["Size"] as? UInt64 else {
                continue
            }

            let volumeName = disk["VolumeName"] as? String
                ?? disk["Content"] as? String
                ?? "Untitled"

            let drive = USBDrive(
                id: deviceNode,
                deviceNode: "/dev/\(deviceNode)",
                name: volumeName,
                size: size,
                isExternal: true,
                isRemovable: true
            )

            drives.append(drive)
        }

        return drives
    }

    static func parseExternalDiskInfo(from output: String) async -> [DiskInfo] {
        var disks: [DiskInfo] = []
        let lines = output.components(separatedBy: .newlines)

        var currentDisk: [String: String] = [:]
        var inExternalSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("/dev/disk") {
                if !currentDisk.isEmpty {
                    if let info = createDiskInfo(from: currentDisk) {
                        disks.append(info)
                    }
                }
                currentDisk = ["device": trimmed]
                inExternalSection = false
            } else if trimmed.contains(":") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
                    currentDisk[key] = value

                    if key == "Protocol" && (value == "USB" || value == "Thunderbolt") {
                        inExternalSection = true
                    }
                }
            }
        }

        if !currentDisk.isEmpty, let info = createDiskInfo(from: currentDisk) {
            disks.append(info)
        }

        return disks.filter { $0.isExternal && $0.isWholeDisk }
    }

    private static func createDiskInfo(from dict: [String: String]) -> DiskInfo? {
        guard let device = dict["device"] else { return nil }

        let isExternal = dict["Protocol"] == "USB"
            || dict["Protocol"] == "Thunderbolt"
            || dict["Removable Media"] == "Removable"
            || dict["Location"] == "External"

        let isRemovable = dict["Removable Media"] == "Removable"
            || dict["Ejectable"] == "Yes"

        let isWholeDisk = dict["Whole"] == "Yes"
            || !device.contains("s") || device.hasSuffix("disk0")

        var size: UInt64 = 0
        if let sizeStr = dict["Disk Size"],
           let match = sizeStr.range(of: #"\((\d+) Bytes\)"#, options: .regularExpression) {
            let bytesStr = sizeStr[match].dropFirst(1).dropLast(7)
            size = UInt64(bytesStr) ?? 0
        } else if let sizeStr = dict["Total Size"],
                  let match = sizeStr.range(of: #"\((\d+) Bytes\)"#, options: .regularExpression) {
            let bytesStr = sizeStr[match].dropFirst(1).dropLast(7)
            size = UInt64(bytesStr) ?? 0
        }

        return DiskInfo(
            deviceNode: device,
            volumeName: dict["Volume Name"] ?? dict["Media Name"] ?? "Untitled",
            size: size,
            isExternal: isExternal,
            isRemovable: isRemovable,
            isWholeDisk: isWholeDisk,
            mediaType: dict["Protocol"] ?? "Unknown"
        )
    }
}

import Foundation

struct USBDrive: Identifiable, Hashable {
    let id: String
    let deviceNode: String
    let name: String
    let size: UInt64
    let isExternal: Bool
    let isRemovable: Bool

    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    var displayName: String {
        "\(name) (\(sizeFormatted))"
    }

    var isValidForWindows: Bool {
        size >= 8 * 1024 * 1024 * 1024
    }
}

import Foundation

struct ISOInfo {
    let path: String
    let name: String
    let size: UInt64
    let mountPoint: String?
    let hasInstallWim: Bool
    let installWimSize: UInt64

    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    var installWimSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(installWimSize))
    }

    var needsWimSplit: Bool {
        installWimSize > 4 * 1024 * 1024 * 1024
    }
}

actor ISOService {
    static let shared = ISOService()

    private var mountedISOs: [String: String] = [:]

    private init() {}

    func validateISO(at path: String) async throws -> ISOInfo {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ISOError.fileNotFound
        }

        guard path.lowercased().hasSuffix(".iso") else {
            throw ISOError.invalidFormat
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let size = attributes[.size] as? UInt64 ?? 0

        let name = (path as NSString).lastPathComponent

        return ISOInfo(
            path: path,
            name: name,
            size: size,
            mountPoint: nil,
            hasInstallWim: false,
            installWimSize: 0
        )
    }

    func mountISO(at path: String) async throws -> ISOInfo {
        if let existingMount = mountedISOs[path] {
            return try await getISOInfo(path: path, mountPoint: existingMount)
        }

        let result = try await ShellExecutor.shared.execute("hdiutil attach \"\(path)\" -readonly -nobrowse")

        guard result.succeeded else {
            throw ISOError.mountFailed(result.error)
        }

        let mountPoint = parseMountPoint(from: result.output)
        guard let mount = mountPoint else {
            throw ISOError.mountFailed("Could not determine mount point")
        }

        mountedISOs[path] = mount

        return try await getISOInfo(path: path, mountPoint: mount)
    }

    func unmountISO(at path: String) async throws {
        guard let mountPoint = mountedISOs[path] else {
            return
        }

        let result = try await ShellExecutor.shared.execute("hdiutil detach \"\(mountPoint)\" -force")

        if result.succeeded || result.output.contains("ejected") {
            mountedISOs.removeValue(forKey: path)
        }
    }

    func unmountAllISOs() async {
        for (path, _) in mountedISOs {
            try? await unmountISO(at: path)
        }
    }

    private func getISOInfo(path: String, mountPoint: String) async throws -> ISOInfo {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let size = attributes[.size] as? UInt64 ?? 0
        let name = (path as NSString).lastPathComponent

        let installWimPath = "\(mountPoint)/sources/install.wim"
        let installEsdPath = "\(mountPoint)/sources/install.esd"

        var hasInstallWim = false
        var installWimSize: UInt64 = 0

        if FileManager.default.fileExists(atPath: installWimPath) {
            hasInstallWim = true
            let wimAttributes = try FileManager.default.attributesOfItem(atPath: installWimPath)
            installWimSize = wimAttributes[.size] as? UInt64 ?? 0
        } else if FileManager.default.fileExists(atPath: installEsdPath) {
            hasInstallWim = true
            let esdAttributes = try FileManager.default.attributesOfItem(atPath: installEsdPath)
            installWimSize = esdAttributes[.size] as? UInt64 ?? 0
        }

        if !hasInstallWim {
            let bootWimPath = "\(mountPoint)/sources/boot.wim"
            if !FileManager.default.fileExists(atPath: bootWimPath) {
                throw ISOError.notWindowsISO
            }
        }

        return ISOInfo(
            path: path,
            name: name,
            size: size,
            mountPoint: mountPoint,
            hasInstallWim: hasInstallWim,
            installWimSize: installWimSize
        )
    }

    private func parseMountPoint(from output: String) -> String? {
        let lines = output.components(separatedBy: .newlines)

        for line in lines.reversed() {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

            if components.count >= 3 {
                let potentialPath = components.dropFirst(2).joined(separator: " ")
                if potentialPath.hasPrefix("/Volumes/") {
                    return potentialPath
                }
            }
        }

        for line in lines {
            if let range = line.range(of: "/Volumes/") {
                return String(line[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }

    func getMountPoint(for path: String) -> String? {
        return mountedISOs[path]
    }
}

enum ISOError: Error, LocalizedError {
    case fileNotFound
    case invalidFormat
    case mountFailed(String)
    case unmountFailed(String)
    case notWindowsISO

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "ISO file not found"
        case .invalidFormat:
            return "Invalid file format. Please select an ISO file."
        case .mountFailed(let message):
            return "Failed to mount ISO: \(message)"
        case .unmountFailed(let message):
            return "Failed to unmount ISO: \(message)"
        case .notWindowsISO:
            return "This does not appear to be a valid Windows installation ISO"
        }
    }
}

import Foundation

enum DependencyStatus: Equatable {
    case installed
    case notInstalled
    case homebrewNotInstalled
    case installing
    case installFailed(String)
}

actor DependencyService {
    static let shared = DependencyService()

    private init() {}

    func checkWimlib() async -> DependencyStatus {
        let result = await checkCommand("wimlib-imagex")
        return result ? .installed : .notInstalled
    }

    func checkHomebrew() async -> Bool {
        return await checkCommand("brew")
    }

    private func checkCommand(_ command: String) async -> Bool {
        do {
            let result = try await ShellExecutor.shared.execute("which \(command)")
            return result.succeeded && !result.output.isEmpty
        } catch {
            return false
        }
    }

    func installWimlib(progressHandler: @escaping (String) -> Void) async throws {
        guard await checkHomebrew() else {
            throw DependencyError.homebrewNotInstalled
        }

        progressHandler("Installing wimlib via Homebrew...")

        do {
            let result = try await ShellExecutor.shared.executeWithOutput("brew install wimlib") { output in
                progressHandler(output)
            }

            if !result.succeeded {
                throw DependencyError.installFailed(result.error)
            }

            let verified = await checkWimlib()
            if verified != .installed {
                throw DependencyError.installFailed("Installation completed but wimlib not found")
            }

            progressHandler("wimlib installed successfully!")
        } catch let error as DependencyError {
            throw error
        } catch {
            throw DependencyError.installFailed(error.localizedDescription)
        }
    }

    func getHomebrewInstallInstructions() -> String {
        """
        Homebrew is required to install wimlib.

        To install Homebrew, run this command in Terminal:

        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        After installing Homebrew, restart this application.
        """
    }

    func getWimlibInfo() -> String {
        """
        wimlib is required to handle Windows installation files larger than 4GB.

        This is needed because:
        - USB drives must be formatted as FAT32 for UEFI boot
        - FAT32 has a 4GB file size limit
        - Windows install.wim files are often 5-6GB
        - wimlib splits the file into smaller chunks that Windows can reassemble
        """
    }
}

enum DependencyError: Error, LocalizedError {
    case homebrewNotInstalled
    case installFailed(String)
    case wimlibNotInstalled

    var errorDescription: String? {
        switch self {
        case .homebrewNotInstalled:
            return "Homebrew is not installed. Please install Homebrew first."
        case .installFailed(let message):
            return "Installation failed: \(message)"
        case .wimlibNotInstalled:
            return "wimlib is not installed"
        }
    }
}

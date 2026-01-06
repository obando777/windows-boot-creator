// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WindowsBootCreator",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "WindowsBootCreator",
            path: "WindowsBootCreator",
            exclude: ["Assets.xcassets", "WindowsBootCreator.entitlements"],
            sources: [
                "WindowsBootCreatorApp.swift",
                "Models/WizardStep.swift",
                "Models/USBDrive.swift",
                "Models/CreationProgress.swift",
                "Utilities/ShellExecutor.swift",
                "Utilities/DiskUtilParser.swift",
                "Services/DependencyService.swift",
                "Services/DiskService.swift",
                "Services/ISOService.swift",
                "Services/WimService.swift",
                "Services/FileTransferService.swift",
                "ViewModels/BootCreatorViewModel.swift",
                "Views/ContentView.swift",
                "Views/WelcomeView.swift",
                "Views/ISOSelectionView.swift",
                "Views/USBSelectionView.swift",
                "Views/ConfirmationView.swift",
                "Views/CreationProgressView.swift",
                "Views/CompletionView.swift"
            ]
        )
    ]
)

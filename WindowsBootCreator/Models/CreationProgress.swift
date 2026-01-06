import Foundation

enum CreationStage: String, CaseIterable {
    case preparing = "Preparing..."
    case formatting = "Formatting USB drive..."
    case mountingISO = "Mounting Windows ISO..."
    case copyingBootFiles = "Copying boot files..."
    case splittingWIM = "Splitting install.wim..."
    case copyingWIM = "Copying Windows image..."
    case finalizing = "Finalizing..."
    case complete = "Complete!"
    case failed = "Failed"

    var order: Int {
        switch self {
        case .preparing: return 0
        case .formatting: return 1
        case .mountingISO: return 2
        case .copyingBootFiles: return 3
        case .splittingWIM: return 4
        case .copyingWIM: return 5
        case .finalizing: return 6
        case .complete: return 7
        case .failed: return -1
        }
    }
}

struct CreationProgress {
    var stage: CreationStage = .preparing
    var stageProgress: Double = 0.0
    var overallProgress: Double = 0.0
    var currentFile: String = ""
    var bytesTransferred: UInt64 = 0
    var totalBytes: UInt64 = 0
    var errorMessage: String?
    var isComplete: Bool = false
    var isFailed: Bool = false

    var bytesTransferredFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytesTransferred))
    }

    var totalBytesFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalBytes))
    }

    mutating func updateStage(_ newStage: CreationStage) {
        stage = newStage
        stageProgress = 0.0

        let totalStages = 7.0
        overallProgress = Double(newStage.order) / totalStages

        if newStage == .complete {
            isComplete = true
            overallProgress = 1.0
            stageProgress = 1.0
        } else if newStage == .failed {
            isFailed = true
        }
    }

    mutating func updateProgress(transferred: UInt64, total: UInt64, file: String = "") {
        bytesTransferred = transferred
        totalBytes = total
        currentFile = file

        if total > 0 {
            stageProgress = Double(transferred) / Double(total)
        }

        let stageWeight = 1.0 / 7.0
        let baseProgress = Double(stage.order) / 7.0
        overallProgress = baseProgress + (stageProgress * stageWeight)
    }

    mutating func fail(with message: String) {
        stage = .failed
        isFailed = true
        errorMessage = message
    }
}

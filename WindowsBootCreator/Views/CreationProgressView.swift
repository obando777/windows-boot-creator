import SwiftUI

struct CreationProgressView: View {
    @ObservedObject var viewModel: BootCreatorViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Creating Bootable USB")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Please wait while your bootable USB drive is being created.")
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()

            progressCard
                .frame(maxWidth: 500)

            Spacer()

            if !viewModel.progress.isFailed {
                Button("Cancel") {
                    Task { await viewModel.cancelCreation() }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                if viewModel.progress.isFailed {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                } else {
                    ProgressView()
                        .scaleEffect(1.2)
                }

                VStack(alignment: .leading) {
                    Text(viewModel.progress.stage.rawValue)
                        .font(.headline)
                    if !viewModel.progress.currentFile.isEmpty {
                        Text(viewModel.progress.currentFile)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text("\(Int(viewModel.progress.overallProgress * 100))%")
                    .font(.title2.bold())
                    .foregroundColor(.accentColor)
            }

            ProgressView(value: viewModel.progress.overallProgress)
                .progressViewStyle(.linear)

            stagesList

            if viewModel.progress.totalBytes > 0 {
                HStack {
                    Text("Transferred:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(viewModel.progress.bytesTransferredFormatted) / \(viewModel.progress.totalBytesFormatted)")
                        .fontWeight(.medium)
                }
                .font(.caption)
            }

            if let error = viewModel.progress.errorMessage {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var stagesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(CreationStage.allCases.filter { $0.order >= 0 && $0.order < 7 }, id: \.self) { stage in
                StageRow(
                    stage: stage,
                    currentStage: viewModel.progress.stage,
                    stageProgress: viewModel.progress.stageProgress
                )
            }
        }
    }
}

struct StageRow: View {
    let stage: CreationStage
    let currentStage: CreationStage
    let stageProgress: Double

    var body: some View {
        HStack {
            stageIcon
                .frame(width: 20)

            Text(stageName)
                .font(.caption)
                .foregroundColor(textColor)

            Spacer()

            if stage == currentStage && stage.order < 7 {
                Text("\(Int(stageProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var stageIcon: some View {
        Group {
            if stage.order < currentStage.order || currentStage == .complete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if stage == currentStage && currentStage != .complete {
                ProgressView()
                    .scaleEffect(0.5)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .font(.caption)
    }

    private var textColor: Color {
        if stage.order < currentStage.order || currentStage == .complete {
            return .primary
        } else if stage == currentStage {
            return .accentColor
        } else {
            return .secondary
        }
    }

    private var stageName: String {
        switch stage {
        case .preparing: return "Preparing"
        case .formatting: return "Formatting USB"
        case .mountingISO: return "Mounting ISO"
        case .copyingBootFiles: return "Copying boot files"
        case .splittingWIM: return "Splitting install.wim"
        case .copyingWIM: return "Copying Windows image"
        case .finalizing: return "Finalizing"
        case .complete: return "Complete"
        case .failed: return "Failed"
        }
    }
}

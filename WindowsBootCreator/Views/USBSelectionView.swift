import SwiftUI

struct USBSelectionView: View {
    @ObservedObject var viewModel: BootCreatorViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Select USB Drive")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Choose the USB drive to create the bootable installer on.")
                .font(.body)
                .foregroundColor(.secondary)

            warningBanner

            Spacer()

            driveList
                .frame(maxWidth: 500)

            Spacer()

            navigationButtons
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task { await viewModel.refreshDrives() }
        }
    }

    private var warningBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("All data on the selected drive will be erased!")
                .font(.callout)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    private var driveList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Drives")
                    .font(.headline)
                Spacer()

                Button(action: {
                    Task { await viewModel.refreshDrives() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLoading)
            }

            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Scanning for drives...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if viewModel.availableDrives.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "externaldrive.badge.xmark")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No USB drives found")
                        .foregroundColor(.secondary)
                    Text("Connect a USB drive and click refresh")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.availableDrives) { drive in
                            DriveRow(
                                drive: drive,
                                isSelected: viewModel.selectedDrive?.id == drive.id,
                                onSelect: {
                                    viewModel.selectedDrive = drive
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var navigationButtons: some View {
        HStack {
            Button(action: { viewModel.goToPreviousStep() }) {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("Back")
                }
            }
            .buttonStyle(.bordered)

            Spacer()

            Button(action: { viewModel.goToNextStep() }) {
                HStack {
                    Text("Next")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canProceedFromUSB)
        }
    }
}

struct DriveRow: View {
    let drive: USBDrive
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .font(.title2)
                    .foregroundColor(drive.isValidForWindows ? .accentColor : .secondary)

                VStack(alignment: .leading) {
                    Text(drive.name)
                        .font(.body.bold())
                        .foregroundColor(.primary)
                    HStack {
                        Text(drive.sizeFormatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !drive.isValidForWindows {
                            Text("(8GB+ required)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(!drive.isValidForWindows)
        .opacity(drive.isValidForWindows ? 1.0 : 0.6)
    }
}

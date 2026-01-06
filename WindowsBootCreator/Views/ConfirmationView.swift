import SwiftUI

struct ConfirmationView: View {
    @ObservedObject var viewModel: BootCreatorViewModel
    @State private var isConfirmed = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Confirm")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Review your selections before creating the bootable USB.")
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()

            summaryCard
                .frame(maxWidth: 500)

            Spacer()

            confirmationCheckbox

            navigationButtons
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.headline)

            Divider()

            if let iso = viewModel.isoInfo {
                summaryRow(
                    icon: "opticaldisc",
                    label: "Windows ISO",
                    value: iso.name,
                    detail: iso.sizeFormatted
                )
            }

            if let drive = viewModel.selectedDrive {
                summaryRow(
                    icon: "externaldrive.fill",
                    label: "USB Drive",
                    value: drive.name,
                    detail: drive.sizeFormatted
                )
            }

            Divider()

            if let iso = viewModel.isoInfo, iso.needsWimSplit {
                HStack(alignment: .top) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("Large File Handling")
                            .font(.subheadline.bold())
                        Text("The install.wim file will be split into smaller parts for FAT32 compatibility. This may take additional time.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            warningSection
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func summaryRow(icon: String, label: String, value: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body.bold())
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var warningSection: some View {
        HStack(alignment: .top) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            VStack(alignment: .leading) {
                Text("Data Loss Warning")
                    .font(.subheadline.bold())
                    .foregroundColor(.red)
                Text("ALL data on the selected USB drive will be permanently erased. Make sure you have backed up any important files.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    private var confirmationCheckbox: some View {
        HStack {
            Toggle(isOn: $isConfirmed) {
                Text("I understand that all data on the USB drive will be erased")
                    .font(.body)
            }
            .toggleStyle(.checkbox)
        }
        .frame(maxWidth: 500)
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

            Button(action: {
                Task { await viewModel.startCreation() }
            }) {
                HStack {
                    Image(systemName: "externaldrive.badge.plus")
                    Text("Create Bootable USB")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isConfirmed)
        }
    }
}

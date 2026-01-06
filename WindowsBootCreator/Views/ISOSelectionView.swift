import SwiftUI
import UniformTypeIdentifiers

struct ISOSelectionView: View {
    @ObservedObject var viewModel: BootCreatorViewModel
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Select Windows ISO")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Choose a Windows 10 or Windows 11 installation ISO file.")
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()

            dropZone
                .frame(maxWidth: 500, maxHeight: 200)

            if let info = viewModel.isoInfo {
                selectedISOInfo(info)
            }

            Spacer()

            navigationButtons
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDragging ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDragging ? Color.accentColor.opacity(0.1) : Color.clear)
                )

            VStack(spacing: 16) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(isDragging ? .accentColor : .secondary)

                Text("Drop ISO file here or click to browse")
                    .font(.body)
                    .foregroundColor(.secondary)

                Button("Choose File...") {
                    openFilePicker()
                }
                .buttonStyle(.bordered)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
        }
        .onTapGesture {
            openFilePicker()
        }
    }

    @ViewBuilder
    private func selectedISOInfo(_ info: ISOInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("ISO Selected")
                    .font(.headline)
            }

            Divider()

            infoRow(label: "File", value: info.name)
            infoRow(label: "Size", value: info.sizeFormatted)

            if info.needsWimSplit {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("install.wim (\(info.installWimSizeFormatted)) will be split for FAT32 compatibility")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: 500)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.body)
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
            .disabled(!viewModel.canProceedFromISO)
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "iso")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a Windows installation ISO"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await viewModel.selectISO(at: url)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "iso" else {
                return
            }

            Task { @MainActor in
                await viewModel.selectISO(at: url)
            }
        }

        return true
    }
}

import SwiftUI

struct CompletionView: View {
    @ObservedObject var viewModel: BootCreatorViewModel

    var body: some View {
        VStack(spacing: 24) {
            if viewModel.progress.isFailed {
                failureContent
            } else {
                successContent
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var successContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)

            Text("Success!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your bootable Windows USB drive has been created successfully.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            instructionsCard

            Spacer()

            HStack(spacing: 16) {
                Button("Eject USB") {
                    Task { await viewModel.ejectDrive() }
                }
                .buttonStyle(.bordered)

                Button("Create Another") {
                    viewModel.reset()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var failureContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.red)

            Text("Creation Failed")
                .font(.largeTitle)
                .fontWeight(.bold)

            if let error = viewModel.progress.errorMessage {
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("Troubleshooting Tips")
                    .font(.headline)

                troubleshootingItem(
                    icon: "externaldrive",
                    text: "Ensure the USB drive is properly connected"
                )
                troubleshootingItem(
                    icon: "arrow.clockwise",
                    text: "Try a different USB port"
                )
                troubleshootingItem(
                    icon: "opticaldisc",
                    text: "Verify the Windows ISO is not corrupted"
                )
                troubleshootingItem(
                    icon: "terminal",
                    text: "Check that wimlib is properly installed"
                )
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .frame(maxWidth: 400)

            Spacer()

            Button("Try Again") {
                viewModel.reset()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Next Steps")
                .font(.headline)

            Divider()

            instructionStep(number: 1, text: "Safely eject the USB drive from your Mac")
            instructionStep(number: 2, text: "Insert the USB drive into your target PC")
            instructionStep(number: 3, text: "Boot from USB (usually F12 or Del during startup)")
            instructionStep(number: 4, text: "Follow the Windows installation wizard")

            Divider()

            HStack(alignment: .top) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                VStack(alignment: .leading) {
                    Text("Tip")
                        .font(.subheadline.bold())
                    Text("Make sure UEFI boot is enabled in your PC's BIOS settings for Windows 10/11.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: 450)
    }

    private func instructionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .font(.body)
        }
    }

    private func troubleshootingItem(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

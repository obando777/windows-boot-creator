import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: BootCreatorViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Windows Bootable USB Creator")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Create a bootable Windows 10/11 installation USB drive from an ISO file.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Divider()
                .padding(.vertical)

            dependencySection

            Spacer()

            if viewModel.canProceedFromWelcome {
                Button(action: { viewModel.goToNextStep() }) {
                    HStack {
                        Text("Get Started")
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var dependencySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dependencies")
                .font(.headline)

            HStack {
                statusIcon(for: viewModel.wimlibStatus)
                VStack(alignment: .leading) {
                    Text("wimlib")
                        .font(.body.bold())
                    Text(statusMessage(for: viewModel.wimlibStatus))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                if case .notInstalled = viewModel.wimlibStatus {
                    Button("Install") {
                        Task { await viewModel.installWimlib() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isInstallingWimlib)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            if viewModel.isInstallingWimlib {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(viewModel.installProgress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if case .homebrewNotInstalled = viewModel.wimlibStatus {
                homebrewInstructions
            }

            if case .installFailed(let error) = viewModel.wimlibStatus {
                Text("Installation failed: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: 400)
    }

    @ViewBuilder
    private var homebrewInstructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Homebrew Required")
                .font(.subheadline.bold())

            Text("Run this command in Terminal to install Homebrew:")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(4)
                .textSelection(.enabled)

            Button("Check Again") {
                Task { await viewModel.checkDependencies() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    private func statusIcon(for status: DependencyStatus) -> some View {
        Group {
            switch status {
            case .installed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .notInstalled, .homebrewNotInstalled:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.orange)
            case .installing:
                ProgressView()
                    .scaleEffect(0.8)
            case .installFailed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.title2)
    }

    private func statusMessage(for status: DependencyStatus) -> String {
        switch status {
        case .installed:
            return "Installed and ready"
        case .notInstalled:
            return "Required for handling large Windows files"
        case .homebrewNotInstalled:
            return "Homebrew is required to install wimlib"
        case .installing:
            return "Installing..."
        case .installFailed(let error):
            return "Failed: \(error)"
        }
    }
}

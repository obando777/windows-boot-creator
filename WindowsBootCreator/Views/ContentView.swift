import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = BootCreatorViewModel()

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.horizontal, 32)
                .padding(.top, 16)

            Divider()
                .padding(.top, 16)

            currentStepView
        }
        .frame(minWidth: 700, minHeight: 550)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(Array(WizardStep.allCases.enumerated()), id: \.element) { index, step in
                StepIndicatorItem(
                    step: step,
                    isActive: step == viewModel.currentStep,
                    isCompleted: step.rawValue < viewModel.currentStep.rawValue
                )

                if index < WizardStep.allCases.count - 1 {
                    stepConnector(isCompleted: step.rawValue < viewModel.currentStep.rawValue)
                }
            }
        }
    }

    private func stepConnector(isCompleted: Bool) -> some View {
        Rectangle()
            .fill(isCompleted ? Color.accentColor : Color.secondary.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: 60)
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch viewModel.currentStep {
        case .welcome:
            WelcomeView(viewModel: viewModel)
        case .selectISO:
            ISOSelectionView(viewModel: viewModel)
        case .selectUSB:
            USBSelectionView(viewModel: viewModel)
        case .confirm:
            ConfirmationView(viewModel: viewModel)
        case .progress:
            CreationProgressView(viewModel: viewModel)
        case .complete:
            CompletionView(viewModel: viewModel)
        }
    }
}

struct StepIndicatorItem: View {
    let step: WizardStep
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 32, height: 32)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                } else {
                    Text("\(step.rawValue + 1)")
                        .font(.caption.bold())
                        .foregroundColor(isActive ? .white : .secondary)
                }
            }

            Text(step.title)
                .font(.caption2)
                .foregroundColor(isActive ? .primary : .secondary)
        }
    }

    private var backgroundColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return .accentColor
        } else {
            return .secondary.opacity(0.2)
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif

import Foundation

enum WizardStep: Int, CaseIterable {
    case welcome = 0
    case selectISO = 1
    case selectUSB = 2
    case confirm = 3
    case progress = 4
    case complete = 5

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .selectISO: return "Select ISO"
        case .selectUSB: return "Select USB"
        case .confirm: return "Confirm"
        case .progress: return "Creating..."
        case .complete: return "Complete"
        }
    }

    var canGoBack: Bool {
        switch self {
        case .welcome, .progress, .complete:
            return false
        default:
            return true
        }
    }

    var nextStep: WizardStep? {
        guard let index = WizardStep.allCases.firstIndex(of: self),
              index + 1 < WizardStep.allCases.count else {
            return nil
        }
        return WizardStep.allCases[index + 1]
    }

    var previousStep: WizardStep? {
        guard let index = WizardStep.allCases.firstIndex(of: self),
              index > 0 else {
            return nil
        }
        return WizardStep.allCases[index - 1]
    }
}

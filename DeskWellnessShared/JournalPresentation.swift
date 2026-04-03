import Foundation

enum JournalEntryKind {
    case scan
    case workout
}

enum JournalPresentation {
    static func title(for kind: JournalEntryKind) -> String {
        switch kind {
        case .scan:
            return "Optional Check-In"
        case .workout:
            return "Desk Reset"
        }
    }

    static func statusText(for kind: JournalEntryKind, exercisesCompleted: Bool) -> String {
        switch kind {
        case .scan:
            return exercisesCompleted ? "Check-in saved with reset done" : "Check-in saved"
        case .workout:
            return exercisesCompleted ? "Reset completed" : "Reset logged"
        }
    }
}

import UserNotifications

enum ReminderGuidancePrimaryAction: Equatable {
    case requestPermission
    case enableReminders
    case openSettings
}

struct ReminderAccessGuidance: Equatable {
    let title: String
    let message: String
    let statusMessage: String
    let primaryActionTitle: String?
    let primaryAction: ReminderGuidancePrimaryAction?
    let showsSecondaryDismissAction: Bool

    static func make(status: UNAuthorizationStatus, remindersEnabled: Bool) -> ReminderAccessGuidance {
        switch status {
        case .authorized, .provisional, .ephemeral:
            if remindersEnabled {
                return ReminderAccessGuidance(
                    title: "Weekday reminders are active",
                    message: "ResetMinute will nudge you during your chosen work window. You can adjust the schedule or turn reminders off any time.",
                    statusMessage: "Weekday reminders are scheduled.",
                    primaryActionTitle: nil,
                    primaryAction: nil,
                    showsSecondaryDismissAction: false
                )
            }

            return ReminderAccessGuidance(
                title: "Notifications are ready",
                message: "Turn on weekday reminders when you want gentle nudges to take a neck, shoulder, or back reset during work hours.",
                statusMessage: "Notifications are available. Weekday reminders are off.",
                primaryActionTitle: "Enable Weekday Reminders",
                primaryAction: .enableReminders,
                showsSecondaryDismissAction: false
            )

        case .notDetermined:
            return ReminderAccessGuidance(
                title: "Allow workday reminders",
                message: "ResetMinute can nudge you to take short desk resets during your workday. You decide if and when to allow notifications.",
                statusMessage: "Notifications have not been allowed yet.",
                primaryActionTitle: "Allow Notifications",
                primaryAction: .requestPermission,
                showsSecondaryDismissAction: false
            )

        case .denied:
            return ReminderAccessGuidance(
                title: "Notifications are off",
                message: "You can keep using ResetMinute manually. Open Settings any time if you want weekday reminder nudges.",
                statusMessage: "Notifications are blocked in Settings.",
                primaryActionTitle: "Open Settings",
                primaryAction: .openSettings,
                showsSecondaryDismissAction: true
            )

        @unknown default:
            return ReminderAccessGuidance(
                title: "Notifications unavailable",
                message: "Use manual resets for now. Try Settings later if notification access becomes available.",
                statusMessage: "Notifications are unavailable right now.",
                primaryActionTitle: nil,
                primaryAction: nil,
                showsSecondaryDismissAction: false
            )
        }
    }
}

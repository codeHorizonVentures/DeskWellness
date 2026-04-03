//
//  ReminderSettingsView.swift
//  DeskWellness
//
//  Created by Codex on 03.04.2026.
//

import SwiftUI
import UserNotifications
import UIKit

struct ReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(ReminderScheduler.enabledKey) private var remindersEnabled = false
    @AppStorage(ReminderScheduler.startHourKey) private var startHour = 10
    @AppStorage(ReminderScheduler.startMinuteKey) private var startMinute = 0
    @AppStorage(ReminderScheduler.endHourKey) private var endHour = 17
    @AppStorage(ReminderScheduler.endMinuteKey) private var endMinute = 0
    @AppStorage(ReminderScheduler.intervalHoursKey) private var intervalHours = 2

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var statusMessage = "Weekday reminders for quick desk resets."

    private let intervalOptions = [1, 2, 3]

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder Access") {
                    ReminderAccessCard(
                        guidance: guidance,
                        onPrimaryAction: {
                            Task { await handlePrimaryAction(guidance.primaryAction) }
                        },
                        onSecondaryAction: {
                            remindersEnabled = false
                            statusMessage = "Weekday reminders stay off until notification access is enabled."
                        }
                    )
                }

                Section {
                    Toggle("Enable weekday reminders", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) { _, _ in
                            Task { await syncReminders() }
                        }
                        .disabled(reminderControlsDisabled)

                    if remindersEnabled {
                        DatePicker(
                            "Start time",
                            selection: startDateBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: startHour) { _, _ in
                            Task { await syncReminders() }
                        }
                        .onChange(of: startMinute) { _, _ in
                            Task { await syncReminders() }
                        }

                        DatePicker(
                            "End time",
                            selection: endDateBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: endHour) { _, _ in
                            Task { await syncReminders() }
                        }
                        .onChange(of: endMinute) { _, _ in
                            Task { await syncReminders() }
                        }

                        Picker("Repeat every", selection: $intervalHours) {
                            ForEach(intervalOptions, id: \.self) { hours in
                                Text("\(hours) hour\(hours == 1 ? "" : "s")").tag(hours)
                            }
                        }
                        .onChange(of: intervalHours) { _, _ in
                            Task { await syncReminders() }
                        }
                    }
                } header: {
                    Text("Workday Reminders")
                } footer: {
                    if reminderControlsDisabled {
                        Text("Notification access is off in Settings. Use the card above to re-enable reminders.")
                    }
                }

                Section("What you get") {
                    Text("ResetMinute schedules weekday prompts during your workday.")
                    Text("Each reminder nudges you to take a quick neck, shoulder, or back reset.")
                }

                Section("Status") {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Desk Reset Reminders")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                authorizationStatus = await ReminderScheduler.currentAuthorizationStatus()
                await syncReminders(showSuccessMessage: false)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await syncReminders(showSuccessMessage: false) }
            }
        }
    }

    private var startDateBinding: Binding<Date> {
        Binding {
            componentsToDate(hour: startHour, minute: startMinute)
        } set: { newDate in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
            startHour = components.hour ?? 10
            startMinute = components.minute ?? 0
        }
    }

    private var endDateBinding: Binding<Date> {
        Binding {
            componentsToDate(hour: endHour, minute: endMinute)
        } set: { newDate in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
            endHour = components.hour ?? 17
            endMinute = components.minute ?? 0
        }
    }

    private func componentsToDate(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private var guidance: ReminderAccessGuidance {
        ReminderAccessGuidance.make(status: authorizationStatus, remindersEnabled: remindersEnabled)
    }

    private var reminderControlsDisabled: Bool {
        authorizationStatus == .denied
    }

    @MainActor
    private func syncReminders(showSuccessMessage: Bool = true) async {
        do {
            let scheduled = try await ReminderScheduler.syncFromDefaults()
            authorizationStatus = await ReminderScheduler.currentAuthorizationStatus()

            if authorizationStatus == .denied {
                remindersEnabled = false
            }

            if scheduled && remindersEnabled {
                statusMessage = showSuccessMessage
                    ? "Weekday reminders are scheduled."
                    : guidance.statusMessage
            } else {
                statusMessage = guidance.statusMessage
            }
        } catch {
            statusMessage = "Could not update reminders right now."
        }
    }

    @MainActor
    private func handlePrimaryAction(_ action: ReminderGuidancePrimaryAction?) async {
        switch action {
        case .requestPermission, .enableReminders:
            remindersEnabled = true
            await syncReminders()

        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }

        case nil:
            break
        }
    }
}

private struct ReminderAccessCard: View {
    let guidance: ReminderAccessGuidance
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(guidance.title)
                .font(.headline)

            Text(guidance.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let primaryActionTitle = guidance.primaryActionTitle {
                Button(primaryActionTitle, action: onPrimaryAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("reminder_guidance_primary_action")
            }

            if guidance.showsSecondaryDismissAction {
                Button("Keep reminders off", role: .cancel, action: onSecondaryAction)
                    .accessibilityIdentifier("reminder_guidance_secondary_action")
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("reminder_guidance_card")
    }
}

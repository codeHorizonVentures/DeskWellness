//
//  ReminderSettingsView.swift
//  DeskWellness
//
//  Created by Codex on 03.04.2026.
//

import SwiftUI
import UserNotifications

struct ReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss

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
                Section("Workday Reminders") {
                    Toggle("Enable weekday reminders", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) { _, _ in
                            Task { await syncReminders() }
                        }

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

    @MainActor
    private func syncReminders(showSuccessMessage: Bool = true) async {
        do {
            let scheduled = try await ReminderScheduler.syncFromDefaults()
            authorizationStatus = await ReminderScheduler.currentAuthorizationStatus()

            if !remindersEnabled {
                statusMessage = "Weekday reminders are off."
            } else if !scheduled && authorizationStatus == .denied {
                statusMessage = "Notifications are blocked. Enable them in Settings to get desk reset reminders."
            } else if scheduled {
                statusMessage = showSuccessMessage
                    ? "Weekday reminders are scheduled."
                    : "Weekday reminders are ready."
            } else {
                statusMessage = "Waiting for notification permission."
            }
        } catch {
            statusMessage = "Could not update reminders right now."
        }
    }
}

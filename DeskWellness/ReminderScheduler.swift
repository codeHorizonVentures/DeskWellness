//
//  ReminderScheduler.swift
//  DeskWellness
//
//  Created by Codex on 03.04.2026.
//

import Foundation
import UserNotifications

enum ReminderScheduler {
    static let enabledKey = "remindersEnabled"
    static let startHourKey = "reminderStartHour"
    static let startMinuteKey = "reminderStartMinute"
    static let endHourKey = "reminderEndHour"
    static let endMinuteKey = "reminderEndMinute"
    static let intervalHoursKey = "reminderIntervalHours"

    private static let reminderPrefix = "desk-reset-reminder-"
    private static let weekdayRange = 2...6

    static func syncFromDefaults() async throws -> Bool {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: enabledKey)

        if !enabled {
            await clearScheduledReminders()
            return false
        }

        let startHour = defaults.integer(forKey: startHourKey)
        let startMinute = defaults.integer(forKey: startMinuteKey)
        let endHour = defaults.integer(forKey: endHourKey)
        let endMinute = defaults.integer(forKey: endMinuteKey)
        let interval = max(1, defaults.integer(forKey: intervalHoursKey))

        let granted = try await requestAuthorizationIfNeeded()
        guard granted else {
            await clearScheduledReminders()
            return false
        }

        let times = scheduledTimes(
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            intervalHours: interval
        )

        await clearScheduledReminders()

        let center = UNUserNotificationCenter.current()
        for weekday in weekdayRange {
            for (index, time) in times.enumerated() {
                var components = DateComponents()
                components.weekday = weekday
                components.hour = time.hour
                components.minute = time.minute

                let content = UNMutableNotificationContent()
                content.title = "Time for a desk reset"
                content.body = "Take a minute for your neck, shoulders, or back."
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let identifier = "\(reminderPrefix)\(weekday)-\(index)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                try await center.add(request)
            }
        }

        return true
    }

    static func clearScheduledReminders() async {
        let center = UNUserNotificationCenter.current()
        let identifiers = await pendingReminderIdentifiers()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    static func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    private static func pendingReminderIdentifiers() async -> [String] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.map(\.identifier).filter { $0.hasPrefix(reminderPrefix) }
    }

    private static func requestAuthorizationIfNeeded() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        @unknown default:
            return false
        }
    }

    private static func scheduledTimes(
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        intervalHours: Int
    ) -> [(hour: Int, minute: Int)] {
        let startTotal = (startHour * 60) + startMinute
        let endTotal = (endHour * 60) + endMinute
        let intervalMinutes = max(60, intervalHours * 60)

        guard endTotal >= startTotal else {
            return [(hour: startHour, minute: startMinute)]
        }

        var times: [(hour: Int, minute: Int)] = []
        var current = startTotal

        while current <= endTotal {
            times.append((hour: current / 60, minute: current % 60))
            current += intervalMinutes
        }

        return times.isEmpty ? [(hour: startHour, minute: startMinute)] : times
    }
}

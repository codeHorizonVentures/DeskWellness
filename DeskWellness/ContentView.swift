//
//  ContentView.swift
//  DeskWellness
//
//  Created by P Dev on 30.04.2025.
//
//
//  ContentView.swift
//  DeskWellness
//
//  P Dev on 30.04.2025.
//

import SwiftUI
import UserNotifications
import Observation
import Combine

// MARK: - Data Model
enum HabitType: String, CaseIterable, Codable {
    case postureCheck = "Posture Check"
    case movementBreak = "Movement Break"
    case deskExercise = "Desk Exercise"
    case standingInterval = "Standing Interval"
    case hydrationReminder = "Hydration Reminder"
}

@Observable
class Habit: Identifiable, Codable {
    let id: UUID
    let type: HabitType
    var interval: TimeInterval
    var isEnabled: Bool
    var notificationIDs: [String]

    // Timer tracking properties (not Codable)
    var lastReset: Date = Date()

    init(id: UUID, type: HabitType, interval: TimeInterval, isEnabled: Bool, notificationIDs: [String]) {
        self.id = id
        self.type = type
        self.interval = interval
        self.isEnabled = isEnabled
        self.notificationIDs = notificationIDs
    }

    func timeRemaining(from date: Date = Date()) -> TimeInterval {
        max(0, interval - date.timeIntervalSince(lastReset))
    }
}

@Observable
class HabitStore {
    var habits: [Habit] = []
    var tick = 0 // Dummy property for forcing updates

    private var timer: AnyCancellable?

    init() {
        loadDefaultHabits()
        startTimer()
    }

    private func loadDefaultHabits() {
        let defaultHabits = [
            Habit(id: UUID(), type: .postureCheck, interval: 1800, isEnabled: true, notificationIDs: []),
            Habit(id: UUID(), type: .movementBreak, interval: 1800, isEnabled: true, notificationIDs: []),
            Habit(id: UUID(), type: .deskExercise, interval: 3600, isEnabled: true, notificationIDs: []),
            Habit(id: UUID(), type: .standingInterval, interval: 7200, isEnabled: true, notificationIDs: []),
            Habit(id: UUID(), type: .hydrationReminder, interval: 2700, isEnabled: true, notificationIDs: [])
        ]

        habits = defaultHabits
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick += 1
            }
    }

    func resetHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].lastReset = Date()
        }
    }
}

// MARK: - Notification Manager
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    var habitStore: HabitStore?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { success, error in
            if success {
                print("Notification authorization granted")
            } else if let error {
                print("Authorization error: \(error.localizedDescription)")
            }
        }
    }

    func scheduleHabitNotification(_ habit: Habit) {
        guard let habitStore else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time for \(habit.type.rawValue)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: habit.interval,
            repeats: true
        )

        let requestID = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: requestID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                DispatchQueue.main.async {
                    if let index = habitStore.habits.firstIndex(where: { $0.id == habit.id }) {
                        habitStore.habits[index].notificationIDs.append(requestID)
                    }
                }
            }
        }
    }

    func cancelNotifications(for habit: Habit) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: habit.notificationIDs)
    }

    func updateNotifications(for habit: Habit) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: habit.notificationIDs)
        // Clear the IDs after removing
        if let store = habitStore,
           let index = store.habits.firstIndex(where: { $0.id == habit.id }) {
            store.habits[index].notificationIDs.removeAll()
        }
    }

    func triggerTestNotification(for habit: Habit) {
        let content = UNMutableNotificationContent()
        content.title = "Test: \(habit.type.rawValue)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - UI Components
struct HabitListView: View {
    @Environment(HabitStore.self) private var habitStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(habitStore.habits) { habit in
                    HabitRowView(habit: habit)
                }
            }
            .navigationTitle("Health Habits")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("Settings") {
                        SettingsView()
                    }
                }
            }
        }
    }
}

struct HabitRowView: View {
    let habit: Habit
    @Environment(HabitStore.self) private var habitStore
    @State private var now = Date()

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(habit.type.rawValue)
                    .font(.headline)
                Text("Every \(formattedInterval(habit.interval))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if habit.isEnabled {
                    Text("Next in: \(formattedInterval(habit.timeRemaining(from: now)))")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { habit.isEnabled },
                set: { newValue in
                    if let index = habitStore.habits.firstIndex(where: { $0.id == habit.id }) {
                        habitStore.habits[index].isEnabled = newValue
                        if newValue {
                            habitStore.habits[index].lastReset = Date()
                            NotificationManager.shared.scheduleHabitNotification(habit)
                        } else {
                            NotificationManager.shared.cancelNotifications(for: habit)
                        }
                    }
                }
            ))
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }

    private func formattedInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .short
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: interval) ?? ""
    }}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(HabitStore.self) private var habitStore

    var body: some View {
        Form {
            Section {
                ForEach(habitStore.habits) { habit in
                    NavigationLink {
                        HabitDetailView(habit: habit)
                    } label: {
                        Text(habit.type.rawValue)
                    }
                }
            } header: {
                Text("Notification Settings")
            }
        }
        .navigationTitle("Settings")
    }
}

struct HabitDetailView: View {
    @Bindable var habit: Habit
    @Environment(HabitStore.self) private var habitStore

    var body: some View {
        Form {
            Section {
                Picker("Interval", selection: $habit.interval) {
                    Text("30 minutes").tag(1800.0)
                    Text("1 hour").tag(3600.0)
                    Text("2 hours").tag(7200.0)
                    Text("Custom").tag(900.0)
                }
                .onChange(of: habit.interval) { _ in
                    habitStore.resetHabit(habit)
                }

                if habit.interval == 900 {
                    Stepper("Custom interval: \(formattedInterval(habit.interval))",
                            value: $habit.interval,
                            in: 300...10800,
                            step: 300)
                    .onChange(of: habit.interval) { _ in
                        habitStore.resetHabit(habit)
                    }
                }
            } header: {
                Text("Timing")
            }

            Section {
                Button("Test Notification") {
                    NotificationManager.shared.triggerTestNotification(for: habit)
                }
            }
        }
        .navigationTitle(habit.type.rawValue)
        .onDisappear {
            NotificationManager.shared.updateNotifications(for: habit)
        }
    }

    private func formattedInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: interval) ?? ""
    }
}

// MARK: - Preview
#Preview {
    HabitListView()
        .environment(HabitStore())
}

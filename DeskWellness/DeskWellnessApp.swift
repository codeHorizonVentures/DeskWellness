//
//  DeskWellnessApp.swift
//  DeskWellness
//
//  Created by P Dev on 30.04.2025.
//

import SwiftUI

@main
struct DeskWellnessApp: App {
    @State private var habitStore = HabitStore()

    var body: some Scene {
        WindowGroup {
            HabitListView()
                .environment(habitStore)
                .onAppear {
                    NotificationManager.shared.habitStore = habitStore
                    NotificationManager.shared.requestAuthorization()
                    scheduleInitialNotifications()
                }
        }
    }

    private func scheduleInitialNotifications() {
        for habit in habitStore.habits.filter({ $0.isEnabled }) {
            NotificationManager.shared.scheduleHabitNotification(habit)
        }
    }
}

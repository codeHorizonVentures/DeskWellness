//
//  DeskWellnessApp.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 30.04.2025.
//

import SwiftUI
import SwiftData

@main
struct DeskWellnessApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [DailyEntry.self])
    }
}

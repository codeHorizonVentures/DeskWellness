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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [DailyEntry.self])
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

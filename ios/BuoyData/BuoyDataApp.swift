//
//  BuoyDataApp.swift
//  BuoyData
//
//  Created by Erik Savage on 1/6/25.
//

import SwiftUI
import WidgetKit

@main
struct BuoyDataApp: App {
    init() {
        let sharedDefaults = UserDefaults(suiteName: "group.BuoyData")
        sharedDefaults?.set("44065", forKey: "favoriteBuoy") // Set default buoy ID

        DispatchQueue.main.async {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

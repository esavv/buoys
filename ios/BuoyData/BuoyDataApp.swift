//
//  BuoyDataApp.swift
//  BuoyData
//
//  Created by Erik Savage on 1/6/25.
//

import SwiftUI

@main
struct BuoyDataApp: App {
    init() {
        let sharedDefaults = UserDefaults(suiteName: "group.BuoyData")
        sharedDefaults?.set("44065", forKey: "favoriteBuoy") // Set default buoy ID
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

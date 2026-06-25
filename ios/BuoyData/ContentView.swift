//
//  ContentView.swift
//  BuoyData
//
//  Created by Erik Savage on 1/6/25.
//

import SwiftUI
import MapKit
import UIKit

enum AppTab: Hashable {
    case favorites, map
}

struct ContentView: View {
    @State private var store = FavoritesStore()
    @State private var selectedTab: AppTab = .favorites
    @State private var focusedMapStationID: String?

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "TabFooterSurface") ?? .secondarySystemBackground
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: .favorites) {
                FavoritesView(
                    selectedTab: $selectedTab,
                    focusedMapStationID: $focusedMapStationID
                )
            } label: {
                Label("Favorites", systemImage: "star.fill")
            }

            Tab(value: .map) {
                MapView(focusedStationID: $focusedMapStationID)
            } label: {
                Label("Map", systemImage: "map")
            }
        }
        .environment(store)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .background {
            Map()
                .frame(width: 1, height: 1)
                .opacity(0.01)
        }
    }
}

#Preview {
    ContentView()
}

//
//  ContentView.swift
//  BuoyData
//
//  Created by Erik Savage on 1/6/25.
//

import SwiftUI
import MapKit

enum AppTab: Hashable {
    case favorites, map
}

struct ContentView: View {
    @State private var store = FavoritesStore()
    @State private var selectedTab: AppTab = .favorites

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .secondarySystemBackground
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: .favorites) {
                FavoritesView(selectedTab: $selectedTab)
            } label: {
                Label("Favorites", systemImage: "star.fill")
            }

            Tab(value: .map) {
                MapView()
            } label: {
                Label("Map", systemImage: "map")
            }
        }
        .environment(store)
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

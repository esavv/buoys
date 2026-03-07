//
//  ContentView.swift
//  BuoyData
//
//  Created by Erik Savage on 1/6/25.
//

import SwiftUI
import MapKit

struct ContentView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .secondarySystemBackground
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            Tab {
                SearchView()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }

            Tab {
                MapView()
            } label: {
                Label("Map", systemImage: "map")
            }
        }
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

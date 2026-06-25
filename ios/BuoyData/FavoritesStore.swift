//
//  FavoritesStore.swift
//  BuoyData
//
//  Created by Erik Savage on 3/7/26.
//

import Foundation
import WidgetKit

struct FavoriteBuoy: Codable, Identifiable, Equatable, Hashable {
    let id: String
}

@Observable
class FavoritesStore {
    private static let suiteName = APIConfig.appGroupID
    private static let key = "favoriteStations"
    private static let legacyKey = "favoriteBuoy"

    var favorites: [FavoriteBuoy] = []

    var widgetBuoyId: String? {
        favorites.first?.id
    }

    init() {
        load()
    }

    func add(_ buoyId: String) {
        guard !favorites.contains(where: { $0.id == buoyId }) else { return }
        favorites.append(FavoriteBuoy(id: buoyId))
        save()
    }

    func remove(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func contains(_ buoyId: String) -> Bool {
        favorites.contains { $0.id == buoyId }
    }

    private func load() {
        let defaults = UserDefaults(suiteName: Self.suiteName)

        if let data = defaults?.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([FavoriteBuoy].self, from: data) {
            favorites = decoded
        }
    }

    private func save() {
        let defaults = UserDefaults(suiteName: Self.suiteName)
        if let data = try? JSONEncoder().encode(favorites) {
            defaults?.set(data, forKey: Self.key)
        }
        if let widgetId = widgetBuoyId {
            defaults?.set(widgetId, forKey: Self.legacyKey)
        } else {
            defaults?.removeObject(forKey: Self.legacyKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

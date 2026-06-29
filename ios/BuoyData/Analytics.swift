//
//  Analytics.swift
//  BuoyData
//

import Foundation

enum Analytics {
    enum ClientSource: String {
        case iosApp = "ios_app"
        case iosWidget = "ios_widget"
    }

    enum Event: String {
        case appOpened = "app opened"
        case screenViewed = "screen viewed"
        case favoriteAddedByID = "favorite added by id"
        case favoriteAddedFromMap = "favorite added from map"
        case favoriteRemoved = "favorite removed"
        case favoriteReordered = "favorite reordered"
        case addBuoyOpened = "add buoy opened"
        case chartInteracted = "chart interacted"
    }

    private static let distinctIDKey = "analyticsDistinctID"
    private static let analyticsIDHeader = "X-Buoys-Analytics-ID"
    private static let clientSourceHeader = "X-Buoys-Client"

    static var distinctID: String {
        let defaults = UserDefaults(suiteName: APIConfig.appGroupID)

        if let existing = defaults?.string(forKey: distinctIDKey), !existing.isEmpty {
            return existing
        }

        let newID = UUID().uuidString
        defaults?.set(newID, forKey: distinctIDKey)
        return newID
    }

    static func request(for url: URL, source: ClientSource) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(distinctID, forHTTPHeaderField: analyticsIDHeader)
        request.setValue(source.rawValue, forHTTPHeaderField: clientSourceHeader)
        return request
    }

    static func trackScreen(_ screenName: String, properties: [String: Any] = [:]) {
        var eventProperties = properties
        eventProperties["screen_name"] = screenName
        track(.screenViewed, properties: eventProperties)
    }

    static func track(_ event: Event, source: ClientSource = .iosApp, properties: [String: Any] = [:]) {
        guard let url = APIConfig.analyticsEventsURL else { return }

        let payload: [String: Any] = [
            "event": event.rawValue,
            "distinct_id": distinctID,
            "source": source.rawValue,
            "properties": properties.merging(defaultProperties(source: source)) { current, _ in current },
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let body = try? JSONSerialization.data(withJSONObject: payload)
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(distinctID, forHTTPHeaderField: analyticsIDHeader)
        request.setValue(source.rawValue, forHTTPHeaderField: clientSourceHeader)

        URLSession.shared.dataTask(with: request).resume()
    }

    private static func defaultProperties(source: ClientSource) -> [String: Any] {
        let bundle = Bundle.main
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        var properties: [String: Any] = [
            "source": source.rawValue,
            "platform": "ios",
            "os_version": ProcessInfo.processInfo.operatingSystemVersionString,
            "bundle_id": bundle.bundleIdentifier ?? "unknown",
        ]

        if let appVersion {
            properties["app_version"] = appVersion
        }

        if let buildNumber {
            properties["build_number"] = buildNumber
        }

        return properties
    }
}

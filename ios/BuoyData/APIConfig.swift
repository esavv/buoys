//
//  APIConfig.swift
//  BuoyData
//
//  Shared configuration for API access.
//  NOTE: Add this file to both BuoyData and BuoyDataWidgetExtension targets in Xcode.
//

import Foundation

enum APIConfig {
    static let appGroupID: String = {
        #if DEBUG
        return "group.BuoyData.dev"
        #else
        return "group.BuoyData"
        #endif
    }()

    static let baseURL = "https://api.buoy-data.com"
    
    static func buoyURL(for buoyID: String) -> URL? {
        URL(string: "\(baseURL)/buoy?id=\(buoyID)")
    }

    static var stationsURL: URL? {
        URL(string: "\(baseURL)/stations")
    }
}

struct Station: Codable, Identifiable {
    let id: String
    let lat: Double
    let lon: Double
    let name: String
    let owner: String
}

struct StationsResponse: Codable {
    let status: String
    let count: Int?
    let stations: [Station]?
    let errorMsg: String?

    enum CodingKeys: String, CodingKey {
        case status, count, stations
        case errorMsg = "error_msg"
    }
}

/// Response model for the buoy API endpoint
struct BuoyResponse: Codable {
    let status: String
    let name: String?
    let lastUpdated: String?
    let observationTime: String?
    let sigWaveHeightFt: String?
    let swellHeightFt: String?
    let swellPeriodS: String?
    let swellDirection: String?
    let errorMsg: String?
    
    enum CodingKeys: String, CodingKey {
        case status, name
        case lastUpdated = "last_updated"
        case observationTime = "observation_time"
        case sigWaveHeightFt = "sig_wave_height_ft"
        case swellHeightFt = "swell_height_ft"
        case swellPeriodS = "swell_period_s"
        case swellDirection = "swell_direction"
        case errorMsg = "error_msg"
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    var observationDate: Date? {
        guard let observationTime else { return nil }
        return Self.isoFormatter.date(from: observationTime)
    }

    /// True when observation is less than 24 hours old, or when we can't
    /// determine the observation time (backward-compat with older API).
    var isRecent: Bool {
        guard let date = observationDate else { return true }
        return Date().timeIntervalSince(date) < 24 * 60 * 60
    }

    var staleDisplayString: String? {
        guard let date = observationDate, !isRecent else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a zzz 'on' MMM d, yyyy"
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return "No data since \(formatter.string(from: date))"
    }
}


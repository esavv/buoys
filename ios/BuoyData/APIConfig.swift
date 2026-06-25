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

    static func buoyHistoryURL(for buoyID: String, hours: Int = 24) -> URL? {
        URL(string: "\(baseURL)/buoy/history?id=\(buoyID)&hours=\(hours)")
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
    let waterTempC: String?
    let meanWaveDirectionDeg: String?
    let lat: Double?
    let lon: Double?
    let errorMsg: String?
    
    enum CodingKeys: String, CodingKey {
        case status, name
        case lastUpdated = "last_updated"
        case observationTime = "observation_time"
        case sigWaveHeightFt = "sig_wave_height_ft"
        case swellHeightFt = "swell_height_ft"
        case swellPeriodS = "swell_period_s"
        case swellDirection = "swell_direction"
        case waterTempC = "water_temp_c"
        case meanWaveDirectionDeg = "mean_wave_direction_deg"
        case lat, lon
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

    /// Water temperature in Fahrenheit for display; "N/A" when missing or invalid.
    var waterTempFDisplay: String {
        guard let raw = waterTempC, raw != "N/A", let c = Double(raw) else { return "N/A" }
        let f = c * 9 / 5 + 32
        return String(format: "%.1f", f)
    }
}

struct BuoyHistoryResponse: Codable {
    let status: String
    let stationID: String?
    let name: String?
    let hours: Int?
    let points: [BuoyHistoryPoint]?
    let errorMsg: String?

    enum CodingKeys: String, CodingKey {
        case status, name, hours, points
        case stationID = "station_id"
        case errorMsg = "error_msg"
    }
}

struct BuoyHistoryPoint: Codable, Identifiable {
    let observationTime: String
    let sigWaveHeightFt: Double?
    let swellHeightFt: Double?
    let swellPeriodS: Double?
    let swellDirection: String?
    let swellDirectionDeg: Double?
    let meanWaveDirectionDeg: Double?
    let waterTempC: Double?

    var id: String { observationTime }

    enum CodingKeys: String, CodingKey {
        case observationTime = "observation_time"
        case sigWaveHeightFt = "sig_wave_height_ft"
        case swellHeightFt = "swell_height_ft"
        case swellPeriodS = "swell_period_s"
        case swellDirection = "swell_direction"
        case swellDirectionDeg = "swell_direction_deg"
        case meanWaveDirectionDeg = "mean_wave_direction_deg"
        case waterTempC = "water_temp_c"
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    var date: Date? {
        Self.isoFormatter.date(from: observationTime)
    }

    var waterTempF: Double? {
        guard let waterTempC else { return nil }
        return waterTempC * 9 / 5 + 32
    }
}

enum BuoyAPIClient {
    static func fetchCurrentBuoy(id: String) async throws -> BuoyResponse {
        guard let url = APIConfig.buoyURL(for: id) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(BuoyResponse.self, from: data)
    }

    static func fetchHistory(id: String, hours: Int = 24) async throws -> BuoyHistoryResponse {
        guard let url = APIConfig.buoyHistoryURL(for: id, hours: hours) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(BuoyHistoryResponse.self, from: data)
    }
}


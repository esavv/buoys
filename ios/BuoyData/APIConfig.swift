//
//  APIConfig.swift
//  BuoyData
//
//  Shared configuration for API access.
//  NOTE: Add this file to both BuoyData and BuoyDataWidgetExtension targets in Xcode.
//

import Foundation

enum APIConfig {
    static let baseURL = "https://api.buoy-data.com"
    
    static func buoyURL(for buoyID: String) -> URL? {
        URL(string: "\(baseURL)/buoy?id=\(buoyID)")
    }
}

/// Response model for the buoy API endpoint
struct BuoyResponse: Codable {
    let status: String
    let lastUpdated: String?
    let sigWaveHeightFt: String?
    let swellHeightFt: String?
    let swellPeriodS: String?
    let swellDirection: String?
    let errorMsg: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case lastUpdated = "last_updated"
        case sigWaveHeightFt = "sig_wave_height_ft"
        case swellHeightFt = "swell_height_ft"
        case swellPeriodS = "swell_period_s"
        case swellDirection = "swell_direction"
        case errorMsg = "error_msg"
    }
}


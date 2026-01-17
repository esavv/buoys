//
//  BuoyDataWidget.swift
//  BuoyDataWidget
//
//  Created by Erik Savage on 1/23/25.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), waveHeight: "—", swellHeight: "—", swellPeriod: "—", swellDirection: "—", lastUpdated: "—", buoyID: "—", errorMessage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: "group.BuoyData")
        let buoyID = sharedDefaults?.string(forKey: "favoriteBuoy") ?? "44065"
        // Call the shared fetch function (this example uses async/await)
        Task {
            let (waveHeight, swellHeight, swellPeriod, swellDirection, lastUpdated, errorMessage) = await fetchBuoyData(for: buoyID)
            let entry = SimpleEntry(date: Date(), waveHeight: waveHeight, swellHeight: swellHeight, swellPeriod: swellPeriod, swellDirection: swellDirection, lastUpdated: lastUpdated, buoyID: buoyID, errorMessage: errorMessage)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: "group.BuoyData")
        let buoyID = sharedDefaults?.string(forKey: "favoriteBuoy") ?? "44065"
        // Fetch the data for the widget
        Task {
            let (waveHeight, swellHeight, swellPeriod, swellDirection, lastUpdated, errorMessage) = await fetchBuoyData(for: buoyID)

            // Create a single entry for the current time
            let currentDate = Date()
            let entry = SimpleEntry(date: Date(), waveHeight: waveHeight, swellHeight: swellHeight, swellPeriod: swellPeriod, swellDirection: swellDirection, lastUpdated: lastUpdated, buoyID: buoyID, errorMessage: errorMessage)

            // Set the refresh policy to update hourly
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))

            completion(timeline)
        }
    }

    // Fetch buoy data from the API
    // Returns (waveHeight, swellHeight, swellPeriod, swellDirection, lastUpdated, errorMessage)
    func fetchBuoyData(for buoyID: String) async -> (String, String, String, String, String, String?) {
        guard let url = APIConfig.buoyURL(for: buoyID) else {
            print("Widget error: Invalid URL")
            return ("", "", "", "", "", "Invalid URL")
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let buoyResponse = try decoder.decode(BuoyResponse.self, from: data)
            
            if buoyResponse.status == "success" {
                let waveHeight = buoyResponse.sigWaveHeightFt ?? "N/A"
                let swellHeight = buoyResponse.swellHeightFt ?? "N/A"
                let swellPeriod = buoyResponse.swellPeriodS ?? "N/A"
                let swellDirection = buoyResponse.swellDirection ?? "N/A"
                let lastUpdated = buoyResponse.lastUpdated ?? "N/A"
                return (waveHeight, swellHeight, swellPeriod, swellDirection, lastUpdated, nil)
            } else {
                let errorMsg = buoyResponse.errorMsg ?? "Unknown API error"
                print("Widget API error: \(errorMsg)")
                return ("", "", "", "", "", errorMsg)
            }
        } catch {
            print("Widget fetch error: \(error.localizedDescription)")
            return ("", "", "", "", "", error.localizedDescription)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let waveHeight: String
    let swellHeight: String
    let swellPeriod: String
    let swellDirection: String
    let lastUpdated: String
    let buoyID: String
    let errorMessage: String?
}

struct BuoyDataWidgetEntryView : View {
    var entry: Provider.Entry
    
    // Formats "8:40 pm EST" to "8:40pm"
    private func formatTime(_ timeString: String) -> String {
        // Remove timezone by taking only the time and am/pm parts
        let components = timeString.split(separator: " ")
        guard components.count >= 2 else { return timeString }
        let time = String(components[0])
        let ampm = String(components[1])
        return time + ampm
    }

    var body: some View {
        VStack(alignment: .center, spacing: 1) {
            Text("\(entry.buoyID)")
                .font(.system(size: 8))
            
            if entry.errorMessage != nil {
                Spacer().frame(height: 6)
                Text("Server\nError")
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                HStack(spacing: 4) {
                    Text(entry.waveHeight).font(.system(size: 12)) + Text(" ft").font(.system(size: 8))
                    Text(entry.swellHeight).font(.system(size: 12)) + Text(" ft").font(.system(size: 8))
                }
                HStack(spacing: 4) {
                    Text(entry.swellPeriod).font(.system(size: 12)) + Text(" s").font(.system(size: 8))
                    Text(entry.swellDirection)
                        .font(.system(size: 12))
                }
                Text(formatTime(entry.lastUpdated))
                    .font(.system(size: 8))
            }
        }
    }
}

struct BuoyDataWidget: Widget {
    let kind: String = "BuoyDataWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                BuoyDataWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                BuoyDataWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("BuoyDataWidget")
        .description("Display live swell data from your favorite buoy.")
        .supportedFamilies([.accessoryCircular]) // Ensure only lock screen widget type
    }
}

#Preview(as: .accessoryCircular) {
    BuoyDataWidget()
} timeline: {
    SimpleEntry(date: .now, waveHeight: "5.2", swellHeight: "4.8", swellPeriod: "7", swellDirection: "ESE", lastUpdated: "3:45 pm", buoyID: "44065", errorMessage: nil)
    SimpleEntry(date: .now, waveHeight: "", swellHeight: "", swellPeriod: "", swellDirection: "", lastUpdated: "", buoyID: "44065", errorMessage: "Network error")
}

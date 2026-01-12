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
        SimpleEntry(date: Date(), waveHeight: "Loading...", swellPeriod: "Loading...", swellDirection: "Loading...", buoyID: "Loading...")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: "group.BuoyData")
        let buoyID = sharedDefaults?.string(forKey: "favoriteBuoy") ?? "44065"
        // Call the shared fetch function (this example uses async/await)
        Task {
            let (waveHeight, swellPeriod, swellDirection) = await fetchBuoyData(for: buoyID)
            let entry = SimpleEntry(date: Date(), waveHeight: waveHeight, swellPeriod: swellPeriod, swellDirection: swellDirection, buoyID: buoyID)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: "group.BuoyData")
        let buoyID = sharedDefaults?.string(forKey: "favoriteBuoy") ?? "44065"
        // Fetch the data for the widget (wave height, swell period, swell direction)
        Task {
            let (waveHeight, swellPeriod, swellDirection) = await fetchBuoyData(for: buoyID)

            // Create a single entry for the current time
            let currentDate = Date()
            let entry = SimpleEntry(date: Date(), waveHeight: waveHeight, swellPeriod: swellPeriod, swellDirection: swellDirection, buoyID: buoyID)

            // Set the refresh policy to update hourly
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))

            completion(timeline)
        }
    }

    // Fetch buoy data from the API
    func fetchBuoyData(for buoyID: String) async -> (String, String, String) {
        guard let url = APIConfig.buoyURL(for: buoyID) else {
            return ("Error: Invalid URL", "N/A", "N/A")
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let buoyResponse = try decoder.decode(BuoyResponse.self, from: data)
            
            if buoyResponse.status == "success" {
                let waveHeight = buoyResponse.sigWaveHeightFt ?? "N/A"
                let swellPeriod = buoyResponse.swellPeriodS ?? "N/A"
                let swellDirection = buoyResponse.swellDirection ?? "N/A"
                return (waveHeight, swellPeriod, swellDirection)
            } else {
                return ("Error: \(buoyResponse.errorMsg ?? "Unknown")", "N/A", "N/A")
            }
        } catch {
            return ("Error: \(error.localizedDescription)", "N/A", "N/A")
        }
    }
    //    func relevances() async -> WidgetRelevances<Void> {
    //        // Generate a list containing the contexts this widget is relevant in.
    //    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let waveHeight: String
    let swellPeriod: String
    let swellDirection: String
    let buoyID: String
}

struct BuoyDataWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .center, spacing: -1) {
            Text("\(entry.buoyID)")
                .font(.system(size: 8))
            HStack {
                Text("\(entry.waveHeight) ft")
                    .font(.system(size: 15))
            }
            HStack {
                Text("\(entry.swellPeriod) s")
                    .font(.system(size: 15))
            }
            HStack {
                Text(entry.swellDirection)
                    .font(.system(size: 15))
//                    .font(.footnote)
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
    SimpleEntry(date: .now, waveHeight: "5.2 ft", swellPeriod: "7 s", swellDirection: "ESE", buoyID: "44065")
    SimpleEntry(date: .now, waveHeight: "5.2 ft", swellPeriod: "7 s", swellDirection: "ESE", buoyID: "44065")
}

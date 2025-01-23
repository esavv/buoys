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
        SimpleEntry(date: Date(), waveHeight: "Loading...", swellPeriod: "Loading...", swellDirection: "Loading...")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        // Call the shared fetch function (this example uses async/await)
        Task {
            let (waveHeight, swellPeriod, swellDirection) = await fetchBuoyData()
            let entry = SimpleEntry(date: Date(), waveHeight: waveHeight, swellPeriod: swellPeriod, swellDirection: swellDirection)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        let currentDate = Date()

        // Fetch the data for the widget (wave height in this case)
        Task {
            let (waveHeight, swellPeriod, swellDirection) = await fetchBuoyData()

            for hourOffset in 0..<24 {
                let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
                let entry = SimpleEntry(date: entryDate, waveHeight: waveHeight, swellPeriod: swellPeriod, swellDirection: swellDirection)
                entries.append(entry)
            }

            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
    }

    // The fetch and parse logic for buoy data
    func fetchBuoyData() async -> (String, String, String) {
        guard let url = URL(string: "https://www.ndbc.noaa.gov/data/realtime2/44065.spec") else {
            return ("Error: Invalid URL", "N/A", "N/A")
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let content = String(data: data, encoding: .utf8) {
                return parseBuoyData(content)
            } else {
                return ("Error: Invalid data format", "N/A", "N/A")
            }
        } catch {
            return ("Error: \(error.localizedDescription)", "N/A", "N/A")
        }
    }

    func parseBuoyData(_ content: String) -> (String, String, String) {
        let lines = content.split(separator: "\n")
        guard lines.count > 2 else {
            return ("Error: Unexpected file format", "N/A", "N/A")
        }

        // Column headers
        let headers = lines[0].split(separator: " ", omittingEmptySubsequences: true)
        // Most recent data (third row)
        let latestData = lines[2].split(separator: " ", omittingEmptySubsequences: true)

        if let waveHeightIndex = headers.firstIndex(of: "WVHT"),
           let swellPeriodIndex = headers.firstIndex(of: "SwP"),
           let swellDirectionIndex = headers.firstIndex(of: "SwD") {
            var waveHeight = "N/A"
            if let waveHeightMeters = Double(latestData[waveHeightIndex]) {
                let waveHeightFeet = waveHeightMeters * 3.28084
                waveHeight = String(format: "%.1f ft", waveHeightFeet) // Format to 1 decimal place
            } else {
                return ("Error: Invalid wave height data", "N/A", "N/A")
            }
            let swellPeriod = String(latestData[swellPeriodIndex])
            let swellDirection = String(latestData[swellDirectionIndex])
            
            return (waveHeight, swellPeriod, swellDirection)
        } else {
            return ("Error: Could not find required headers", "N/A", "N/A")
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
}

struct BuoyDataWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading) {
            Text("Height: \(entry.waveHeight)")
            Text("Period: \(entry.swellPeriod) s")
            Text("Direction: \(entry.swellDirection)")
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
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
        .supportedFamilies([.accessoryRectangular]) // Ensure only lock screen widget type
    }
}

#Preview(as: .accessoryRectangular) {
    BuoyDataWidget()
} timeline: {
    SimpleEntry(date: .now, waveHeight: "5.2 ft", swellPeriod: "7 s", swellDirection: "ESE")
    SimpleEntry(date: .now, waveHeight: "5.2 ft", swellPeriod: "7 s", swellDirection: "ESE")
}

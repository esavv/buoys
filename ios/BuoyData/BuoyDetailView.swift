//
//  BuoyDetailView.swift
//  BuoyData
//

import Charts
import SwiftUI

struct BuoyDetailView: View {
    let buoy: FavoriteBuoy

    @State private var currentData: BuoyResponse?
    @State private var historyData: BuoyHistoryResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var title: String {
        currentData?.name ?? historyData?.name ?? "Station \(buoy.id)"
    }

    private var historyPoints: [BuoyHistoryPoint] {
        (historyData?.points ?? []).filter { $0.date != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard

                if isLoading && historyPoints.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    chartsSection
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .background(Color("FavoriteScreenBackground").ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: buoy.id) {
            await loadData()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)

                Text("Station \(buoy.id)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let currentData, currentData.status == "success" {
                FavoriteBuoyReadings(data: currentData)
            } else if isLoading {
                ProgressView()
                    .padding(.vertical, 4)
            } else {
                Text("Current readings unavailable")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("FavoriteCardSurface"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Last 24 Hours")
                .font(.headline)

            MetricChartCard(
                title: "Wave Height",
                unit: "ft",
                points: historyPoints,
                value: \.sigWaveHeightFt
            )

            MetricChartCard(
                title: "Swell Height",
                unit: "ft",
                points: historyPoints,
                value: \.swellHeightFt
            )

            MetricChartCard(
                title: "Swell Period",
                unit: "s",
                points: historyPoints,
                value: \.swellPeriodS
            )

            DirectionChartCard(points: historyPoints)

            MetricChartCard(
                title: "Water Temp",
                unit: "°F",
                points: historyPoints,
                value: \.waterTempF,
                yScale: .roundedToFive
            )
        }
    }

    @MainActor
    private func loadData() async {
        isLoading = true
        errorMessage = nil

        async let currentRequest = BuoyAPIClient.fetchCurrentBuoy(id: buoy.id)
        async let historyRequest = BuoyAPIClient.fetchHistory(id: buoy.id)

        var loadErrors: [String] = []

        do {
            currentData = try await currentRequest
        } catch {
            currentData = nil
            loadErrors.append("current readings")
        }

        do {
            historyData = try await historyRequest
        } catch {
            historyData = nil
            loadErrors.append("history")
        }

        if !loadErrors.isEmpty {
            errorMessage = "Could not load \(loadErrors.joined(separator: " or ")). Pull back and try again."
        }

        isLoading = false
    }
}

private struct MetricChartCard: View {
    let title: String
    let unit: String
    let data: [MetricChartDataPoint]
    let yScaleDomain: ClosedRange<Double>?

    init(
        title: String,
        unit: String,
        points: [BuoyHistoryPoint],
        value metricValue: KeyPath<BuoyHistoryPoint, Double?>,
        yScale: MetricChartYScale = .automatic
    ) {
        self.title = title
        self.unit = unit
        let data: [MetricChartDataPoint] = points.compactMap { point in
            guard let date = point.date, let chartValue = point[keyPath: metricValue] else { return nil }
            return MetricChartDataPoint(date: date, value: chartValue)
        }
        self.data = data
        self.yScaleDomain = yScale.domain(for: data.map { $0.value })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if data.isEmpty {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                chart
                    .frame(height: 160)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("FavoriteCardSurface"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }

    @ViewBuilder
    private var chart: some View {
        let baseChart = Chart(data) { point in
            LineMark(
                x: .value("Time", point.date),
                y: .value(title, point.value)
            )
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Time", point.date),
                y: .value(title, point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.linearGradient(
                colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }

        if let yScaleDomain {
            baseChart.chartYScale(domain: yScaleDomain)
        } else {
            baseChart
        }
    }
}

private struct MetricChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

private enum MetricChartYScale {
    case automatic
    case roundedToFive

    func domain(for values: [Double]) -> ClosedRange<Double>? {
        switch self {
        case .automatic:
            return nil
        case .roundedToFive:
            guard let minValue = values.min(), let maxValue = values.max() else { return nil }

            let interval = 5.0
            let lower = floor(minValue / interval) * interval
            var upper = ceil(maxValue / interval) * interval

            if upper <= lower {
                upper = lower + interval
            }

            return lower...upper
        }
    }
}

private struct DirectionChartCard: View {
    let points: [BuoyHistoryPoint]

    private var directionPoints: [BuoyHistoryPoint] {
        points.filter { $0.swellDirectionDeg != nil || $0.meanWaveDirectionDeg != nil }
    }

    private var sampledPoints: [BuoyHistoryPoint] {
        sample(directionPoints, maxCount: 7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Swell Direction")
                    .font(.subheadline.weight(.semibold))
                Text("Wave direction below each point")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if sampledPoints.isEmpty {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 110)
            } else {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(sampledPoints) { point in
                        DirectionSampleView(point: point)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("FavoriteCardSurface"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }

    private func sample(_ values: [BuoyHistoryPoint], maxCount: Int) -> [BuoyHistoryPoint] {
        guard values.count > maxCount, maxCount > 1 else { return values }

        let step = Double(values.count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { index in
            values[Int((Double(index) * step).rounded())]
        }
    }
}

private struct DirectionSampleView: View {
    let point: BuoyHistoryPoint

    private var arrowDegrees: Double {
        (point.swellDirectionDeg ?? point.meanWaveDirectionDeg ?? 0) + 180
    }

    private var waveDirectionText: String {
        guard let degrees = point.meanWaveDirectionDeg else { return "N/A" }
        return "\(Int(degrees.rounded()))°"
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "arrow.up")
                .font(.subheadline.weight(.semibold))
                .rotationEffect(.degrees(arrowDegrees))
                .frame(width: 22, height: 22)
                .foregroundStyle(Color.accentColor)

            Text(point.swellDirection ?? "N/A")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(waveDirectionText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let date = point.date {
                Text(date, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        BuoyDetailView(buoy: FavoriteBuoy(id: "44065"))
    }
}

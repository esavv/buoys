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

    private var stationTitle: String {
        "Station \(buoy.id)"
    }

    private var buoyName: String {
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
        .navigationTitle(stationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: buoy.id) {
            await loadData()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(buoyName)
                .font(.title3.weight(.semibold))
                .lineLimit(2)

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
                title: "Water Temperature",
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
    let fillBaseline: Double
    @State private var selectedDate: Date?
    @State private var selectionLayout = MetricChartSelectionLayout()

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
        let yScaleDomain = yScale.domain(for: data.map { $0.value })
        self.yScaleDomain = yScaleDomain
        self.fillBaseline = yScaleDomain?.lowerBound ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if let selectedPoint {
                    selectedTimeCallout(for: selectedPoint)
                }
            }
            .frame(height: 24)
            .padding(.bottom, 2)

            if data.isEmpty {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                selectedValueRow

                chart
                    .frame(height: 160)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 16)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("FavoriteCardSurface"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }

    @ViewBuilder
    private var chart: some View {
        let baseChart = Chart {
            ForEach(data) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Baseline", fillBaseline),
                    yEnd: .value(title, point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.linearGradient(
                    colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                ))

                LineMark(
                    x: .value("Time", point.date),
                    y: .value(title, point.value)
                )
                .interpolationMethod(.catmullRom)
            }

            if let selectedPoint {
                RuleMark(x: .value("Selected Time", selectedPoint.date))
                    .foregroundStyle(.secondary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("Selected Time", selectedPoint.date),
                    y: .value(title, selectedPoint.value)
                )
                .foregroundStyle(Color.accentColor)
                .symbolSize(42)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let axisValue = value.as(Double.self) {
                        Text("\(formattedAxisValue(axisValue)) \(axisUnit)")
                            .offset(x: 4)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formattedAxisTime(date))
                    }
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrameAnchor = proxy.plotFrame {
                    let plotFrame = geometry[plotFrameAnchor]
                    let selectedX = selectedPoint
                        .flatMap { proxy.position(forX: $0.date) }
                        .map { plotFrame.minX + $0 }

                    Color.clear.preference(
                        key: MetricChartSelectionLayoutKey.self,
                        value: MetricChartSelectionLayout(plotFrame: plotFrame, selectedX: selectedX)
                    )
                } else {
                    Color.clear.preference(
                        key: MetricChartSelectionLayoutKey.self,
                        value: MetricChartSelectionLayout()
                    )
                }
            }
        }
        .onPreferenceChange(MetricChartSelectionLayoutKey.self) { layout in
            selectionLayout = layout
        }

        if let yScaleDomain {
            baseChart.chartYScale(domain: yScaleDomain)
        } else {
            baseChart
        }
    }

    private var selectedValueRow: some View {
        GeometryReader { geometry in
            if let selectedPoint, let selectedX = selectionLayout.selectedX {
                selectedValueCallout(for: selectedPoint)
                    .position(
                        x: clamped(
                            selectedX,
                            min: selectionLayout.plotFrame.minX,
                            max: min(selectionLayout.plotFrame.maxX, geometry.size.width)
                        ),
                        y: geometry.size.height / 2
                    )
            } else {
                selectionPlaceholder
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .frame(height: 24)
    }

    private var selectedPoint: MetricChartDataPoint? {
        guard let selectedDate else { return nil }

        return data.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var selectionPlaceholder: some View {
        Text("00:00 PM")
            .font(.caption.weight(.semibold))
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .opacity(0)
    }

    private func selectedTimeCallout(for point: MetricChartDataPoint) -> some View {
        Text(formattedTime(point.date))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
    }

    private func selectedValueCallout(for point: MetricChartDataPoint) -> some View {
        Text(formattedValue(point.value))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
    }

    private func clamped(_ value: CGFloat, min lowerBound: CGFloat, max upperBound: CGFloat) -> CGFloat {
        min(max(value, lowerBound), upperBound)
    }

    private func formattedValue(_ value: Double) -> String {
        "\(String(format: "%.1f", value)) \(unit)"
    }

    private var axisUnit: String {
        unit == "°F" ? "F" : unit
    }

    private func formattedAxisValue(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.1f", value)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formattedAxisTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }
}

private struct MetricChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

private struct MetricChartSelectionLayout: Equatable {
    var plotFrame: CGRect = .zero
    var selectedX: CGFloat?
}

private struct MetricChartSelectionLayoutKey: PreferenceKey {
    static let defaultValue = MetricChartSelectionLayout()

    static func reduce(value: inout MetricChartSelectionLayout, nextValue: () -> MetricChartSelectionLayout) {
        value = nextValue()
    }
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
            Text("Swell Direction")
                .font(.subheadline.weight(.semibold))

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

    private var timeText: String? {
        guard let date = point.date else { return nil }

        let minute = Calendar.current.component(.minute, from: date)
        let formatter = DateFormatter()
        formatter.dateFormat = minute == 0 ? "h a" : "h:mm a"
        return formatter.string(from: date)
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

            if let timeText {
                Text(timeText)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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

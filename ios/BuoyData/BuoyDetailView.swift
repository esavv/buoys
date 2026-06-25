//
//  BuoyDetailView.swift
//  BuoyData
//

import Charts
import MapKit
import SwiftUI

struct BuoyDetailView: View {
    let buoy: FavoriteBuoy

    @State private var currentData: BuoyResponse?
    @State private var historyData: BuoyHistoryResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var buoyName: String? {
        currentData?.name ?? historyData?.name
    }

    private var historyPoints: [BuoyHistoryPoint] {
        (historyData?.points ?? []).filter { $0.date != nil }
    }

    private var buoyCoordinate: CLLocationCoordinate2D? {
        guard let lat = currentData?.lat, let lon = currentData?.lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
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
            .padding(.horizontal)
            .padding(.top, 2)
            .padding(.bottom)
        }
        .background(Color("FavoriteScreenBackground").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: buoy.id) {
            await loadData()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let buoyName {
                    Text(buoyName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)

                    Text("Station \(buoy.id)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Station \(buoy.id)")
                        .font(.title3.weight(.semibold))
                }
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

            CombinedHeightChartCard(points: historyPoints)

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

            if let buoyCoordinate {
                BuoyLocationMapCard(
                    coordinate: buoyCoordinate,
                    title: "Station \(buoy.id)"
                )
            }
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
        yScale: MetricChartYScale = .zeroBasedBuffered
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
            HStack(alignment: .center) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if let selectedPoint {
                    selectedTimeCallout(for: selectedPoint)
                } else {
                    selectionPlaceholder
                }
            }
            .frame(height: 18)

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
                            .offset(x: 4, y: 6)
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
                        x: selectedX,
                        y: geometry.size.height / 2
                    )
            } else {
                selectionPlaceholder
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .frame(height: 18)
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
            .opacity(0)
    }

    private func selectedTimeCallout(for point: MetricChartDataPoint) -> some View {
        Text(formattedTime(point.date))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
    }

    private func selectedValueCallout(for point: MetricChartDataPoint) -> some View {
        Text(formattedValue(point.value))
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
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

private struct CombinedHeightChartCard: View {
    private let title = "Wave & Swell Height"
    private let unit = "ft"
    private let waveColor = Color.accentColor
    private let swellColor = Color.green

    let data: [HeightChartDataPoint]
    let seriesData: [HeightChartSeriesPoint]
    let yScaleDomain: ClosedRange<Double>?
    let fillBaseline: Double

    @State private var selectedDate: Date?
    @State private var selectionLayout = MetricChartSelectionLayout()

    init(points: [BuoyHistoryPoint]) {
        let data: [HeightChartDataPoint] = points.compactMap { point in
            guard let date = point.date else { return nil }
            guard point.swellHeightFt != nil || point.sigWaveHeightFt != nil else { return nil }

            return HeightChartDataPoint(
                date: date,
                swellHeight: point.swellHeightFt,
                waveHeight: point.sigWaveHeightFt
            )
        }

        self.data = data

        self.seriesData = data.flatMap { point in
            [
                point.swellHeight.map {
                    HeightChartSeriesPoint(date: point.date, value: $0, series: .swell)
                },
                point.waveHeight.map {
                    HeightChartSeriesPoint(date: point.date, value: $0, series: .wave)
                },
            ].compactMap { $0 }
        }

        let values: [Double] = data.flatMap { point in
            [point.swellHeight, point.waveHeight].compactMap { $0 }
        }
        let yScaleDomain = MetricChartYScale.zeroBasedBuffered.domain(for: values)
        self.yScaleDomain = yScaleDomain
        self.fillBaseline = yScaleDomain?.lowerBound ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if let selectedPoint {
                    selectedTimeCallout(for: selectedPoint)
                } else {
                    selectionPlaceholder
                }
            }
            .frame(height: 18)

            if data.isEmpty {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                selectedValueRow

                chart
                    .frame(height: 160)

                legend
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
            ForEach(seriesData) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Baseline", fillBaseline),
                    yEnd: .value("Height", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Series", point.series.label))
                .opacity(point.series == .swell ? 0.16 : 0.14)

                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Height", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Series", point.series.label))
            }

            if let selectedPoint {
                RuleMark(x: .value("Selected Time", selectedPoint.date))
                    .foregroundStyle(.secondary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                if let waveHeight = selectedPoint.waveHeight {
                    PointMark(
                        x: .value("Selected Time", selectedPoint.date),
                        y: .value("Wave Height", waveHeight)
                    )
                    .foregroundStyle(waveColor)
                    .symbolSize(42)
                }

                if let swellHeight = selectedPoint.swellHeight {
                    PointMark(
                        x: .value("Selected Time", selectedPoint.date),
                        y: .value("Swell Height", swellHeight)
                    )
                    .foregroundStyle(swellColor)
                    .symbolSize(42)
                }
            }
        }
        .chartForegroundStyleScale([
            HeightChartSeries.swell.label: swellColor,
            HeightChartSeries.wave.label: waveColor,
        ])
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let axisValue = value.as(Double.self) {
                        Text("\(formattedAxisValue(axisValue)) \(unit)")
                            .offset(x: 4, y: 6)
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
                selectedValuesCallout(for: selectedPoint)
                    .position(x: selectedX, y: geometry.size.height / 2)
            } else {
                selectionPlaceholder
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .frame(height: 18)
    }

    private func selectedValuesCallout(for point: HeightChartDataPoint) -> some View {
        HStack(spacing: 6) {
            if let waveHeight = point.waveHeight {
                Text(formattedValue(waveHeight))
                    .foregroundStyle(waveColor)
            }

            if let swellHeight = point.swellHeight {
                Text(formattedValue(swellHeight))
                    .foregroundStyle(swellColor)
            }
        }
        .font(.caption.weight(.semibold))
    }

    private var legend: some View {
        HStack(spacing: 10) {
            Spacer()
            HeightChartLegendItem(color: waveColor, label: "Wave")
            HeightChartLegendItem(color: swellColor, label: "Swell")
        }
        .padding(.top, 4)
    }

    private var selectedPoint: HeightChartDataPoint? {
        guard let selectedDate else { return nil }

        return data.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var selectionPlaceholder: some View {
        Text("00:00 PM")
            .font(.caption.weight(.semibold))
            .opacity(0)
    }

    private func selectedTimeCallout(for point: HeightChartDataPoint) -> some View {
        Text(formattedTime(point.date))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
    }

    private func formattedValue(_ value: Double) -> String {
        "\(String(format: "%.1f", value)) \(unit)"
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

private struct HeightChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let swellHeight: Double?
    let waveHeight: Double?
}

private struct HeightChartSeriesPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let series: HeightChartSeries
}

private enum HeightChartSeries {
    case swell
    case wave

    var label: String {
        switch self {
        case .swell:
            return "Swell"
        case .wave:
            return "Wave"
        }
    }
}

private struct HeightChartLegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct BuoyLocationMapCard: View {
    let coordinate: CLLocationCoordinate2D
    let title: String

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 1.2, longitudeDelta: 1.2)
        )
    }

    var body: some View {
        Map(initialPosition: .region(region)) {
            Marker(title, coordinate: coordinate)
                .tint(.red)
        }
        .allowsHitTesting(false)
        .frame(height: 150)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
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
    case zeroBasedBuffered
    case roundedToFive

    func domain(for values: [Double]) -> ClosedRange<Double>? {
        switch self {
        case .zeroBasedBuffered:
            guard let maxValue = values.max() else { return nil }

            let upper = max(1, floor(maxValue) + 1)
            return 0...upper
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

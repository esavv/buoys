//
//  BuoyDetailView.swift
//  BuoyData
//

import Charts
import MapKit
import SwiftUI

struct BuoyDetailView: View {
    let buoy: FavoriteBuoy
    var onOpenMap: ((String) -> Void)? = nil

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
                        .font(.headline)
                        .lineLimit(2)

                    Text("Station \(buoy.id)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Station \(buoy.id)")
                        .font(.headline)
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
                .padding(.leading, 16)

            CombinedHeightChartCard(points: historyPoints)

            SwellPeriodDirectionChartCard(points: historyPoints)

            MetricChartCard(
                title: "Water Temperature",
                unit: "°F",
                points: historyPoints,
                value: \.waterTempF,
                yScale: .temperature
            )

            if let buoyCoordinate {
                BuoyLocationMapCard(
                    coordinate: buoyCoordinate,
                    title: "Station \(buoy.id)",
                    onTap: {
                        onOpenMap?(buoy.id)
                    }
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
    let yAxisSpec: ChartYAxisSpec?
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
        let yAxisSpec = yScale.axisSpec(for: data.map { $0.value })
        self.yAxisSpec = yAxisSpec
        self.fillBaseline = yAxisSpec?.domain.lowerBound ?? 0
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
        .padding(.leading, 16)
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
            if let yAxisSpec {
                AxisMarks(position: .leading, values: yAxisSpec.ticks) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let axisValue = value.as(Double.self) {
                            Text("\(formattedAxisValue(axisValue)) \(axisUnit)")
                                .offset(x: 4, y: 6)
                        }
                    }
                }
            } else {
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

        if let yAxisSpec {
            baseChart.chartYScale(domain: yAxisSpec.domain)
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
    let yAxisSpec: ChartYAxisSpec?
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
        let yAxisSpec = MetricChartYScale.zeroBasedBuffered.axisSpec(for: values)
        self.yAxisSpec = yAxisSpec
        self.fillBaseline = yAxisSpec?.domain.lowerBound ?? 0
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
        .padding(.leading, 16)
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
            if let yAxisSpec {
                AxisMarks(position: .leading, values: yAxisSpec.ticks) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let axisValue = value.as(Double.self) {
                            Text("\(formattedAxisValue(axisValue)) \(unit)")
                                .offset(x: 4, y: 6)
                        }
                    }
                }
            } else {
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

        if let yAxisSpec {
            baseChart.chartYScale(domain: yAxisSpec.domain)
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

private struct SwellPeriodDirectionChartCard: View {
    private let title = "Swell Period & Direction"
    private let unit = "s"

    let data: [SwellPeriodDirectionPoint]
    let arrowPoints: [SwellPeriodDirectionPoint]
    let yAxisSpec: ChartYAxisSpec?
    let fillBaseline: Double

    @State private var selectedDate: Date?
    @State private var selectionLayout = MetricChartSelectionLayout()

    init(points: [BuoyHistoryPoint]) {
        let data: [SwellPeriodDirectionPoint] = points.compactMap { point in
            guard let date = point.date, let period = point.swellPeriodS else { return nil }

            return SwellPeriodDirectionPoint(
                date: date,
                period: period,
                direction: point.swellDirection,
                directionDegrees: point.swellDirectionDeg
            )
        }

        let sortedData = data.sorted { $0.date < $1.date }

        self.data = sortedData
        self.arrowPoints = Self.sampleDirectionPoints(sortedData)

        let yAxisSpec = ChartYAxisSpec.nicePadded(
            for: sortedData.map { $0.period },
            padding: 2,
            lowerLimit: 0
        )
        self.yAxisSpec = yAxisSpec
        self.fillBaseline = yAxisSpec?.domain.lowerBound ?? 0
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
        .padding(.leading, 16)
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
                    yEnd: .value("Swell Period", point.period)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.linearGradient(
                    colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                ))

                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Swell Period", point.period)
                )
                .interpolationMethod(.catmullRom)
            }

            if let selectedPoint {
                RuleMark(x: .value("Selected Time", selectedPoint.date))
                    .foregroundStyle(.secondary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

            }
        }
        .chartYAxis {
            if let yAxisSpec {
                AxisMarks(position: .leading, values: yAxisSpec.ticks) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let axisValue = value.as(Double.self) {
                            Text("\(formattedAxisValue(axisValue)) \(unit)")
                                .offset(x: 4, y: 6)
                        }
                    }
                }
            } else {
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

                    ZStack {
                        if let selectedPoint,
                           let xPosition = proxy.position(forX: selectedPoint.date),
                           let yPosition = proxy.position(forY: selectedPoint.period),
                           let directionDegrees = selectedPoint.directionDegrees {
                            directionArrow(degrees: directionDegrees)
                                .position(
                                    x: plotFrame.minX + xPosition,
                                    y: plotFrame.minY + yPosition
                                )
                        } else {
                            ForEach(arrowPoints) { point in
                                if let xPosition = proxy.position(forX: point.date),
                                   let yPosition = proxy.position(forY: point.period),
                                   let directionDegrees = point.directionDegrees {
                                    directionArrow(degrees: directionDegrees)
                                        .position(
                                            x: plotFrame.minX + xPosition,
                                            y: plotFrame.minY + yPosition
                                        )
                                }
                            }
                        }
                    }
                    .allowsHitTesting(false)

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

        if let yAxisSpec {
            baseChart.chartYScale(domain: yAxisSpec.domain)
        } else {
            baseChart
        }
    }

    private var selectedValueRow: some View {
        GeometryReader { geometry in
            if let selectedPoint, let selectedX = selectionLayout.selectedX {
                selectedValueCallout(for: selectedPoint)
                    .position(x: selectedX, y: geometry.size.height / 2)
            } else {
                selectionPlaceholder
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .frame(height: 18)
    }

    private var selectedPoint: SwellPeriodDirectionPoint? {
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

    private func selectedTimeCallout(for point: SwellPeriodDirectionPoint) -> some View {
        Text(formattedTime(point.date))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
    }

    private func selectedValueCallout(for point: SwellPeriodDirectionPoint) -> some View {
        Text(formattedValue(point))
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
    }

    private func directionArrow(degrees: Double) -> some View {
        Image(systemName: "location.north.fill")
            .font(.callout.weight(.semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(degrees + 180))
    }

    private func formattedValue(_ point: SwellPeriodDirectionPoint) -> String {
        let period = "\(String(format: "%.1f", point.period)) \(unit)"

        guard let direction = point.direction else {
            return period
        }

        if let directionDegrees = point.directionDegrees {
            return "\(period) from \(direction) (\(Int(directionDegrees.rounded()))°)"
        }

        return "\(period) from \(direction)"
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

    private static func sampleDirectionPoints(_ points: [SwellPeriodDirectionPoint]) -> [SwellPeriodDirectionPoint] {
        let directionPoints = points.filter { $0.directionDegrees != nil }
        guard let startDate = points.first?.date, let endDate = points.last?.date else { return [] }

        var sampledPoints: [SwellPeriodDirectionPoint] = []
        let interval: TimeInterval = 4 * 60 * 60
        let initialOffset: TimeInterval = 90 * 60
        var targetDate = startDate.addingTimeInterval(initialOffset)

        while targetDate <= endDate {
            if let closestPoint = directionPoints.min(by: {
                abs($0.date.timeIntervalSince(targetDate)) < abs($1.date.timeIntervalSince(targetDate))
            }) {
                if let lastPoint = sampledPoints.last, lastPoint.id == closestPoint.id {
                    targetDate = targetDate.addingTimeInterval(interval)
                    continue
                }

                sampledPoints.append(closestPoint)
            }

            targetDate = targetDate.addingTimeInterval(interval)
        }

        return sampledPoints
    }
}

private struct SwellPeriodDirectionPoint: Identifiable {
    let id = UUID()
    let date: Date
    let period: Double
    let direction: String?
    let directionDegrees: Double?
}

private struct BuoyLocationMapCard: View {
    let coordinate: CLLocationCoordinate2D
    let title: String
    let onTap: () -> Void

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 1.2, longitudeDelta: 1.2)
        )
    }

    var body: some View {
        ZStack {
            Map(initialPosition: .region(region)) {
                Marker(title, coordinate: coordinate)
                    .tint(.red)
            }
            .allowsHitTesting(false)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(perform: onTap)
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

private struct ChartYAxisSpec {
    let domain: ClosedRange<Double>
    let ticks: [Double]

    static func zeroBased(for values: [Double]) -> ChartYAxisSpec? {
        nicePadded(for: values, padding: 1, lowerLimit: 0)
    }

    static func temperature(for values: [Double]) -> ChartYAxisSpec? {
        nicePadded(for: values, padding: 1, minRange: 5)
    }

    static func nicePadded(
        for values: [Double],
        padding: Double,
        minRange: Double? = nil,
        lowerLimit: Double? = nil,
        maxTickCount: Int = 5
    ) -> ChartYAxisSpec? {
        guard let minValue = values.min(), let maxValue = values.max() else { return nil }

        let rawLower = minValue - padding
        let lowerBase = lowerLimit.map { max($0, rawLower) } ?? rawLower
        let upperBase = maxValue + (padding / 2)
        let paddedUpper = maxValue + padding
        let desiredSpan = max(minRange ?? 0, paddedUpper - lowerBase)

        for step in niceSteps(for: desiredSpan) {
            let lower = lowerLimit.map { max($0, floor(lowerBase / step) * step) } ?? floor(lowerBase / step) * step
            var upper = ceil(upperBase / step) * step

            if let minRange, upper - lower < minRange {
                upper = ceil((lower + minRange) / step) * step
            }

            if upper <= lower {
                upper = lower + step
            }

            let ticks = tickValues(from: lower, through: upper, by: step)
            if ticks.count <= maxTickCount {
                return ChartYAxisSpec(domain: lower...upper, ticks: ticks)
            }
        }

        return nil
    }

    private static func niceSteps(for span: Double) -> [Double] {
        let bases = [0.5, 1.0, 2.0, 5.0]
        return (-2...3).flatMap { exponent in
            bases.map { $0 * pow(10, Double(exponent)) }
        }
        .filter { $0 > 0 && $0 <= max(100, span * 10) }
        .sorted()
    }

    private static func tickValues(from lower: Double, through upper: Double, by step: Double) -> [Double] {
        var values: [Double] = []
        var value = lower

        while value <= upper + (step / 1000) {
            values.append((value * 1000).rounded() / 1000)
            value += step
        }

        return values
    }
}

private enum MetricChartYScale {
    case zeroBasedBuffered
    case temperature

    func axisSpec(for values: [Double]) -> ChartYAxisSpec? {
        switch self {
        case .zeroBasedBuffered:
            return ChartYAxisSpec.zeroBased(for: values)
        case .temperature:
            return ChartYAxisSpec.temperature(for: values)
        }
    }
}

#Preview {
    NavigationStack {
        BuoyDetailView(buoy: FavoriteBuoy(id: "44065"))
    }
}

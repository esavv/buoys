//
//  MetricChartCard.swift
//  BuoyData
//

import Charts
import SwiftUI

struct MetricChartCard: View {
    let title: String
    let unit: String
    private let data: [MetricChartDataPoint]
    private let yAxisSpec: ChartYAxisSpec?
    private let fillBaseline: Double
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
                                .offset(x: 0, y: 6)
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
                                .offset(x: 0, y: 6)
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

struct MetricChartSelectionLayout: Equatable {
    var plotFrame: CGRect = .zero
    var selectedX: CGFloat?
}

struct MetricChartSelectionLayoutKey: PreferenceKey {
    static let defaultValue = MetricChartSelectionLayout()

    static func reduce(value: inout MetricChartSelectionLayout, nextValue: () -> MetricChartSelectionLayout) {
        value = nextValue()
    }
}

struct ChartYAxisSpec {
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
        let maxStep = max(100, span * 10)
        var steps: [Double] = []

        for exponent in -2...3 {
            let multiplier = pow(10, Double(exponent))

            for base in bases {
                let step = base * multiplier
                if step > 0 && step <= maxStep {
                    steps.append(step)
                }
            }
        }

        return steps.sorted()
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

enum MetricChartYScale {
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

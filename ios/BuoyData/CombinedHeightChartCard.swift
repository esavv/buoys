//
//  CombinedHeightChartCard.swift
//  BuoyData
//

import Charts
import SwiftUI

struct CombinedHeightChartCard: View {
    private let title = "Wave & Swell Height"
    private let unit = "ft"
    private let waveColor = Color.accentColor
    private let swellColor = Color.green

    private let data: [HeightChartDataPoint]
    private let seriesData: [HeightChartSeriesPoint]
    private let yAxisSpec: ChartYAxisSpec?
    private let fillBaseline: Double

    private var swellSeriesData: [HeightChartSeriesPoint] {
        seriesData.filter { $0.series == .swell }
    }

    private var waveSeriesData: [HeightChartSeriesPoint] {
        seriesData.filter { $0.series == .wave }
    }

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
            ForEach(swellSeriesData) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Baseline", fillBaseline),
                    yEnd: .value("Swell Height", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Series", HeightChartSeries.swell.fillLabel))
            }

            ForEach(waveSeriesData) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Baseline", fillBaseline),
                    yEnd: .value("Wave Height", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Series", HeightChartSeries.wave.fillLabel))
            }

            ForEach(swellSeriesData) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Swell Height", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Series", HeightChartSeries.swell.label))
            }

            ForEach(waveSeriesData) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Wave Height", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Series", HeightChartSeries.wave.label))
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
        .chartForegroundStyleScale(
            domain: [
                HeightChartSeries.swell.fillLabel,
                HeightChartSeries.wave.fillLabel,
                HeightChartSeries.swell.label,
                HeightChartSeries.wave.label,
            ],
            range: [
                AnyShapeStyle(fillGradient(for: swellColor, opacity: 0.16)),
                AnyShapeStyle(fillGradient(for: waveColor, opacity: 0.14)),
                AnyShapeStyle(swellColor),
                AnyShapeStyle(waveColor),
            ]
        )
        .chartLegend(.hidden)
        .chartYAxis {
            if let yAxisSpec {
                AxisMarks(position: .leading, values: yAxisSpec.ticks) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let axisValue = value.as(Double.self) {
                            Text("\(formattedAxisValue(axisValue)) \(unit)")
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
                            Text("\(formattedAxisValue(axisValue)) \(unit)")
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

    private func fillGradient(for color: Color, opacity: Double) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(opacity), color.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
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

    var fillLabel: String {
        "\(label) Fill"
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

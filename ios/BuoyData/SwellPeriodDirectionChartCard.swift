//
//  SwellPeriodDirectionChartCard.swift
//  BuoyData
//

import Charts
import SwiftUI

struct SwellPeriodDirectionChartCard: View {
    private let title = "Swell Period & Direction"
    private let unit = "s"

    private let data: [SwellPeriodDirectionPoint]
    private let arrowPoints: [SwellPeriodDirectionPoint]
    private let yAxisSpec: ChartYAxisSpec?
    private let fillBaseline: Double

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
                                .offset(x: -2, y: 6)
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
                                .offset(x: -2, y: 6)
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

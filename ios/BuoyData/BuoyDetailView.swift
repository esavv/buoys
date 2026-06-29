//
//  BuoyDetailView.swift
//  BuoyData
//

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
        .onAppear {
            Analytics.trackScreen("Buoy Detail", properties: [
                "station_id": buoy.id,
            ])
        }
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

            CombinedHeightChartCard(points: historyPoints, stationID: buoy.id)

            SwellPeriodDirectionChartCard(points: historyPoints, stationID: buoy.id)

            MetricChartCard(
                title: "Water Temperature",
                unit: "°F",
                points: historyPoints,
                value: \.waterTempF,
                yScale: .temperature,
                stationID: buoy.id,
                chartType: "water_temperature"
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
        .frame(height: BuoyDetailChartLayout.metricCardHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(perform: onTap)
    }
}

#Preview {
    NavigationStack {
        BuoyDetailView(buoy: FavoriteBuoy(id: "44065"))
    }
}

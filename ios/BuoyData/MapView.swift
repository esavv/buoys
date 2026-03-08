//
//  MapView.swift
//  BuoyData
//
//  Created by Erik Savage on 3/7/26.
//

import SwiftUI
import MapKit

struct MapView: View {
    @State private var stations: [Station] = []
    @State private var selectedStation: Station? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            BuoyMapView(stations: stations, selectedStation: $selectedStation)

            if let station = selectedStation {
                StationCard(station: station) {
                    selectedStation = nil
                }
                .id(station.id)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedStation?.id)
        .onAppear {
            if stations.isEmpty {
                fetchStations()
            }
        }
    }

    private func fetchStations() {
        guard let url = APIConfig.stationsURL else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Stations fetch error: \(error?.localizedDescription ?? "Unknown")")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(StationsResponse.self, from: data)
                if decoded.status == "success", let fetchedStations = decoded.stations {
                    DispatchQueue.main.async {
                        stations = fetchedStations
                    }
                }
            } catch {
                print("Stations decode error: \(error.localizedDescription)")
            }
        }.resume()
    }
}

struct StationCard: View {
    let station: Station
    let onDismiss: () -> Void

    @Environment(FavoritesStore.self) private var store
    @State private var buoyData: BuoyResponse? = nil
    @State private var isLoading = true

    private var isFavorite: Bool {
        store.contains(station.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name)
                        .font(.headline)
                    Text("Station \(station.id)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.gray)
                        .font(.title2)
                }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if let data = buoyData, data.status == "success" {
                BuoyReadingGrid(data: data)
            } else {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }

            HStack {
                Spacer()
                if isFavorite {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.subheadline)
                        Text("Favorite Buoy")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Button {
                        store.add(station.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.subheadline)
                            Text("Add to Favorites")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 4)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .onAppear {
            fetchBuoyData()
        }
    }

    private func fetchBuoyData() {
        guard let url = APIConfig.buoyURL(for: station.id) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { isLoading = false }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(BuoyResponse.self, from: data)
                DispatchQueue.main.async {
                    buoyData = decoded
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async { isLoading = false }
            }
        }.resume()
    }
}

struct BuoyReadingGrid: View {
    let data: BuoyResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    readingLine("Wave Height", value: data.sigWaveHeightFt, unit: "ft")
                    readingLine("Swell Height", value: data.swellHeightFt, unit: "ft")
                }
                VStack(alignment: .leading, spacing: 2) {
                    readingLine("Period", value: data.swellPeriodS, unit: "s")
                    readingLine("Direction", value: data.swellDirection)
                }
            }
            if let updated = data.lastUpdated {
                Text("Updated \(updated)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func readingLine(_ label: String, value: String?, unit: String? = nil) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let value = value, value != "N/A" {
                Text(unit != nil ? "\(value) \(unit!)" : value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text("N/A")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

class BuoyAnnotation: NSObject, MKAnnotation {
    let stationId: String
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(station: Station) {
        self.stationId = station.id
        self.coordinate = CLLocationCoordinate2D(latitude: station.lat, longitude: station.lon)
        self.title = station.name
        self.subtitle = "Station \(station.id)"
        super.init()
    }
}

struct BuoyMapView: UIViewRepresentable {
    let stations: [Station]
    @Binding var selectedStation: Station?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.0, longitude: -68.0),
            span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
        )
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "BuoyMarker")
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        let existingIds = Set(mapView.annotations.compactMap { ($0 as? BuoyAnnotation)?.stationId })
        let newIds = Set(stations.map { $0.id })

        guard existingIds != newIds else { return }

        mapView.removeAnnotations(mapView.annotations)
        let annotations = stations.map { BuoyAnnotation(station: $0) }
        mapView.addAnnotations(annotations)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: BuoyMapView

        init(parent: BuoyMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier,
                    for: cluster
                ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
                view.markerTintColor = .systemRed
                view.titleVisibility = .hidden
                view.subtitleVisibility = .hidden
                return view
            }

            guard let buoyAnnotation = annotation as? BuoyAnnotation else { return nil }

            let identifier = "BuoyMarker"
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: identifier,
                for: buoyAnnotation
            ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: buoyAnnotation, reuseIdentifier: identifier)

            view.clusteringIdentifier = "buoy"
            view.markerTintColor = .systemRed
            view.titleVisibility = .hidden
            view.subtitleVisibility = .hidden
            view.canShowCallout = false
            view.annotation = buoyAnnotation
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let buoyAnnotation = annotation as? BuoyAnnotation else { return }
            parent.selectedStation = parent.stations.first { $0.id == buoyAnnotation.stationId }
            mapView.setCenter(buoyAnnotation.coordinate, animated: true)
        }

        func mapView(_ mapView: MKMapView, didDeselect annotation: MKAnnotation) {
            guard annotation is BuoyAnnotation else { return }
            parent.selectedStation = nil
        }
    }
}

#Preview {
    MapView()
}

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

    var body: some View {
        BuoyMapView(stations: stations)
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
        let existingIds = Set(mapView.annotations.compactMap { ($0 as? BuoyAnnotation)?.stationId })
        let newIds = Set(stations.map { $0.id })

        guard existingIds != newIds else { return }

        mapView.removeAnnotations(mapView.annotations)
        let annotations = stations.map { BuoyAnnotation(station: $0) }
        mapView.addAnnotations(annotations)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
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
    }
}

#Preview {
    MapView()
}

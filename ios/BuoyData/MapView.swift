//
//  MapView.swift
//  BuoyData
//
//  Created by Erik Savage on 3/7/26.
//

import SwiftUI
import MapKit

struct MapView: View {
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.0, longitude: -68.0),
            span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
        )
    )
    @State private var stations: [Station] = []

    var body: some View {
        Map(position: $position) {
            ForEach(stations) { station in
                Marker(
                    station.name,
                    coordinate: CLLocationCoordinate2D(
                        latitude: station.lat,
                        longitude: station.lon
                    )
                )
            }
        }
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

#Preview {
    MapView()
}

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

    var body: some View {
        Map(position: $position)
    }
}

#Preview {
    MapView()
}

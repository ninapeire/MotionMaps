//
//  CombinedRouteMapView.swift
//  MotionMaps
//
//  Created by Nina Peire on 24/03/2025.
//

import SwiftUI
import CoreLocation
import MapKit
import HealthKit


// Set London as home for anonymisation as centre point.
let home = CLLocationCoordinate2D(latitude: 51.5072, longitude: 0.1276)

// Map View which contains all the combined routes.
struct CombinedRouteMapView: View {
    let allRoutes: [UUID: ([CLLocation], HKWorkout)]
    @State private var region = MKCoordinateRegion()

    var body: some View {
        ZStack {
            MultiRouteMap(routes: allRoutes.map { $0.value.0 }, region: $region)
                .edgesIgnoringSafeArea(.all)
        }
        .onAppear {
            // Centre map view on home location.
            region = MKCoordinateRegion(center: home, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        }
        .navigationTitle("All Routes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Generate the actual Mapview which contains the combined routes.
struct MultiRouteMap: UIViewRepresentable {
    let routes: [[CLLocation]]
    @Binding var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // For each route add a blue line following its coordinates.
        for route in routes {
            let coords = route.map { $0.coordinate }
            let polyline = ColoredPolyline(coordinates: coords, count: coords.count)
            polyline.color = UIColor.systemBlue
            mapView.addOverlay(polyline)
        }

        // Centre map view on home location.
        mapView.setRegion(MKCoordinateRegion(center: home,
                                             span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)),
                          animated: false)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.setRegion(region, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? ColoredPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = polyline.color
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// Custom polyline class
class ColoredPolyline: MKPolyline {
    var color: UIColor = .systemBlue
}

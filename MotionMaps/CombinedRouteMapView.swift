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


// MARK: - Constants

/// File-private namespace for map view defaults. Avoids polluting the module
/// with bare top-level `home`/`defaultSpan` constants.
private enum MapDefaults {
    /// Central London (~Trafalgar Square) — default centre when no routes are available.
    static let home = CLLocationCoordinate2D(latitude: 51.5072, longitude: -0.1276)

    /// Roughly a 5 km × 5 km viewport — wide enough to see most central-London routes without zooming.
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
}


// MARK: - Views

/// SwiftUI host for the combined-routes map. Centres on `MapDefaults.home` on
/// first appearance and delegates rendering to `MultiRouteMap`.
struct CombinedRouteMapView: View {
    let allRoutes: [UUID: RouteEntry]
    @State private var region = MKCoordinateRegion()

    var body: some View {
        ZStack {
            MultiRouteMap(routes: allRoutes.values.map(\.locations), region: $region)
                .edgesIgnoringSafeArea(.all)
        }
        .onAppear {
            region = MKCoordinateRegion(center: MapDefaults.home, span: MapDefaults.defaultSpan)
        }
        .navigationTitle("All Routes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// `UIViewRepresentable` wrapper around `MKMapView`. Draws each provided route
/// as a `ColoredPolyline` so future versions can theme by activity type.
struct MultiRouteMap: UIViewRepresentable {
    let routes: [[CLLocation]]
    @Binding var region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        for route in routes {
            let coords = route.map { $0.coordinate }
            let polyline = ColoredPolyline(coordinates: coords, count: coords.count)
            polyline.color = UIColor.systemBlue
            mapView.addOverlay(polyline)
        }

        mapView.setRegion(MKCoordinateRegion(center: MapDefaults.home, span: MapDefaults.defaultSpan), animated: false)

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


// MARK: - Helpers

/// `MKPolyline` subclass with a per-overlay stroke colour — enables drawing different
/// activity types (e.g. cycling vs running) in different colours from one renderer.
class ColoredPolyline: MKPolyline {
    var color: UIColor = .systemBlue
}

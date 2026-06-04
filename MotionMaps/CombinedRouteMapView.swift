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
    /// Central London (~Trafalgar Square) — fallback centre when no routes are available.
    static let home = CLLocationCoordinate2D(latitude: 51.5072, longitude: -0.1276)

    /// Roughly a 5 km × 5 km viewport — used as fallback only.
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)

    /// Padding around the auto-fit bounding rect, in points.
    static let fitPadding = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
}


// MARK: - Views

/// SwiftUI host for the combined-routes map. Delegates rendering to `MultiRouteMap`,
/// which auto-fits the viewport to the routes' bounding rect on creation.
struct CombinedRouteMapView: View {
    let allRoutes: [UUID: RouteEntry]

    var body: some View {
        MultiRouteMap(routes: allRoutes.values.map(\.locations))
            .edgesIgnoringSafeArea(.all)
            .navigationTitle("All Routes")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// `UIViewRepresentable` wrapper around `MKMapView`. Draws each provided route
/// as a `ColoredPolyline` and frames the viewport to cover them all.
///
/// `updateUIView` is intentionally a no-op so user pan/zoom is preserved across
/// SwiftUI parent re-renders.
struct MultiRouteMap: UIViewRepresentable {
    let routes: [[CLLocation]]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        for route in routes where !route.isEmpty {
            let coords = route.map { $0.coordinate }
            let polyline = ColoredPolyline(coordinates: coords, count: coords.count)
            polyline.color = UIColor.systemBlue
            mapView.addOverlay(polyline)
        }

        if mapView.overlays.isEmpty {
            mapView.setRegion(
                MKCoordinateRegion(center: MapDefaults.home, span: MapDefaults.defaultSpan),
                animated: false
            )
        } else {
            let boundingRect = mapView.overlays.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) }
            mapView.setVisibleMapRect(boundingRect, edgePadding: MapDefaults.fitPadding, animated: false)
        }

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}

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

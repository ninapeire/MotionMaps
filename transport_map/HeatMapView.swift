//
//  HeatMapView.swift
//  Workout Maps
//
//  Created by Nina Peire on 26/03/2025.
//

import SwiftUI
import CoreLocation
import MapKit
import HealthKit

struct HeatMapView: View {
    let allRoutes: [UUID: ([CLLocation], HKWorkout)]
    
    @State private var region = MKCoordinateRegion()

    var body: some View {
        ZStack {
            HeatMap(routes: allRoutes.map { $0.value.0 }, region: $region)
                .edgesIgnoringSafeArea(.all)
        }
        .onAppear {
            region = MKCoordinateRegion(center: home, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        }
        .navigationTitle("All Routes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RoundedCoordinate: Hashable {
    let latitude: Double
    let longitude: Double

    init(_ coord: CLLocationCoordinate2D) {
        let precision = 1e3
        self.latitude = round(coord.latitude * precision) / precision
        self.longitude = round(coord.longitude * precision) / precision
    }
}

//struct ColoredPolyline: MKPolyline {
//    var color: UIColor?
//}

struct HeatMap: UIViewRepresentable {
    let routes: [[CLLocation]]
    @Binding var region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        let allCoordinates = routes.flatMap { $0.map { $0.coordinate } }

        // Draw original polylines
//        for route in routes {
//            let coords = route.map { $0.coordinate }
//            let polyline = ColoredPolyline(coordinates: coords, count: coords.count)
//            polyline.color = UIColor.systemBlue
//            mapView.addOverlay(polyline)
//        }

        // Add heatmap overlay circles
        let heatmapData = calculateHeatmapData(from: routes)
        for (roundedCoord, count) in heatmapData {
            let coord = CLLocationCoordinate2D(latitude: roundedCoord.latitude, longitude: roundedCoord.longitude)
            let circle = MKCircle(center: coord, radius: 20) // Adjust radius
            circle.title = "\(1)" // Pass frequency through title
            mapView.addOverlay(circle)
        }

        // Set initial map region
        if let first = allCoordinates.first {
            mapView.setRegion(MKCoordinateRegion(center: first,
                                                 span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)),
                              animated: false)
        }

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.setRegion(region, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func calculateHeatmapData(from routes: [[CLLocation]]) -> [RoundedCoordinate: Int] {
        var frequency: [RoundedCoordinate: Int] = [:]
        for route in routes {
            for location in route {
                let coord = RoundedCoordinate(location.coordinate)
                frequency[coord, default: 0] += 1
            }
        }
        return frequency
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? ColoredPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = polyline.color
                renderer.lineWidth = 3
                return renderer
            } else if let circle = overlay as? MKCircle,
                      let countStr = circle.title,
                      let count = Int(countStr ?? "") {

                let renderer = MKCircleRenderer(circle: circle)
                let alpha = min(CGFloat(count) / 10.0, 1.0) // Cap max opacity
                renderer.fillColor = UIColor.red.withAlphaComponent(alpha)
                renderer.strokeColor = .clear
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

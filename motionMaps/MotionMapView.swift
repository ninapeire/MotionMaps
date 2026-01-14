//
//  MotionMapView.swift
//  transport_map
//
//  Created by Nina Peire on 24/03/2025.
//

import SwiftUI
import MapKit
import CoreLocation
import HealthKit

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        default:
            return "Workout"
        }
    }
}

struct MotionMapView: View {
    let workout: HKWorkout
    let route: [CLLocation]

    @State private var region = MKCoordinateRegion()

    var body: some View {
        ZStack {
            RouteMap(route: route, region: $region)
                .edgesIgnoringSafeArea(.all)
        }
        .onAppear {
            if let firstCoord = route.first?.coordinate {
                region = MKCoordinateRegion(center: firstCoord,
                                             span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            }
        }
        .navigationTitle(workout.workoutActivityType.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - RouteMap

struct RouteMap: UIViewRepresentable {
    let route: [CLLocation]
    @Binding var region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true

        // Center the map
        if let center = route.first?.coordinate {
            mapView.setRegion(MKCoordinateRegion(center: center,
                                                 span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)),
                              animated: false)
        }

        // Add polyline
        let coordinates = route.map { $0.coordinate }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        // Add annotations
        if let start = coordinates.first {
            let startPin = MKPointAnnotation()
            startPin.coordinate = start
            startPin.title = "Start"
            mapView.addAnnotation(startPin)
        }

        if let end = coordinates.last {
            let endPin = MKPointAnnotation()
            endPin.coordinate = end
            endPin.title = "End"
            mapView.addAnnotation(endPin)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Region updates if needed
        mapView.setRegion(region, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

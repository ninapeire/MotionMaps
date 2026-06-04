//
//  ContentView.swift
//  MotionMaps
//
//  Created by Nina Peire on 24/03/2025.
//

import SwiftUI
import HealthKit

/// Top-level navigation list. Surfaces Running and Cycling rows for any workout
/// types HealthKit returns; tapping a row navigates to the combined map view.
struct ContentView: View {
    @StateObject var healthManager = HealthManager()
    @State private var hasRequestedAuth = false

    var body: some View {
        NavigationStack {
            List {
                if !healthManager.runningWorkoutRoutes.isEmpty {
                    NavigationLink("Running", destination: CombinedRouteMapView(allRoutes: healthManager.runningWorkoutRoutes))
                        .padding()
                }

                if !healthManager.cyclingWorkoutRoutes.isEmpty {
                    NavigationLink("Cycling", destination: CombinedRouteMapView(allRoutes: healthManager.cyclingWorkoutRoutes))
                        .padding()
                }
            }
            .navigationTitle("Workout Maps")
        }
        .onAppear {
            guard !hasRequestedAuth else { return }
            hasRequestedAuth = true
            healthManager.requestAuthorization()
        }
    }
}


#Preview {
    ContentView()
}

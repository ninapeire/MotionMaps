//
//  ContentView.swift
//  MotionMaps
//
//  Created by Nina Peire on 24/03/2025.
//

import SwiftUI
import HealthKit
import UIKit

/// Top-level navigation list. Shows a loading indicator while HealthKit
/// authorization is resolving, an empty state if no workouts are available,
/// or Running / Cycling rows for any workout types HealthKit returned.
struct ContentView: View {
    @StateObject var healthManager = HealthManager()
    @Environment(\.modelContext) private var modelContext
    @State private var hasStarted = false

    private var hasNoWorkouts: Bool {
        healthManager.runningWorkoutRoutes.isEmpty && healthManager.cyclingWorkoutRoutes.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if !healthManager.didCompleteAuth {
                    ProgressView("Loading workouts…")
                } else if hasNoWorkouts {
                    emptyState
                } else {
                    workoutList
                }
            }
            .navigationTitle("Workout Maps")
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            healthManager.modelContext = modelContext
            healthManager.start()
        }
    }

    private var workoutList: some View {
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
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Workouts Found", systemImage: "figure.run")
        } description: {
            Text("No cycling or running workouts have been recorded in Apple Health since October 2024.\n\nIf you've recorded workouts and don't see them here, MotionMaps may not have HealthKit permission. You can grant access from the iOS Settings app.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}


#Preview {
    ContentView()
}

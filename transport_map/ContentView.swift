//
//  ContentView.swift
//  transport_map
//
//  Created by Nina Peire on 24/03/2025.
//

import SwiftUI
import HealthKit


// The main view that displays the options for different workout types.
struct ContentView: View {
    @StateObject var healthManager = HealthManager()
    
    var body: some View {
        NavigationView {
            List{
                
                // Show running routes if these are available.
                if !healthManager.runningWorkoutRoutes.isEmpty {
                    NavigationLink("Running", destination: CombinedRouteMapView(allRoutes: healthManager.runningWorkoutRoutes))
                        .padding()
                }
                
                // Show cycling routes if these are available.
                if !healthManager.cyclingWorkoutRoutes.isEmpty {
                    NavigationLink("Cycling", destination: CombinedRouteMapView(allRoutes: healthManager.cyclingWorkoutRoutes))
                        .padding()
                }
                
            }.navigationTitle("Workout Maps")
        }.onAppear {
            // Request HealthKit permissions on launch.
            healthManager.requestAuthorization()
        }
    }
}


#Preview {
    ContentView()
}

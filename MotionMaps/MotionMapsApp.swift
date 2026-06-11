//
//  MotionMapsApp.swift
//  MotionMaps
//
//  Created by Nina Peire on 24/03/2025.
//

import SwiftUI
import SwiftData

@main
struct MotionMapsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: CachedWorkout.self)
    }
}

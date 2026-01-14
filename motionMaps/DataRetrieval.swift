//
//  DataRetrieval.swift
//  MotionMaps
//
//  Created by Nina Peire on 24/03/2025.
//

import HealthKit
import Foundation
import CoreLocation


class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var cyclingWorkoutRoutes: [UUID: ([CLLocation], HKWorkout)] = [:]
    @Published var runningWorkoutRoutes: [UUID: ([CLLocation], HKWorkout)] = [:]
    
    // HealthKit data types to read
    let readTypes = Set([
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
//            HKObjectType.quantityType(forIdentifier: .heartRate)!,
//            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
//            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ])

    // Requests HealthKit read authorization for required data types
    func requestAuthorization() {
        if HKHealthStore.isHealthDataAvailable() {
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                if success {
                    print("Authorization granted.")
                    self.fetchCyclingWorkouts()
                    self.fetchRunningWorkouts()
                } else {
                    print("Authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        } else {
            print("Health data is not available.")
        }
    }
    
    // Returns a predicate to filter workouts starting on a specific calendar day
    func getCalendarDatePredicate(day: Int, month: Int, year: Int) -> NSPredicate {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        let startDate = calendar.date(from: dateComponents)!
        return HKQuery.predicateForSamples(withStart: startDate, end: nil, options: [])
    }
    
    // Fetches the route (locations) for a given workout
    func fetchRoute(for workout: HKWorkout, completion: @escaping ([CLLocation]) -> Void) {
        let predicate = HKQuery.predicateForObjects(from: workout)
        let routeQuery = HKSampleQuery(sampleType: HKSeriesType.workoutRoute(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            guard let route = samples?.first as? HKWorkoutRoute else {
                completion([])
                return
            }

            var locations: [CLLocation] = []
            let locationQuery = HKWorkoutRouteQuery(route: route) { _, newLocations, done, error in
                if let newLocations = newLocations {
                    locations.append(contentsOf: newLocations)
                }
                if done {
                    DispatchQueue.main.async {
                        completion(locations)
                    }
                }
            }
            self.healthStore.execute(locationQuery)
        }
        healthStore.execute(routeQuery)
    }
    
    // Fetches all cycling workouts starting January 3rd 2025.
    func fetchCyclingWorkouts() {
        let workoutType = HKObjectType.workoutType()

        let predicate = self.getCalendarDatePredicate(day: 3, month: 1, year: 2025)
        let cyclingPredicate = HKQuery.predicateForWorkouts(with: .cycling)
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, cyclingPredicate])

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: workoutType, predicate: combinedPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
            guard let workouts = samples as? [HKWorkout] else { return }

            for workout in workouts {
                self.fetchRoute(for: workout) { locations in
                    DispatchQueue.main.async {
                        self.cyclingWorkoutRoutes[workout.uuid] = (locations, workout)
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    // Fetches all running workouts starting January 3rd 2025.
    func fetchRunningWorkouts() {
        let workoutType = HKObjectType.workoutType()

        let predicate = self.getCalendarDatePredicate(day: 3, month: 1, year: 2025)
        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, runningPredicate])

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: workoutType, predicate: combinedPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
            guard let workouts = samples as? [HKWorkout] else { return }

            for workout in workouts {
                self.fetchRoute(for: workout) { locations in
                    DispatchQueue.main.async {
                        self.runningWorkoutRoutes[workout.uuid] = (locations, workout)
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }


}

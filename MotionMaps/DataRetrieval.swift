//
//  DataRetrieval.swift
//  MotionMaps
//
//  Created by Nina Peire on 24/03/2025.
//

import HealthKit
import Foundation
import CoreLocation


/// Owns the `HKHealthStore`, requests HealthKit authorization, and runs the
/// HKSampleQueries that populate `runningWorkoutRoutes` and `cyclingWorkoutRoutes`.
class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var cyclingWorkoutRoutes: [UUID: ([CLLocation], HKWorkout)] = [:]
    @Published var runningWorkoutRoutes: [UUID: ([CLLocation], HKWorkout)] = [:]

    let readTypes = Set([
        HKObjectType.workoutType(),
        HKSeriesType.workoutRoute(),
    ])

    /// Requests HealthKit read access. On success, kicks off the cycling and running
    /// workout fetches; on failure logs an error and leaves both dictionaries empty.
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

    /// Returns an `NSPredicate` matching workouts whose start date is on or after the given calendar day.
    func getCalendarDatePredicate(day: Int, month: Int, year: Int) -> NSPredicate {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        let startDate = calendar.date(from: dateComponents)!
        return HKQuery.predicateForSamples(withStart: startDate, end: nil, options: [])
    }

    /// Fetches the recorded `CLLocation` samples for a single workout's route.
    /// Calls back with an empty array if the workout has no associated route.
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

    /// Fetches all cycling workouts recorded since October 1st, 2024 and
    /// stores each one's route in `cyclingWorkoutRoutes`, keyed by workout UUID.
    func fetchCyclingWorkouts() {
        let workoutType = HKObjectType.workoutType()

        let predicate = self.getCalendarDatePredicate(day: 1, month: 10, year: 2024)
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

    /// Fetches all running workouts recorded since October 1st, 2024 and
    /// stores each one's route in `runningWorkoutRoutes`, keyed by workout UUID.
    func fetchRunningWorkouts() {
        let workoutType = HKObjectType.workoutType()

        let predicate = self.getCalendarDatePredicate(day: 1, month: 10, year: 2024)
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

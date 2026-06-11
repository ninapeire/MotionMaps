//
//  DataRetrieval.swift
//  MotionMaps
//
//  Created by Nina Peire on 24/03/2025.
//

import HealthKit
import Foundation
import CoreLocation
import SwiftData


/// A workout's metadata plus its recorded route. Carries enough information
/// for the map view (`locations`), planned per-workout detail views (`uuid`,
/// `activityType`, dates), and for SwiftData persistence — without holding an
/// `HKWorkout` reference, which can't be serialised directly.
struct RouteEntry {
    let uuid: UUID
    let activityType: HKWorkoutActivityType
    let startDate: Date
    let endDate: Date
    let locations: [CLLocation]
}

extension RouteEntry {
    /// Build a `RouteEntry` from an `HKWorkout` sample plus its fetched route locations.
    init(workout: HKWorkout, locations: [CLLocation]) {
        self.init(
            uuid: workout.uuid,
            activityType: workout.workoutActivityType,
            startDate: workout.startDate,
            endDate: workout.endDate,
            locations: locations
        )
    }
}


/// Owns the `HKHealthStore`, requests HealthKit authorization, and runs the
/// HKSampleQueries that populate `runningWorkoutRoutes` and `cyclingWorkoutRoutes`.
/// On launch, hydrates those dictionaries from a SwiftData cache so the UI can
/// render before HealthKit returns; persists fresh fetches back to the cache.
class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var cyclingWorkoutRoutes: [UUID: RouteEntry] = [:]
    @Published var runningWorkoutRoutes: [UUID: RouteEntry] = [:]

    /// `true` once the auth prompt has resolved (granted, denied, or unavailable)
    /// — or once cached data has been loaded. Lets the UI switch off the loading
    /// state without waiting for in-flight route queries.
    @Published var didCompleteAuth: Bool = false

    /// Optional SwiftData context. `ContentView` injects this on first appearance.
    /// When present, `start()` hydrates from the cache and persists fresh fetches.
    var modelContext: ModelContext?

    let readTypes = Set([
        HKObjectType.workoutType(),
        HKSeriesType.workoutRoute(),
    ])

    /// Entry point called once from `ContentView.onAppear`. Loads cached workouts
    /// synchronously (so the UI can render immediately) and then refreshes from
    /// HealthKit in the background.
    func start() {
        loadFromCache()
        requestAuthorization()
    }

    /// Reads every `CachedWorkout` and populates the published dictionaries with a
    /// single assignment per activity type, avoiding per-entry re-render thrash. If
    /// the cache is non-empty, flips `didCompleteAuth` so the UI skips the loading
    /// state and shows the workout list immediately.
    private func loadFromCache() {
        guard let modelContext else { return }
        do {
            let cached = try modelContext.fetch(FetchDescriptor<CachedWorkout>())
            var cycling: [UUID: RouteEntry] = [:]
            var running: [UUID: RouteEntry] = [:]
            for cw in cached {
                let entry = RouteEntry(cached: cw)
                switch cw.activityType {
                case .cycling: cycling[cw.uuid] = entry
                case .running: running[cw.uuid] = entry
                default: break
                }
            }
            cyclingWorkoutRoutes = cycling
            runningWorkoutRoutes = running
            if !cached.isEmpty {
                didCompleteAuth = true
            }
        } catch {
            print("Failed to load cache: \(error)")
        }
    }

    /// Inserts or updates the `CachedWorkout` row for an entry. Idempotent — same
    /// entry can be upserted repeatedly without duplicating rows. Must be called
    /// on the main thread; SwiftData's main context isn't thread-safe.
    private func upsertCache(_ entry: RouteEntry) {
        guard let modelContext else { return }
        let entryUUID = entry.uuid
        let descriptor = FetchDescriptor<CachedWorkout>(
            predicate: #Predicate<CachedWorkout> { $0.uuid == entryUUID }
        )
        do {
            let coords = entry.locations.map {
                Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
            }
            if let existing = try modelContext.fetch(descriptor).first {
                existing.activityTypeRaw = entry.activityType.rawValue
                existing.startDate = entry.startDate
                existing.endDate = entry.endDate
                existing.coordinates = coords
            } else {
                modelContext.insert(CachedWorkout(
                    uuid: entry.uuid,
                    activityType: entry.activityType,
                    startDate: entry.startDate,
                    endDate: entry.endDate,
                    coordinates: coords
                ))
            }
        } catch {
            print("Failed to upsert cache for workout \(entry.uuid): \(error)")
        }
    }

    /// Requests HealthKit read access. On success, kicks off the cycling and running
    /// workout fetches; on failure logs an error and leaves both dictionaries empty.
    /// Sets `didCompleteAuth = true` once the prompt resolves so the UI can move
    /// off the loading state.
    func requestAuthorization() {
        if HKHealthStore.isHealthDataAvailable() {
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                DispatchQueue.main.async {
                    self.didCompleteAuth = true
                }
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
            DispatchQueue.main.async {
                self.didCompleteAuth = true
            }
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

    /// Fetches all cycling workouts recorded since October 1st, 2024 and stores
    /// each one's route in `cyclingWorkoutRoutes`, keyed by workout UUID. Persists
    /// each entry to the SwiftData cache as it arrives.
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
                        let entry = RouteEntry(workout: workout, locations: locations)
                        self.cyclingWorkoutRoutes[workout.uuid] = entry
                        self.upsertCache(entry)
                    }
                }
            }
        }

        healthStore.execute(query)
    }

    /// Fetches all running workouts recorded since October 1st, 2024 and stores
    /// each one's route in `runningWorkoutRoutes`, keyed by workout UUID. Persists
    /// each entry to the SwiftData cache as it arrives.
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
                        let entry = RouteEntry(workout: workout, locations: locations)
                        self.runningWorkoutRoutes[workout.uuid] = entry
                        self.upsertCache(entry)
                    }
                }
            }
        }

        healthStore.execute(query)
    }
}

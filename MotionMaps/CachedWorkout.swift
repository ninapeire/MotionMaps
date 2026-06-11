//
//  CachedWorkout.swift
//  MotionMaps
//
//  Created by Nina Peire on 24/03/2025.
//

import Foundation
import SwiftData
import HealthKit
import CoreLocation

/// Codable lat/lon pair persisted inside `CachedWorkout.coordinates`. Kept as a
/// value type so SwiftData can encode the array without HealthKit/CoreLocation
/// types being involved at the storage layer.
struct Coordinate: Codable {
    let latitude: Double
    let longitude: Double
}

/// SwiftData-persisted snapshot of one workout's route, so launches after the
/// first one can hydrate the UI instantly without waiting for HealthKit queries.
/// `HealthManager` upserts these rows whenever HealthKit returns new or modified
/// data, keying by `uuid`.
@Model
final class CachedWorkout {
    @Attribute(.unique) var uuid: UUID
    var activityTypeRaw: UInt
    var startDate: Date
    var endDate: Date
    var coordinates: [Coordinate]

    init(uuid: UUID, activityType: HKWorkoutActivityType, startDate: Date, endDate: Date, coordinates: [Coordinate]) {
        self.uuid = uuid
        self.activityTypeRaw = activityType.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.coordinates = coordinates
    }

    /// Reconstructs the `HKWorkoutActivityType` from its raw value. Falls back to
    /// `.other` if the persisted value isn't recognised by the current iOS SDK.
    var activityType: HKWorkoutActivityType {
        HKWorkoutActivityType(rawValue: activityTypeRaw) ?? .other
    }
}


extension RouteEntry {
    /// Build a `RouteEntry` from a persisted `CachedWorkout` row, materialising
    /// the stored coordinates back into `CLLocation` for the map view to consume.
    init(cached: CachedWorkout) {
        self.init(
            uuid: cached.uuid,
            activityType: cached.activityType,
            startDate: cached.startDate,
            endDate: cached.endDate,
            locations: cached.coordinates.map {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude)
            }
        )
    }
}

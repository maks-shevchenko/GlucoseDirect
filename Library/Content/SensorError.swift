//
//  SensorError.swift
//  GlucoseDirect
//

import Foundation

// MARK: - SensorError

struct SensorError: CustomStringConvertible, Codable, Identifiable {
    // MARK: Lifecycle

    init(timestamp: Date, error: SensorReadingError) {
        let roundedTimestamp = timestamp.toRounded(on: 1, .minute)

        id = UUID()
        self.timestamp = roundedTimestamp
        self.error = error
        timegroup = roundedTimestamp.toRounded(on: DirectConfig.timegroupRounding, .minute)
    }

    init(id _: UUID, timestamp: Date, error: SensorReadingError) {
        let roundedTimestamp = timestamp.toRounded(on: 1, .minute)

        id = UUID()
        self.timestamp = roundedTimestamp
        self.error = error
        timegroup = roundedTimestamp.toRounded(on: DirectConfig.timegroupRounding, .minute)
    }

    // MARK: Internal

    let id: UUID
    let timestamp: Date
    let error: SensorReadingError
    let timegroup: Date

    var description: String {
        "{ id: \(id), timestamp: \(timestamp.toLocalTime()), error: \(error.description) }"
    }
}

// MARK: Equatable

extension SensorError: Equatable {
    func isMinutly(ofMinutes: Int) -> Bool {
        let minutes = Calendar.current.component(.minute, from: timestamp)

        return minutes % ofMinutes == 0
    }

    static func == (lhs: SensorError, rhs: SensorError) -> Bool {
        lhs.id == rhs.id
    }
}

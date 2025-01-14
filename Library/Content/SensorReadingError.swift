//
//  SensorReadingError.swift
//  GlucoseDirect
//

import Foundation

// MARK: - SensorReadingError

struct SensorReadingError: OptionSet, Codable {
    static let OK = SensorReadingError([])
    static let SD14_FIFO_OVERFLOW = SensorReadingError(rawValue: 1 << 0)
    static let FILTER_DELTA = SensorReadingError(rawValue: 1 << 1)
    static let WORK_VOLTAGE = SensorReadingError(rawValue: 1 << 2)
    static let PEAK_DELTA_EXCEEDED = SensorReadingError(rawValue: 1 << 3)
    static let AVG_DELTA_EXCEEDED = SensorReadingError(rawValue: 1 << 4)
    static let RF = SensorReadingError(rawValue: 1 << 5)
    static let REF_R = SensorReadingError(rawValue: 1 << 6)
    static let SIGNAL_SATURATED = SensorReadingError(rawValue: 1 << 7)
    static let SENSOR_SIGNAL_LOW = SensorReadingError(rawValue: 1 << 8)
    static let THERMISTOR_OUT_OF_RANGE = SensorReadingError(rawValue: 1 << 11)
    static let TEMP_HIGH = SensorReadingError(rawValue: 1 << 13)
    static let TEMP_LOW = SensorReadingError(rawValue: 1 << 14)
    static let INVALID_DATA = SensorReadingError(rawValue: 1 << 15)

    let rawValue: Int
}

extension SensorReadingError {
    var description: String {
        getDescription(separator: "\n")
    }

    var debugDescription: String {
        getDescription(separator: ", ")
    }

    func getDescription(separator: String) -> String {
        var outputs: [String] = []

        if contains(.SD14_FIFO_OVERFLOW) {
            outputs.append("SD14_FIFO_OVERFLOW")
        }
        if contains(.FILTER_DELTA) {
            outputs.append("FILTER_DELTA")
        }
        if contains(.WORK_VOLTAGE) {
            outputs.append("WORK_VOLTAGE")
        }
        if contains(.PEAK_DELTA_EXCEEDED) {
            outputs.append("PEAK_DELTA_EXCEEDED")
        }
        if contains(.AVG_DELTA_EXCEEDED) {
            outputs.append("AVG_DELTA_EXCEEDED")
        }
        if contains(.RF) {
            outputs.append("RF")
        }
        if contains(.REF_R) {
            outputs.append("REF_R")
        }
        if contains(.SIGNAL_SATURATED) {
            outputs.append("SIGNAL_SATURATED")
        }
        if contains(.SENSOR_SIGNAL_LOW) {
            outputs.append("SENSOR_SIGNAL_LOW")
        }
        if contains(.THERMISTOR_OUT_OF_RANGE) {
            outputs.append("THERMISTOR_OUT_OF_RANGE")
        }
        if contains(.TEMP_HIGH) {
            outputs.append("TEMP_HIGH")
        }
        if contains(.TEMP_LOW) {
            outputs.append("TEMP_LOW")
        }
        if contains(.INVALID_DATA) {
            outputs.append("INVALID_DATA")
        }

        return outputs.joined(separator: separator)
    }
}

//
//  GlucoseFilter.swift
//  GlucoseDirect
//

import Foundation

// MARK: - GlucoseFilter

class GlucoseFilter {
    // MARK: Internal

    func filter(glucoseValue: Int, initGlucoseValues: [Int]) -> Double {
        return filter(glucoseValue: Double(glucoseValue), initGlucoseValues: initGlucoseValues.map { Double($0) })
    }

    func filter(glucoseValue: Double, initGlucoseValues: [Double]) -> Double {
        if kalmanFilter == nil {
            let kalmanFilter = KalmanFilter(processNoise: 1, measurementNoise: 25)

            for initGlucoseValue in initGlucoseValues {
                let _ = kalmanFilter.filter(initGlucoseValue)
            }

            self.kalmanFilter = kalmanFilter
        }

        return kalmanFilter?.filter(glucoseValue) ?? glucoseValue
    }

    // MARK: Private

    private var kalmanFilter: KalmanFilter?
}

private class KalmanFilter {
    // MARK: Lifecycle

    init(processNoise: Double = 0.01, measurementNoise: Double = 1, stateVector: Double = 1, controlVector: Double = 1, measurementVector: Double = 0) {
        self.processNoise = processNoise
        self.measurementNoise = measurementNoise

        self.stateVector = stateVector
        self.controlVector = controlVector
        self.measurementVector = measurementVector
    }

    // MARK: Internal

    func filter(_ measurement: Double, _ control: Double = 0) -> Double {
        if isFirst {
            isFirst = false

            x = (1 / controlVector) * measurement
            cov = (1 / controlVector) * measurementNoise * (1 / controlVector)

            return measurement
        } else {
            // Compute prediction
            let predX = predict(control)
            let predCov = uncertainty()

            // Kalman gain
            let K = predCov * controlVector * (1 / ((controlVector * predCov * controlVector) + measurementNoise))

            // Correction
            x = predX + K * (measurement - (controlVector * predX))
            cov = predCov - (K * controlVector * predCov)
        }

        return x
    }

    // MARK: Private

    private let processNoise: Double
    private let measurementNoise: Double
    private let stateVector: Double
    private let measurementVector: Double
    private let controlVector: Double

    private var isFirst = true
    private var cov: Double = 0
    private var x: Double = 0

    private func predict(_ control: Double = 0) -> Double {
        return (stateVector * x) + (measurementVector * control)
    }

    private func uncertainty() -> Double {
        return ((stateVector * cov) * stateVector) + processNoise
    }
}

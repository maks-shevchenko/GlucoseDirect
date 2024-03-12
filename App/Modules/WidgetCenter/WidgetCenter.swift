//
//  WidgetCenter.swift
//  GlucoseDirectApp
//

import ActivityKit
import Combine
import Foundation
import WidgetKit

@available(iOS 16.1, *)
func widgetCenterMiddleware() -> Middleware<DirectState, DirectAction> {
    widgetCenterMiddleware(service: LazyService<ActivityGlucoseService>(initialization: {
        ActivityGlucoseService()
    }))
}

@available(iOS 16.1, *)
private func widgetCenterMiddleware(service: LazyService<ActivityGlucoseService>) -> Middleware<DirectState, DirectAction> {
    return { state, action, _ in
        switch action {
        case .startup:
            guard state.glucoseLiveActivity else {
                break
            }

            service.value.start(alarmLow: state.alarmLow, alarmHigh: state.alarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit)

        case .setGlucoseUnit(unit: _):
            guard state.glucoseLiveActivity else {
                break
            }

            guard service.value.isActivated else {
                break
            }

            if service.value.stopRequired {
                service.value.stop()

            } else if service.value.restartRecommended || service.value.startRequired, state.appState == .active {
                service.value.start(alarmLow: state.alarmLow, alarmHigh: state.alarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit)

            } else if !service.value.startRequired {
                service.value.update(alarmLow: state.alarmLow, alarmHigh: state.alarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit)
            }

        case let .setGlucoseLiveActivity(enabled: enabled):
            if enabled {
                guard service.value.isActivated else {
                    break
                }

                service.value.start(alarmLow: state.alarmLow, alarmHigh: state.alarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit)
            } else {
                service.value.stop()
            }

        case let .setAppState(appState: appState):
            guard appState == .active else {
                break
            }

            WidgetCenter.shared.reloadAllTimelines()

            guard state.glucoseLiveActivity else {
                break
            }

            guard service.value.isActivated else {
                break
            }

            if service.value.restartRecommended || service.value.startRequired {
                service.value.start(alarmLow: state.alarmLow, alarmHigh: state.alarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit)
            }

        case .setConnectionState(connectionState: _):
            guard state.glucoseLiveActivity else {
                break
            }

            guard service.value.isActivated else {
                break
            }

            if service.value.stopRequired {
                service.value.stop()

            } else if service.value.restartRecommended || service.value.startRequired, state.appState == .active {
                service.value.start(alarmLow: state.alarmLow, alarmHigh: state.alarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit)

            } else if !service.value.startRequired {
                service.value.update(alarmLow: state.alarmLow, alarmHigh: state.alarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit)
            }

        case .addSensorGlucose(glucoseValues: _):
            guard state.glucoseLiveActivity else {
                break
            }

            guard service.value.isActivated else {
                break
            }

            if service.value.stopRequired {
                service.value.stop()

            } else if service.value.restartRecommended || service.value.startRequired, state.appState == .active {
                service.value.start(alarmLow: state.alarmLow, alarmHigh: state.alarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit)

            } else if !service.value.startRequired {
                service.value.update(alarmLow: state.alarmLow, alarmHigh: state.alarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit)
            }

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}

// MARK: - ActivityGlucoseService

@available(iOS 16.1, *)
private class ActivityGlucoseService {
    // MARK: Lifecycle

    init() {
        DirectLog.info("Create ActivityGlucoseService")
    }

    // MARK: Internal

    var isActivated: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var restartRecommended: Bool {
        if let activityRefresh = activityRestart, Date() > activityRefresh {
            return true
        }

        return false
    }

    var stopRequired: Bool {
        if let activityStop = activityStop, Date() > activityStop {
            return true
        }

        return false
    }

    var startRequired: Bool {
        return activity == nil
    }

    func start(alarmLow: Int, alarmHigh: Int, sensorState: SensorState?, connectionState: SensorConnectionState, glucose: SensorGlucose?, glucoseUnit: GlucoseUnit) {
        Task {
            let activities = Activity<SensorGlucoseActivityAttributes>.activities
            for activity in activities {
                await activity.end(dismissalPolicy: .immediate)
            }

            do {
                activityStart = Date()
                activityRestart = Date() + 5 * 60
                activityStop = Date() + 8 * 60 * 60

                let activityAttributes = SensorGlucoseActivityAttributes()
                let initialContentState = getStatus(alarmLow: alarmLow, alarmHigh: alarmHigh, sensorState: sensorState, connectionState: connectionState, glucose: glucose, glucoseUnit: glucoseUnit)

                activity = try Activity<SensorGlucoseActivityAttributes>.request(
                    attributes: activityAttributes,
                    contentState: initialContentState,
                    pushType: nil
                )
            } catch {
                DirectLog.error("\(error)")

                activityStart = nil
                activityRestart = nil
                activityStop = nil
                activity = nil
            }
        }
    }

    func update(alarmLow: Int, alarmHigh: Int, sensorState: SensorState?, connectionState: SensorConnectionState, glucose: SensorGlucose?, glucoseUnit: GlucoseUnit) {
        guard let activity = activity else {
            return
        }

        Task {
            let updatedStatus = getStatus(alarmLow: alarmLow, alarmHigh: alarmHigh, sensorState: sensorState, connectionState: connectionState, glucose: glucose, glucoseUnit: glucoseUnit)
            await activity.update(using: updatedStatus)
        }
    }

    func stop() {
        activityStart = nil
        activityRestart = nil
        activityStop = nil
        activity = nil

        Task {
            let activities = Activity<SensorGlucoseActivityAttributes>.activities
            for activity in activities {
                await activity.end(using: getStatus(), dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: Private

    private var activity: Activity<SensorGlucoseActivityAttributes>?
    private var activityStart: Date?
    private var activityRestart: Date?
    private var activityStop: Date?

    private func getStatus() -> SensorGlucoseActivityAttributes.GlucoseStatus {
        return SensorGlucoseActivityAttributes.GlucoseStatus(alarmLow: 0, alarmHigh: 0)
    }

    private func getStatus(alarmLow: Int, alarmHigh: Int, sensorState: SensorState?, connectionState: SensorConnectionState, glucose: SensorGlucose?, glucoseUnit: GlucoseUnit) -> SensorGlucoseActivityAttributes.GlucoseStatus {
        return SensorGlucoseActivityAttributes.GlucoseStatus(alarmLow: alarmLow, alarmHigh: alarmHigh, sensorState: sensorState, connectionState: connectionState, glucose: glucose, glucoseUnit: glucoseUnit, startDate: activityStart, restartDate: activityRestart, stopDate: activityStop)
    }
}

//
//  ConnectionNotification.swift
//  GlucoseDirect
//

import Combine
import Foundation
import UserNotifications
import WidgetKit

func connectionNotificationMiddelware() -> Middleware<DirectState, DirectAction> {
    return connectionNotificationMiddelware(service: LazyService<ConnectionNotificationService>(initialization: {
        ConnectionNotificationService()
    }))
}

private func connectionNotificationMiddelware(service: LazyService<ConnectionNotificationService>) -> Middleware<DirectState, DirectAction> {
    return { state, action, lastState in
        switch action {
        case .startup:
            guard state.hasConnectionAlarm else {
                DirectLog.info("Guard: connectionAlarm disabled")
                break
            }

            service.value.scheduleSensorConnectionLostAlarm(sound: state.connectionAlarmSound)

        case .shutdown:
            guard state.hasConnectionAlarm else {
                DirectLog.info("Guard: connectionAlarm disabled")
                break
            }

            service.value.scheduleSensorConnectionLostAlarm(sound: state.connectionAlarmSound)

        case .addSensorReadings(readings: _):
            guard state.hasConnectionAlarm else {
                DirectLog.info("Guard: connectionAlarm disabled")
                break
            }

            service.value.scheduleSensorConnectionLostAlarm(sound: state.connectionAlarmSound)

        case let .addSensorGlucose(glucoseValues: glucoseValues):
            guard state.hasConnectionAlarm else {
                DirectLog.info("Guard: connectionAlarm disabled")
                break
            }

            guard !glucoseValues.isEmpty else {
                DirectLog.info("Guard: glucoseValues isEmpty")
                break
            }

            service.value.clearAlarm()

        case let .setConnectionState(connectionState: connectionState):
            guard state.hasConnectionAlarm else {
                DirectLog.info("Guard: connectionAlarm disabled")
                break
            }

            if connectionState == .disconnected, lastState.connectionState != .disconnected {
                service.value.scheduleSensorConnectionLostAlarm(sound: state.connectionAlarmSound)
            }

        case let .setConnectionAlarmSound(sound: sound):
            if sound == .none {
                service.value.clearAlarm()
            }

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}

// MARK: - ConnectionNotificationService

private class ConnectionNotificationService {
    // MARK: Lifecycle

    init() {
        DirectLog.info("Create ConnectionNotificationService")
    }

    // MARK: Internal

    enum Identifier: String {
        case sensorConnectionAlarm = "libre-direct.notifications.sensor-connection-alarm"
    }

    func clearAlarm() {
        DirectLog.info("Clear alarm")
        DirectNotifications.shared.removeNotification(identifier: Identifier.sensorConnectionAlarm.rawValue)
    }

    func scheduleSensorConnectionLostAlarm(sound: NotificationSound) {
        DirectLog.info("Schedule sensor connection lost alarm")

        DirectNotifications.shared.ensureCanSendNotification { state in
            DirectLog.info("Schedule sensor connection lost alarm, state: \(state)")

            UNUserNotificationCenter.current().getPendingNotificationRequests { pendingAlarms in
                let hasPendingAlarm = pendingAlarms.filter {
                    $0.identifier == Identifier.sensorConnectionAlarm.rawValue
                }.count > 0

                guard !hasPendingAlarm else {
                    return
                }

                let notification = UNMutableNotificationContent()

                if sound != .none, state == .sound {
                    notification.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(sound.rawValue).aiff"))
                } else {
                    notification.sound = .none
                }

                notification.title = LocalizedString("Alarm, loss of signal")
                notification.interruptionLevel = .timeSensitive
                notification.body = LocalizedString("No more data is received from the sensor. The cause may be that the Bluetooth connection to the sensor has been interrupted or that the LibreLinkUp is no longer providing data.")

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15 * 60, repeats: true)
                DirectNotifications.shared.addNotification(identifier: Identifier.sensorConnectionAlarm.rawValue, content: notification, trigger: trigger)
            }
        }
    }
}

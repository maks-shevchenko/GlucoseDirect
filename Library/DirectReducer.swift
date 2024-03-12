//
//  DirectReducer.swift
//  GlucoseDirect
//

import Combine
import Foundation
import UIKit

// MARK: - directReducer

func directReducer(state: inout DirectState, action: DirectAction) {
    if !Thread.isMainThread {
        DirectLog.error("Reducer is not used in main thread, action: \(action), queue: \(OperationQueue.current?.underlyingQueue?.label ?? "None")")
    }

    switch action {
    case let .addCalibration(bloodGlucoseValue: bloodGlucoseValue):
        guard let latestGlucoseValue = state.sensorGlucoseValues.last?.rawGlucoseValue else {
            DirectLog.info("Guard: state.currentGlucose.initialGlucoseValue is nil")
            break
        }

        state.customCalibration.append(CustomCalibration(x: Double(latestGlucoseValue), y: Double(bloodGlucoseValue)))

    case let .addBloodGlucose(glucoseValues: glucoseValues):
        state.latestBloodGlucose = glucoseValues.last

    case let .addInsulinDelivery(insulinDeliveryValues: insulinDeliveryValues):
        state.latestInsulinDelivery = insulinDeliveryValues.last

    case let .addSensorGlucose(glucoseValues: glucoseValues):
        state.latestSensorGlucose = glucoseValues.last
        state.connectionError = nil
        state.connectionErrorTimestamp = nil

    case let .addSensorError(errorValues: errorValues):
        state.latestSensorError = errorValues.last

    case .clearCalibrations:
        state.customCalibration = []

    case .clearBloodGlucoseValues:
        state.latestBloodGlucose = nil

    case .clearSensorGlucoseValues:
        state.latestSensorGlucose = nil

    case .clearSensorErrorValues:
        state.latestSensorError = nil

    case let .registerConnectionInfo(infos: infos):
        state.connectionInfos.append(contentsOf: infos)

    case let .deleteCalibration(calibration: calibration):
        state.customCalibration = state.customCalibration.filter { item in
            item.id != calibration.id
        }

    case .resetSensor:
        state.sensor = nil
        state.customCalibration = []
        state.connectionError = nil
        state.connectionErrorTimestamp = nil

    case .resetError:
        state.connectionError = nil
        state.connectionErrorTimestamp = nil

    case let .selectCalendarTarget(id: id):
        state.selectedCalendarTarget = id

    case let .selectConnection(id: id, connection: connection):
        if id != state.selectedConnectionID || state.selectedConnection == nil {
            state.selectedConnectionID = id
            state.selectedConnection = connection

            if let sensor = state.sensor {
                state.selectedConfiguration = connection.getConfiguration(sensor: sensor)
            }
        }

    case .selectConnectionID(id: _):
        state.isConnectionPaired = false
        state.sensor = nil
        state.transmitter = nil
        state.selectedConfiguration = []
        state.customCalibration = []
        state.connectionError = nil
        state.connectionErrorTimestamp = nil

    case let .selectView(viewTag: viewTag):
        state.selectedView = viewTag

    case let .setAlarmHigh(upperLimit: upperLimit):
        state.alarmHigh = upperLimit

    case let .setAlarmLow(lowerLimit: lowerLimit):
        state.alarmLow = lowerLimit

    case let .setAlarmVolume(volume: volume):
        state.alarmVolume = volume

    case let .setAlarmSnoozeUntil(untilDate: untilDate, autosnooze: autosnooze):
        if let untilDate = untilDate {
            state.alarmSnoozeUntil = untilDate

            if let glucose = state.sensorGlucoseValues.last {
                let alarm = state.isAlarm(glucoseValue: glucose.glucoseValue)

                if alarm != .none {
                    state.alarmSnoozeKind = alarm
                }
            }

            if !autosnooze {
                DirectNotifications.shared.stopSound()
            }
        } else {
            state.alarmSnoozeUntil = nil
            state.alarmSnoozeKind = nil
        }

    case let .setAppleCalendarExport(enabled: enabled):
        state.appleCalendarExport = enabled

    case let .setAppleHealthExport(enabled: enabled):
        state.appleHealthExport = enabled

    case let .setAppState(appState: appState):
        state.appState = appState

    case let .setBellmanConnectionState(connectionState: connectionState):
        state.bellmanConnectionState = connectionState

    case let .setBellmanNotification(enabled: enabled):
        state.bellmanAlarm = enabled

    case let .setChartShowLines(enabled: enabled):
        state.chartShowLines = enabled

    case let .setChartZoomLevel(level: level):
        state.chartZoomLevel = level

    case let .setConnectionAlarmSound(sound: sound):
        state.connectionAlarmSound = sound

    case let .setIgnoreMute(enabled: enabled):
        state.ignoreMute = enabled

    case let .setConnectionError(errorMessage: errorMessage, errorTimestamp: errorTimestamp):
        state.connectionError = errorMessage
        state.connectionErrorTimestamp = errorTimestamp

    case let .setConnectionPaired(isPaired: isPaired):
        state.isConnectionPaired = isPaired

    case let .setConnectionPeripheralUUID(peripheralUUID: peripheralUUID):
        state.connectionPeripheralUUID = peripheralUUID

    case let .setConnectionState(connectionState: connectionState):
        state.connectionState = connectionState

        if resetableStates.contains(connectionState) {
            state.connectionError = nil
            state.connectionErrorTimestamp = nil
        }

    case let .setExpiringAlarmSound(sound: sound):
        state.expiringAlarmSound = sound

    case let .setNormalGlucoseNotification(enabled: enabled):
        state.normalGlucoseNotification = enabled

    case let .setAlarmGlucoseNotification(enabled: enabled):
        state.alarmGlucoseNotification = enabled

    case let .setGlucoseLiveActivity(enabled: enabled):
        state.glucoseLiveActivity = enabled

    case let .setGlucoseUnit(unit: unit):
        state.glucoseUnit = unit

    case let .setBloodGlucoseValues(glucoseValues: glucoseValues):
        state.bloodGlucoseValues = glucoseValues

    case let .setInsulinDeliveryValues(insulinDeliveryValues: insulinDeliveryValues):
        state.insulinDeliveryValues = insulinDeliveryValues

    case let .setSensorGlucoseValues(glucoseValues: glucoseValues):
        state.sensorGlucoseValues = glucoseValues

        #if targetEnvironment(simulator)
            if state.latestSensorGlucose == nil {
                state.latestSensorGlucose = glucoseValues.last
            }
        #endif

    case let .setSensorErrorValues(errorValues: errorValues):
        state.sensorErrorValues = errorValues

    case let .setHighGlucoseAlarmSound(sound: sound):
        state.highGlucoseAlarmSound = sound

    case let .setLowGlucoseAlarmSound(sound: sound):
        state.lowGlucoseAlarmSound = sound

    case let .setNightscoutSecret(apiSecret: apiSecret):
        state.nightscoutApiSecret = apiSecret

    case let .setNightscoutUpload(enabled: enabled):
        state.nightscoutUpload = enabled

    case let .setNightscoutURL(url: url):
        state.nightscoutURL = url

    case let .setPreventScreenLock(enabled: enabled):
        state.preventScreenLock = enabled

    case let .setReadGlucose(enabled: enabled):
        state.readGlucose = enabled

    case let .setMinSelectedDate(minSelectedDate: minSelectedDate):
        state.minSelectedDate = min(minSelectedDate, state.minSelectedDate)

    case let .setSelectedDate(selectedDate: date):
        if let date = date, date < Date().startOfDay {
            state.selectedDate = date
        } else {
            state.selectedDate = nil
        }

    case let .setSensor(sensor: sensor, keepDevice: keepDevice):
        if let sensorSerial = state.sensor?.serial, sensorSerial != sensor.serial {
            state.customCalibration = []

            if !keepDevice {
                state.connectionPeripheralUUID = nil
            }
        }

        state.sensor = sensor
        state.connectionError = nil
        state.connectionErrorTimestamp = nil

        if let selectedConnection = state.selectedConnection {
            state.selectedConfiguration = selectedConnection.getConfiguration(sensor: sensor)
        }

    case let .setSensorInterval(interval: interval):
        state.sensorInterval = interval

    case let .setSensorState(sensorAge: sensorAge, sensorState: sensorState):
        guard state.sensor != nil else {
            DirectLog.info("Guard: state.sensor is nil")
            break
        }

        state.sensor!.age = sensorAge

        if let sensorState = sensorState {
            state.sensor!.state = sensorState
        }

        if state.sensor!.startTimestamp == nil, sensorAge > state.sensor!.warmupTime {
            state.sensor!.startTimestamp = Date().toRounded(on: 1, .minute) - Double(sensorAge * 60)
        }

        state.connectionError = nil
        state.connectionErrorTimestamp = nil

    case let .setShowAnnotations(showAnnotations: showAnnotations):
        state.showAnnotations = showAnnotations

    case let .setGlucoseStatistics(statistics: statistics):
        state.glucoseStatistics = statistics

    case let .setTransmitter(transmitter: transmitter):
        state.transmitter = transmitter

    case let .setStatisticsDays(days: days):
        state.statisticsDays = days

    case .exportToUnknown:
        state.appIsBusy = true

    case .exportToTidepool:
        state.appIsBusy = true

    case .exportToGlooko:
        state.appIsBusy = true

    case .sendFile(fileURL: _):
        state.appIsBusy = false

    case let .setAppIsBusy(isBusy: isBusy):
        state.appIsBusy = isBusy

    case let .setShowSmoothedGlucose(enabled: enabled):
        state.showSmoothedGlucose = enabled

    case let .setShowInsulinInput(enabled: enabled):
        state.showInsulinInput = enabled

    default:
        break
    }

    if let alarmSnoozeUntil = state.alarmSnoozeUntil, Date() > alarmSnoozeUntil {
        state.alarmSnoozeUntil = nil
        state.alarmSnoozeKind = nil
    }
}

// MARK: - private

private var resetableStates: Set<SensorConnectionState> = [.connected, .powerOff, .scanning]
private var disconnectedStates: Set<SensorConnectionState> = [.disconnected, .scanning]

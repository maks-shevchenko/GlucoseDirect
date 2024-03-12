//
//  AppState.swift
//  GlucoseDirect
//

import Combine
import Foundation
import SwiftUI
import UserNotifications

#if canImport(CoreNFC)
    import CoreNFC
#endif

// MARK: - AppState

struct AppState: DirectState {
    // MARK: Lifecycle

    init() {
        #if targetEnvironment(simulator)
            let defaultConnectionID = DirectConfig.virtualID
        #else
            #if canImport(CoreNFC)
                let defaultConnectionID = NFCTagReaderSession.readingAvailable
                    ? DirectConfig.libre2ID
                    : DirectConfig.bubbleID
            #else
                let defaultConnectionID = DirectConfig.bubbleID
            #endif
        #endif

        if UserDefaults.shared.glucoseUnit == nil {
            UserDefaults.shared.glucoseUnit = UserDefaults.standard.glucoseUnit ?? .mgdL
        }

        if let sensor = UserDefaults.standard.sensor, UserDefaults.shared.sensor == nil {
            UserDefaults.shared.sensor = sensor
        }

        if let transmitter = UserDefaults.standard.transmitter, UserDefaults.shared.transmitter == nil {
            UserDefaults.shared.transmitter = transmitter
        }

        alarmHigh = UserDefaults.standard.alarmHigh
        alarmLow = UserDefaults.standard.alarmLow
        alarmVolume = UserDefaults.standard.alarmVolume
        appleCalendarExport = UserDefaults.standard.appleCalendarExport
        appleHealthExport = UserDefaults.standard.appleHealthExport
        bellmanAlarm = UserDefaults.standard.bellmanAlarm
        chartShowLines = UserDefaults.standard.chartShowLines
        chartZoomLevel = UserDefaults.standard.chartZoomLevel
        connectionAlarmSound = UserDefaults.standard.connectionAlarmSound
        connectionPeripheralUUID = UserDefaults.standard.connectionPeripheralUUID
        customCalibration = UserDefaults.standard.customCalibration
        expiringAlarmSound = UserDefaults.standard.expiringAlarmSound
        normalGlucoseNotification = UserDefaults.standard.normalGlucoseNotification
        alarmGlucoseNotification = UserDefaults.standard.alarmGlucoseNotification
        glucoseLiveActivity = UserDefaults.standard.glucoseLiveActivity
        ignoreMute = UserDefaults.standard.ignoreMute
        glucoseUnit = UserDefaults.shared.glucoseUnit ?? .mgdL
        highGlucoseAlarmSound = UserDefaults.standard.highGlucoseAlarmSound
        isConnectionPaired = UserDefaults.standard.isConnectionPaired
        latestBloodGlucose = UserDefaults.shared.latestBloodGlucose
        latestSensorGlucose = UserDefaults.shared.latestSensorGlucose
        latestSensorError = UserDefaults.shared.latestSensorError
        latestInsulinDelivery = UserDefaults.shared.latestInsulinDelivery
        lowGlucoseAlarmSound = UserDefaults.standard.lowGlucoseAlarmSound
        nightscoutApiSecret = UserDefaults.standard.nightscoutApiSecret
        nightscoutUpload = UserDefaults.standard.nightscoutUpload
        nightscoutURL = UserDefaults.standard.nightscoutURL
        readGlucose = UserDefaults.standard.readGlucose
        selectedCalendarTarget = UserDefaults.standard.selectedCalendarTarget
        selectedConnectionID = UserDefaults.standard.selectedConnectionID ?? defaultConnectionID
        sensor = UserDefaults.shared.sensor
        sensorInterval = UserDefaults.standard.sensorInterval
        showAnnotations = UserDefaults.standard.showAnnotations
        transmitter = UserDefaults.shared.transmitter
        showSmoothedGlucose = UserDefaults.standard.showSmoothedGlucose
        showInsulinInput = UserDefaults.standard.showInsulinInput
    }

    // MARK: Internal

    var appIsBusy = false
    var appState: ScenePhase = .inactive
    var alarmSnoozeUntil: Date? = nil
    var alarmSnoozeKind: Alarm?
    var bellmanConnectionState: BellmanConnectionState = .disconnected
    var bloodGlucoseHistory: [BloodGlucose] = []
    var bloodGlucoseValues: [BloodGlucose] = []
    var insulinDeliveryValues: [InsulinDelivery] = []
    var connectionError: String?
    var connectionErrorTimestamp: Date?
    var connectionInfos: [SensorConnectionInfo] = []
    var connectionState: SensorConnectionState = .disconnected
    var preventScreenLock = false
    var selectedConnection: SensorConnectionProtocol?
    var selectedConfiguration: [SensorConnectionConfigurationOption] = []
    var minSelectedDate: Date = .init()
    var selectedDate: Date?
    var sensorErrorValues: [SensorError] = []
    var sensorGlucoseHistory: [SensorGlucose] = []
    var sensorGlucoseValues: [SensorGlucose] = []
    var glucoseStatistics: GlucoseStatistics?
    var targetValue = 100
    var selectedView = DirectConfig.overviewViewTag
    var statisticsDays = 3

    var appSerial: String {
        UserDefaults.shared.appSerial
    }

    var alarmHigh: Int { didSet { UserDefaults.standard.alarmHigh = alarmHigh } }
    var alarmLow: Int { didSet { UserDefaults.standard.alarmLow = alarmLow } }
    var alarmVolume: Float { didSet { UserDefaults.standard.alarmVolume = alarmVolume } }
    var appleCalendarExport: Bool { didSet { UserDefaults.standard.appleCalendarExport = appleCalendarExport } }
    var appleHealthExport: Bool { didSet { UserDefaults.standard.appleHealthExport = appleHealthExport } }
    var bellmanAlarm: Bool { didSet { UserDefaults.standard.bellmanAlarm = bellmanAlarm } }
    var chartShowLines: Bool { didSet { UserDefaults.standard.chartShowLines = chartShowLines } }
    var chartZoomLevel: Int { didSet { UserDefaults.standard.chartZoomLevel = chartZoomLevel } }
    var connectionAlarmSound: NotificationSound { didSet { UserDefaults.standard.connectionAlarmSound = connectionAlarmSound } }
    var connectionPeripheralUUID: String? { didSet { UserDefaults.standard.connectionPeripheralUUID = connectionPeripheralUUID } }
    var customCalibration: [CustomCalibration] { didSet { UserDefaults.standard.customCalibration = customCalibration } }
    var expiringAlarmSound: NotificationSound { didSet { UserDefaults.standard.expiringAlarmSound = expiringAlarmSound } }
    var normalGlucoseNotification: Bool { didSet { UserDefaults.standard.normalGlucoseNotification = normalGlucoseNotification } }
    var alarmGlucoseNotification: Bool { didSet { UserDefaults.standard.alarmGlucoseNotification = alarmGlucoseNotification } }
    var glucoseLiveActivity: Bool { didSet { UserDefaults.standard.glucoseLiveActivity = glucoseLiveActivity } }
    var glucoseUnit: GlucoseUnit { didSet { UserDefaults.shared.glucoseUnit = glucoseUnit } }
    var highGlucoseAlarmSound: NotificationSound { didSet { UserDefaults.standard.highGlucoseAlarmSound = highGlucoseAlarmSound } }
    var ignoreMute: Bool { didSet { UserDefaults.standard.ignoreMute = ignoreMute } }
    var isConnectionPaired: Bool { didSet { UserDefaults.standard.isConnectionPaired = isConnectionPaired } }
    var latestBloodGlucose: BloodGlucose? { didSet { UserDefaults.shared.latestBloodGlucose = latestBloodGlucose } }
    var latestSensorError: SensorError? { didSet { UserDefaults.shared.latestSensorError = latestSensorError } }
    var latestSensorGlucose: SensorGlucose? { didSet { UserDefaults.shared.latestSensorGlucose = latestSensorGlucose } }
    var latestInsulinDelivery: InsulinDelivery? { didSet { UserDefaults.shared.latestInsulinDelivery = latestInsulinDelivery } }
    var lowGlucoseAlarmSound: NotificationSound { didSet { UserDefaults.standard.lowGlucoseAlarmSound = lowGlucoseAlarmSound } }
    var nightscoutApiSecret: String { didSet { UserDefaults.standard.nightscoutApiSecret = nightscoutApiSecret } }
    var nightscoutUpload: Bool { didSet { UserDefaults.standard.nightscoutUpload = nightscoutUpload } }
    var nightscoutURL: String { didSet { UserDefaults.standard.nightscoutURL = nightscoutURL } }
    var readGlucose: Bool { didSet { UserDefaults.standard.readGlucose = readGlucose } }
    var selectedCalendarTarget: String? { didSet { UserDefaults.standard.selectedCalendarTarget = selectedCalendarTarget } }
    var selectedConnectionID: String? { didSet { UserDefaults.standard.selectedConnectionID = selectedConnectionID } }
    var sensor: Sensor? { didSet { UserDefaults.shared.sensor = sensor } }
    var sensorInterval: Int { didSet { UserDefaults.standard.sensorInterval = sensorInterval } }
    var showAnnotations: Bool { didSet { UserDefaults.standard.showAnnotations = showAnnotations } }
    var transmitter: Transmitter? { didSet { UserDefaults.shared.transmitter = transmitter } }
    var showSmoothedGlucose: Bool { didSet { UserDefaults.standard.showSmoothedGlucose = showSmoothedGlucose } }
    var showInsulinInput: Bool { didSet { UserDefaults.standard.showInsulinInput = showInsulinInput } }
}

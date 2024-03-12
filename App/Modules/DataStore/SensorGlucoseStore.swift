//
//  SensorGlucoseStore.swift
//  GlucoseDirectApp
//
//  https://github.com/groue/GRDB.swift
//

import Combine
import Foundation
import GRDB

func glucoseStatisticsMiddleware() -> Middleware<DirectState, DirectAction> {
    return { state, action, _ in
        switch action {
        case .loadSensorGlucoseValues:
            return Just(DirectAction.loadSensorGlucoseStatistics)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .setAlarmLow(lowerLimit: _):
            return Just(DirectAction.loadSensorGlucoseStatistics)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .setAlarmHigh(upperLimit: _):
            return Just(DirectAction.loadSensorGlucoseStatistics)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .setStatisticsDays(days: _):
            return Just(DirectAction.loadSensorGlucoseStatistics)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .loadSensorGlucoseStatistics:
            guard state.appState == .active else {
                break
            }

            return DataStore.shared.getSensorGlucoseStatistics(days: state.statisticsDays, lowerLimit: state.alarmLow, upperLimit: state.alarmHigh).map { statistics in
                DirectAction.setGlucoseStatistics(statistics: statistics)
            }.eraseToAnyPublisher()

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}

func sensorGlucoseStoreMiddleware() -> Middleware<DirectState, DirectAction> {
    return { state, action, _ in
        switch action {
        case .startup:
            DataStore.shared.createSensorGlucoseTable()

            return DataStore.shared.getFirstSensorGlucoseDate().map { minSelectedDate in
                DirectAction.setMinSelectedDate(minSelectedDate: minSelectedDate)
            }.eraseToAnyPublisher()

        case let .addSensorGlucose(glucoseValues: glucoseValues):
            guard !glucoseValues.isEmpty else {
                break
            }

            DataStore.shared.insertSensorGlucose(glucoseValues)

            return Just(DirectAction.loadSensorGlucoseValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case let .deleteSensorGlucose(glucose: glucose):
            DataStore.shared.deleteSensorGlucose(glucose)

            return Just(DirectAction.loadSensorGlucoseValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .clearSensorGlucoseValues:
            DataStore.shared.deleteAllSensorGlucose()

            return Just(DirectAction.loadSensorGlucoseValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .setSelectedDate(selectedDate: _):
            return Just(DirectAction.loadSensorGlucoseValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .loadSensorGlucoseValues:
            guard state.appState == .active else {
                break
            }

            return DataStore.shared.getSensorGlucoseValues(selectedDate: state.selectedDate).map { glucoseValues in
                DirectAction.setSensorGlucoseValues(glucoseValues: glucoseValues)
            }.eraseToAnyPublisher()

        case let .setAppState(appState: appState):
            guard appState == .active else {
                break
            }

            return Just(DirectAction.loadSensorGlucoseValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}

private extension DataStore {
    func createSensorGlucoseTable() {
        if let dbQueue = dbQueue {
            do {
                try dbQueue.write { db in
                    try db.create(table: SensorGlucose.Table, ifNotExists: true) { t in
                        t.column(SensorGlucose.Columns.id.name, .text)
                            .primaryKey()
                        t.column(SensorGlucose.Columns.timestamp.name, .date)
                            .notNull()
                            .indexed()
                        t.column(SensorGlucose.Columns.minuteChange.name, .double)
                        t.column(SensorGlucose.Columns.rawGlucoseValue.name, .integer)
                            .notNull()
                        t.column(SensorGlucose.Columns.intGlucoseValue.name, .integer)
                            .notNull()
                        t.column(SensorGlucose.Columns.timegroup.name, .date)
                            .notNull()
                            .indexed()
                    }
                }
            } catch {
                DirectLog.error("\(error)")
            }

            var migrator = DatabaseMigrator()

            migrator.registerMigration("Add column 'smoothGlucoseValue'") { db in
                try db.alter(table: SensorGlucose.Table) { t in
                    t.add(column: SensorGlucose.Columns.smoothGlucoseValue.name, .double)
                }
            }

            migrator.registerMigration("Fill column 'smoothGlucoseValue'") { db in
                let filter = GlucoseFilter()
                let glucoseValues = try Row.fetchAll(db, sql: "SELECT \(SensorGlucose.Columns.id.name), \(SensorGlucose.Columns.rawGlucoseValue.name) FROM \(SensorGlucose.databaseTableName) ORDER BY \(SensorGlucose.Columns.timestamp.name)")

                for row in glucoseValues {
                    let id: UUID = row[SensorGlucose.Columns.id.name]
                    let rawGlucoseValue: Int = row[SensorGlucose.Columns.rawGlucoseValue.name]
                    let smoothGlucoseValue = filter.filter(glucoseValue: rawGlucoseValue, initGlucoseValues: [])
                    try db.execute(
                        sql: "UPDATE \(SensorGlucose.databaseTableName) SET \(SensorGlucose.Columns.smoothGlucoseValue.name) = :value WHERE \(SensorGlucose.Columns.id.name) = :id",
                        arguments: ["value": smoothGlucoseValue, "id": id.uuidString]
                    )
                }
            }

            do {
                try migrator.migrate(dbQueue)
            } catch {
                DirectLog.error("\(error)")
            }
        }
    }

    func deleteAllSensorGlucose() {
        if let dbQueue = dbQueue {
            do {
                try dbQueue.write { db in
                    do {
                        try SensorGlucose.deleteAll(db)
                    } catch {
                        DirectLog.error("\(error)")
                    }
                }
            } catch {
                DirectLog.error("\(error)")
            }
        }
    }

    func deleteSensorGlucose(_ value: SensorGlucose) {
        if let dbQueue = dbQueue {
            do {
                try dbQueue.write { db in
                    do {
                        try SensorGlucose.deleteOne(db, id: value.id)
                    } catch {
                        DirectLog.error("\(error)")
                    }
                }
            } catch {
                DirectLog.error("\(error)")
            }
        }
    }

    func insertSensorGlucose(_ values: [SensorGlucose]) {
        if let dbQueue = dbQueue {
            do {
                for value in values {
                    try dbQueue.write { db in
                        let count = try SensorGlucose
                            .filter(Column(SensorGlucose.Columns.timestamp.name) == value.timestamp)
                            .fetchCount(db)

                        if count == 0 {
                            try value.insert(db)
                        }
                    }
                }
            } catch {
                DirectLog.error("\(error)")
            }
        }
    }

    func getSensorGlucoseStatistics(days: Int, lowerLimit: Int, upperLimit: Int) -> Future<GlucoseStatistics, DirectError> {
        return Future { promise in
            if let dbQueue = self.dbQueue {
                dbQueue.asyncRead { asyncDB in
                    do {
                        let db = try asyncDB.get()

                        if let row = try Row.fetchOne(db, sql: """
                            SELECT
                                COUNT(sg.intGlucoseValue) AS readings,
                                IFNULL(MIN(sg.timestamp), DATETIME('now', 'utc')) AS fromTimestamp,
                                IFNULL(MAX(sg.timestamp), DATETIME('now', 'utc')) AS toTimestamp,
                                IFNULL(3.31 + (0.02392 * sub.avg), 0) AS gmi,
                                IFNULL(sub.avg, 0) AS avg,
                                IFNULL(100.0 / COUNT(sg.intGlucoseValue) * COUNT(CASE WHEN sg.intGlucoseValue < :low THEN 1 END), 0) AS tbr,
                                IFNULL(100.0 / COUNT(sg.intGlucoseValue) * COUNT(CASE WHEN sg.intGlucoseValue > :high THEN 1 END), 0) AS tar,
                                ROUND(IFNULL(JULIANDAY(MAX(sg.timestamp)) - JULIANDAY(MIN(sg.timestamp)), 0)) AS days,
                                IFNULL(AVG((sg.intGlucoseValue - sub.avg) * (sg.intGlucoseValue - sub.avg)), 0) as variance,
                                ROUND((SELECT IFNULL(JULIANDAY(MAX(timestamp)) - JULIANDAY(MIN(timestamp)), 0) FROM \(SensorGlucose.Table))) as maxDays
                            FROM \(SensorGlucose.Table) sg, (
                                    SELECT AVG(ssg.intGlucoseValue) AS avg
                                    FROM \(SensorGlucose.Table) ssg
                                    WHERE ssg.timestamp >= DATETIME('now', 'start of day', :days, 'utc') AND ssg.timestamp <= DATETIME('now', 'start of day', 'utc')
                                ) AS sub
                            WHERE sg.timestamp >= DATETIME('now', 'start of day', :days, 'utc') and sg.timestamp < DATETIME('now', 'start of day', 'utc')
                        """, arguments: ["days": "-\(days) days", "low": lowerLimit, "high": upperLimit]) {
                            let statistics = GlucoseStatistics(
                                readings: row["readings"],
                                fromTimestamp: row["fromTimestamp"],
                                toTimestamp: row["toTimestamp"],
                                gmi: row["gmi"],
                                avg: row["avg"],
                                tbr: row["tbr"],
                                tar: row["tar"],
                                variance: row["variance"],
                                days: row["days"],
                                maxDays: row["maxDays"]
                            )

                            promise(.success(statistics))
                        } else {
                            promise(.failure(.withMessage("No statistics available")))
                        }
                    } catch {
                        promise(.failure(.withError(error)))
                    }
                }
            }
        }
    }

    func getFirstSensorGlucoseDate() -> Future<Date, DirectError> {
        return Future { promise in
            if let dbQueue = self.dbQueue {
                dbQueue.asyncRead { asyncDB in
                    do {
                        let db = try asyncDB.get()

                        if let date = try Date.fetchOne(db, sql: "SELECT MIN(timestamp) FROM \(SensorGlucose.Table)") {
                            promise(.success(date))
                        } else {
                            promise(.success(Date()))
                        }
                    } catch {
                        promise(.failure(.withError(error)))
                    }
                }
            }
        }
    }

    func getSensorGlucoseValues(selectedDate: Date? = nil) -> Future<[SensorGlucose], DirectError> {
        return Future { promise in
            if let dbQueue = self.dbQueue {
                dbQueue.asyncRead { asyncDB in
                    do {
                        let db = try asyncDB.get()

                        if let selectedDate = selectedDate, let nextDate = Calendar.current.date(byAdding: .day, value: +1, to: selectedDate) {
                            let result = try SensorGlucose
                                .filter(Column(SensorGlucose.Columns.timestamp.name) >= selectedDate.startOfDay)
                                .filter(nextDate.startOfDay > Column(SensorGlucose.Columns.timestamp.name))
                                .order(Column(SensorGlucose.Columns.timestamp.name))
                                .fetchAll(db)

                            promise(.success(result))
                        } else {
                            let result = try SensorGlucose
                                .filter(sql: "\(SensorGlucose.Columns.timestamp.name) >= datetime('now', '-\(DirectConfig.lastChartHours) hours')")
                                .order(Column(SensorGlucose.Columns.timestamp.name))
                                .fetchAll(db)

                            promise(.success(result))
                        }
                    } catch {
                        promise(.failure(.withError(error)))
                    }
                }
            }
        }
    }
}

//
//  BloodGlucoseStore.swift
//  GlucoseDirectApp
//
//  https://github.com/groue/GRDB.swift
//

import Combine
import Foundation
import GRDB

func bloodGlucoseStoreMiddleware() -> Middleware<DirectState, DirectAction> {
    return { state, action, _ in
        switch action {
        case .startup:
            DataStore.shared.createBloodGlucoseTable()

            return DataStore.shared.getFirstBloodGlucoseDate().map { minSelectedDate in
                DirectAction.setMinSelectedDate(minSelectedDate: minSelectedDate)
            }.eraseToAnyPublisher()

        case let .addBloodGlucose(glucoseValues: glucoseValues):
            guard !glucoseValues.isEmpty else {
                break
            }

            DataStore.shared.insertBloodGlucose(glucoseValues)

            return Just(DirectAction.loadBloodGlucoseValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case let .deleteBloodGlucose(glucose: glucose):
            DataStore.shared.deleteBloodGlucose(glucose)

            return Just(DirectAction.loadBloodGlucoseValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .clearBloodGlucoseValues:
            DataStore.shared.deleteAllBloodGlucose()

            return Just(DirectAction.loadBloodGlucoseValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .setSelectedDate(selectedDate: _):
            return Just(DirectAction.loadBloodGlucoseValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .loadBloodGlucoseValues:
            guard state.appState == .active else {
                break
            }

            return DataStore.shared.getBloodGlucoseValues(selectedDate: state.selectedDate).map { glucoseValues in
                DirectAction.setBloodGlucoseValues(glucoseValues: glucoseValues)
            }.eraseToAnyPublisher()

        case let .setAppState(appState: appState):
            guard appState == .active else {
                break
            }

            return Just(DirectAction.loadBloodGlucoseValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}

private extension DataStore {
    func createBloodGlucoseTable() {
        if let dbQueue = dbQueue {
            do {
                try dbQueue.write { db in
                    try db.create(table: BloodGlucose.Table, ifNotExists: true) { t in
                        t.column(BloodGlucose.Columns.id.name, .text)
                            .primaryKey()
                        t.column(BloodGlucose.Columns.timestamp.name, .date)
                            .notNull()
                            .indexed()
                        t.column(BloodGlucose.Columns.glucoseValue.name, .integer)
                            .notNull()
                        t.column(BloodGlucose.Columns.timegroup.name, .date)
                            .notNull()
                            .indexed()
                    }
                }
            } catch {
                DirectLog.error("\(error)")
            }
        }
    }

    func deleteAllBloodGlucose() {
        if let dbQueue = dbQueue {
            do {
                try dbQueue.write { db in
                    do {
                        try BloodGlucose.deleteAll(db)
                    } catch {
                        DirectLog.error("\(error)")
                    }
                }
            } catch {
                DirectLog.error("\(error)")
            }
        }
    }

    func deleteBloodGlucose(_ value: BloodGlucose) {
        if let dbQueue = dbQueue {
            do {
                try dbQueue.write { db in
                    do {
                        try BloodGlucose.deleteOne(db, id: value.id)
                    } catch {
                        DirectLog.error("\(error)")
                    }
                }
            } catch {
                DirectLog.error("\(error)")
            }
        }
    }

    func insertBloodGlucose(_ values: [BloodGlucose]) {
        if let dbQueue = dbQueue {
            do {
                try dbQueue.write { db in
                    for value in values {
                        do {
                            try value.insert(db)
                        } catch {
                            DirectLog.error("\(error)")
                        }
                    }
                }
            } catch {
                DirectLog.error("\(error)")
            }
        }
    }

    func getFirstBloodGlucoseDate() -> Future<Date, DirectError> {
        return Future { promise in
            if let dbQueue = self.dbQueue {
                dbQueue.asyncRead { asyncDB in
                    do {
                        let db = try asyncDB.get()

                        if let date = try Date.fetchOne(db, sql: "SELECT MIN(timestamp) FROM \(BloodGlucose.Table)") {
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

    func getBloodGlucoseValues(selectedDate: Date? = nil) -> Future<[BloodGlucose], DirectError> {
        return Future { promise in
            if let dbQueue = self.dbQueue {
                dbQueue.asyncRead { asyncDB in
                    do {
                        let db = try asyncDB.get()

                        if let selectedDate = selectedDate, let nextDate = Calendar.current.date(byAdding: .day, value: +1, to: selectedDate) {
                            let result = try BloodGlucose
                                .filter(Column(SensorGlucose.Columns.timestamp.name) >= selectedDate.startOfDay)
                                .filter(nextDate.startOfDay > Column(SensorGlucose.Columns.timestamp.name))
                                .order(Column(BloodGlucose.Columns.timestamp.name))
                                .fetchAll(db)

                            promise(.success(result))
                        } else {
                            let result = try BloodGlucose
                                .filter(sql: "\(BloodGlucose.Columns.timestamp.name) >= datetime('now', '-\(DirectConfig.lastChartHours) hours')")
                                .order(Column(BloodGlucose.Columns.timestamp.name))
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

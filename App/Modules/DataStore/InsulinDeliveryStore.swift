//
//  InsulinDeliveryStore.swift
//  GlucoseDirectApp
//

import Combine
import Foundation
import GRDB

func insulinDeliveryStoreMiddleware() -> Middleware<DirectState, DirectAction> {
    return { state, action, _ in
        switch action {
        case .startup:
            DataStore.shared.createInsulinDeliveryTable()

            return DataStore.shared.getFirstInsulinDeliveryDate().map { minSelectedDate in
                DirectAction.setMinSelectedDate(minSelectedDate: minSelectedDate)
            }.eraseToAnyPublisher()

        case let .addInsulinDelivery(insulinDeliveryValues: insulinDeliveryValues):
            guard !insulinDeliveryValues.isEmpty else {
                break
            }

            DataStore.shared.insertInsulinDelivery(insulinDeliveryValues)

            return Just(DirectAction.loadInsulinDeliveryValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case let .deleteInsulinDelivery(insulinDelivery: insulinDelivery):
            DataStore.shared.deleteInsulinDelivery(insulinDelivery)

            return Just(DirectAction.loadInsulinDeliveryValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .clearBloodGlucoseValues:
            DataStore.shared.deleteAllInsulinDelivery()

            return Just(DirectAction.loadInsulinDeliveryValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .setSelectedDate(selectedDate: _):
            return Just(DirectAction.loadInsulinDeliveryValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .loadInsulinDeliveryValues:
            guard state.appState == .active else {
                break
            }

            return DataStore.shared.getInsulinDeliveryValues(selectedDate: state.selectedDate).map { insulinDeliveryValues in
                DirectAction.setInsulinDeliveryValues(insulinDeliveryValues: insulinDeliveryValues)
            }.eraseToAnyPublisher()

        case let .setAppState(appState: appState):
            guard appState == .active else {
                break
            }

            return Just(DirectAction.loadInsulinDeliveryValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}

private extension DataStore {
    func createInsulinDeliveryTable() {
        if let dbQueue = dbQueue {
            do {
                try dbQueue.write { db in
                    try db.create(table: InsulinDelivery.Table, ifNotExists: true) { t in
                        t.column(InsulinDelivery.Columns.id.name, .text)
                            .primaryKey()
                        t.column(InsulinDelivery.Columns.starts.name, .date)
                            .notNull()
                            .indexed()
                        t.column(InsulinDelivery.Columns.ends.name, .date)
                            .notNull()
                            .indexed()
                        t.column(InsulinDelivery.Columns.units.name, .double)
                            .notNull()
                        t.column(InsulinDelivery.Columns.type.name, .text)
                            .notNull()
                            .indexed()
                        t.column(InsulinDelivery.Columns.timegroup.name, .date)
                            .notNull()
                            .indexed()
                    }
                }
            } catch {
                DirectLog.error("\(error)")
            }
        }
    }

    func deleteAllInsulinDelivery() {
        if let dbQueue = dbQueue {
            do {
                try dbQueue.write { db in
                    do {
                        try InsulinDelivery.deleteAll(db)
                    } catch {
                        DirectLog.error("\(error)")
                    }
                }
            } catch {
                DirectLog.error("\(error)")
            }
        }
    }

    func deleteInsulinDelivery(_ value: InsulinDelivery) {
        if let dbQueue = dbQueue {
            do {
                try dbQueue.write { db in
                    do {
                        try InsulinDelivery.deleteOne(db, id: value.id)
                    } catch {
                        DirectLog.error("\(error)")
                    }
                }
            } catch {
                DirectLog.error("\(error)")
            }
        }
    }

    func insertInsulinDelivery(_ values: [InsulinDelivery]) {
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

    func getFirstInsulinDeliveryDate() -> Future<Date, DirectError> {
        return Future { promise in
            if let dbQueue = self.dbQueue {
                dbQueue.asyncRead { asyncDB in
                    do {
                        let db = try asyncDB.get()

                        if let date = try Date.fetchOne(db, sql: "SELECT MIN(starts) FROM \(InsulinDelivery.Table)") {
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

    func getInsulinDeliveryValues(selectedDate: Date? = nil) -> Future<[InsulinDelivery], DirectError> {
        return Future { promise in
            if let dbQueue = self.dbQueue {
                dbQueue.asyncRead { asyncDB in
                    do {
                        let db = try asyncDB.get()

                        if let selectedDate = selectedDate, let nextDate = Calendar.current.date(byAdding: .day, value: +1, to: selectedDate) {
                            let result = try InsulinDelivery
                                .filter(Column(InsulinDelivery.Columns.starts.name) >= selectedDate.startOfDay)
                                .filter(nextDate.startOfDay > Column(InsulinDelivery.Columns.starts.name))
                                .order(Column(InsulinDelivery.Columns.starts.name))
                                .fetchAll(db)

                            promise(.success(result))
                        } else {
                            let result = try InsulinDelivery
                                .filter(sql: "\(InsulinDelivery.Columns.starts.name) >= datetime('now', '-\(DirectConfig.lastChartHours) hours') OR \(InsulinDelivery.Columns.ends.name) >= datetime('now', '-\(DirectConfig.lastChartHours) hours')")
                                .order(Column(InsulinDelivery.Columns.starts.name))
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

//
//  Nightscout.swift
//  GlucoseDirect
//

import Combine
import Foundation

func nightscoutMiddleware() -> Middleware<DirectState, DirectAction> {
    return nightscoutMiddleware(service: LazyService<NightscoutService>(initialization: {
        NightscoutService()
    }))
}

private func nightscoutMiddleware(service: LazyService<NightscoutService>) -> Middleware<DirectState, DirectAction> {
    return { state, action, lastState in
        let nightscoutURL = state.nightscoutURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let nightscoutApiSecret = state.nightscoutApiSecret

        if state.nightscoutUpload, !nightscoutURL.isEmpty, !nightscoutApiSecret.isEmpty {
            switch action {
            case let .deleteBloodGlucose(glucose: glucose):
                service.value.deleteBloodGlucose(nightscoutURL: nightscoutURL, apiSecret: nightscoutApiSecret.toSha1(), id: glucose.id.uuidString)

            case let .deleteSensorGlucose(glucose: glucose):
                service.value.deleteSensorGlucose(nightscoutURL: nightscoutURL, apiSecret: nightscoutApiSecret.toSha1(), id: glucose.id.uuidString)

            case let .deleteInsulinDelivery(insulinDelivery: insulinDeliveryValue):
                service.value.deleteInsulinDelivery(nightscoutURL: nightscoutURL, apiSecret: nightscoutApiSecret.toSha1(), id: insulinDeliveryValue.id.uuidString)

            case .clearBloodGlucoseValues:
                service.value.clearBloodGlucoseValues(nightscoutURL: nightscoutURL, apiSecret: nightscoutApiSecret.toSha1())

            case .clearSensorGlucoseValues:
                service.value.clearSensorGlucoseValues(nightscoutURL: nightscoutURL, apiSecret: nightscoutApiSecret.toSha1())

            case let .addBloodGlucose(glucoseValues: glucoseValues):
                service.value.addBloodGlucose(nightscoutURL: nightscoutURL, apiSecret: nightscoutApiSecret.toSha1(), glucoseValues: glucoseValues)

            case let .addSensorGlucose(glucoseValues: glucoseValues):
                guard let glucose = glucoseValues.last, glucose.type != .high else {
                    break
                }

                service.value.addSensorGlucose(nightscoutURL: nightscoutURL, apiSecret: nightscoutApiSecret.toSha1(), glucoseValues: glucoseValues)

            case .setSensorState(sensorAge: _, sensorState: _):
                guard let sensor = state.sensor, sensor.startTimestamp != nil else {
                    DirectLog.info("Guard: state.sensor or sensor.startTimestamp is nil")
                    break
                }

                guard lastState.sensor == nil || lastState.sensor!.startTimestamp == nil else {
                    DirectLog.info("Guard: lastState.sensor and lastState.sensor!.startTimestamp not nil")
                    break
                }

                guard let serial = sensor.serial else {
                    DirectLog.info("Guard: sensor.serial is nil")
                    break
                }

                service.value.isSensorStarted(nightscoutURL: nightscoutURL, apiSecret: nightscoutApiSecret.toSha1(), serial: serial) { isStarted in
                    if let isStarted = isStarted, !isStarted {
                        service.value.setSensorStart(nightscoutURL: nightscoutURL, apiSecret: nightscoutApiSecret.toSha1(), sensor: sensor)
                    }
                }
            case let .addInsulinDelivery(insulinDeliveryValues: insulinDeliveryValues):
                service.value.addInsulinDelivery(nightscoutURL: nightscoutURL, apiSecret: nightscoutApiSecret.toSha1(), insulinDeliveryValues: insulinDeliveryValues)

            default:
                break
            }
        }

        return Empty().eraseToAnyPublisher()
    }
}

// MARK: - NightscoutService

private class NightscoutService {
    // MARK: Lifecycle

    init() {
        DirectLog.info("Create NightscoutService")
    }

    // MARK: Internal

    func setSensorStart(nightscoutURL: String, apiSecret: String, sensor: Sensor) {
        let nightscoutValue = sensor.toNightscoutSensorStart()

        guard let nightscoutValue = nightscoutValue else {
            return
        }

        guard let nightscoutJson = try? JSONSerialization.data(withJSONObject: nightscoutValue) else {
            return
        }

        let session = URLSession.shared

        let urlString = "\(nightscoutURL)/api/v1/treatments"
        guard let url = URL(string: urlString) else {
            DirectLog.error("Nightscout, bad nightscout url")
            return
        }

        let request = createRequest(url: url, method: "POST", apiSecret: apiSecret)

        let task = session.uploadTask(with: request, from: nightscoutJson) { data, response, error in
            if let error = error {
                DirectLog.info("Nightscout error: \(error)")
                return
            }

            if let response = response as? HTTPURLResponse {
                let status = response.statusCode

                if status != 200, let data = data {
                    let responseString = String(data: data, encoding: .utf8)
                    DirectLog.info("Nightscout error: \(response.statusCode) \(responseString)")
                }
            }
        }

        task.resume()
    }

    func clearBloodGlucoseValues(nightscoutURL: String, apiSecret: String) {
        let session = URLSession.shared

        let urlString = "\(nightscoutURL)/api/v1/entries?find[device]=\(DirectConfig.projectName)&find[type]=mbg"
        guard let url = URL(string: urlString) else {
            DirectLog.error("Nightscout, bad nightscout url")
            return
        }

        let request = createRequest(url: url, method: "DELETE", apiSecret: apiSecret)

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DirectLog.info("Nightscout error: \(error)")
                return
            }

            if let response = response as? HTTPURLResponse {
                let status = response.statusCode
                if status != 200, let data = data {
                    let responseString = String(data: data, encoding: .utf8)
                    DirectLog.info("Nightscout error: \(response.statusCode) \(responseString)")
                }
            }
        }

        task.resume()
    }

    func clearSensorGlucoseValues(nightscoutURL: String, apiSecret: String) {
        let session = URLSession.shared

        let urlString = "\(nightscoutURL)/api/v1/entries?find[device]=\(DirectConfig.projectName)&find[type]=sgv"
        guard let url = URL(string: urlString) else {
            DirectLog.error("Nightscout, bad nightscout url")
            return
        }

        let request = createRequest(url: url, method: "DELETE", apiSecret: apiSecret)

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DirectLog.info("Nightscout error: \(error)")
                return
            }

            if let response = response as? HTTPURLResponse {
                let status = response.statusCode
                if status != 200, let data = data {
                    let responseString = String(data: data, encoding: .utf8)
                    DirectLog.info("Nightscout error: \(response.statusCode) \(responseString)")
                }
            }
        }

        task.resume()
    }

    func deleteBloodGlucose(nightscoutURL: String, apiSecret: String, id: String) {
        let session = URLSession.shared

        let urlString = "\(nightscoutURL)/api/v1/entries?find[glucoseDirect]=\(id)"
        guard let url = URL(string: urlString) else {
            DirectLog.error("Nightscout, bad nightscout url")
            return
        }

        let request = createRequest(url: url, method: "DELETE", apiSecret: apiSecret)

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DirectLog.info("Nightscout error: \(error)")
                return
            }

            if let response = response as? HTTPURLResponse {
                let status = response.statusCode
                if status != 200, let data = data {
                    let responseString = String(data: data, encoding: .utf8)
                    DirectLog.info("Nightscout error: \(response.statusCode) \(responseString)")
                }
            }
        }

        task.resume()
    }

    func deleteSensorGlucose(nightscoutURL: String, apiSecret: String, id: String) {
        let session = URLSession.shared

        let urlString = "\(nightscoutURL)/api/v1/entries?find[glucoseDirect]=\(id)"
        guard let url = URL(string: urlString) else {
            DirectLog.error("Nightscout, bad nightscout url")
            return
        }

        let request = createRequest(url: url, method: "DELETE", apiSecret: apiSecret)

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DirectLog.info("Nightscout error: \(error)")
                return
            }

            if let response = response as? HTTPURLResponse {
                let status = response.statusCode
                if status != 200, let data = data {
                    let responseString = String(data: data, encoding: .utf8)
                    DirectLog.info("Nightscout error: \(response.statusCode) \(responseString)")
                }
            }
        }

        task.resume()
    }

    func deleteInsulinDelivery(nightscoutURL: String, apiSecret: String, id: String) {
        let session = URLSession.shared

        let urlString = "\(nightscoutURL)/api/v1/treatments?find[glucoseDirect]=\(id)"
        guard let url = URL(string: urlString) else {
            DirectLog.error("Nightscout, bad nightscout url")
            return
        }

        let request = createRequest(url: url, method: "DELETE", apiSecret: apiSecret)

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DirectLog.info("Nightscout error: \(error)")
                return
            }

            if let response = response as? HTTPURLResponse {
                let status = response.statusCode
                if status != 200, let data = data {
                    let responseString = String(data: data, encoding: .utf8)
                    DirectLog.info("Nightscout error: \(response.statusCode) \(responseString)")
                }
            }
        }

        task.resume()
    }

    func addBloodGlucose(nightscoutURL: String, apiSecret: String, glucoseValues: [BloodGlucose]) {
        let nightscoutValues = glucoseValues.map { glucose in
            glucose.toNightscoutGlucose()
        }.compactMap { $0 }

        guard let nightscoutJson = try? JSONSerialization.data(withJSONObject: nightscoutValues) else {
            return
        }

        let session = URLSession.shared

        let urlString = "\(nightscoutURL)/api/v1/entries"
        guard let url = URL(string: urlString) else {
            DirectLog.error("Nightscout, bad nightscout url")
            return
        }

        let request = createRequest(url: url, method: "POST", apiSecret: apiSecret)

        let task = session.uploadTask(with: request, from: nightscoutJson) { data, response, error in
            if let error = error {
                DirectLog.info("Nightscout error: \(error)")
                return
            }

            if let response = response as? HTTPURLResponse {
                if response.statusCode != 200, let data = data {
                    let responseString = String(data: data, encoding: .utf8)
                    DirectLog.info("Nightscout error: \(response.statusCode) \(responseString)")
                }
            }
        }

        task.resume()
    }

    func addSensorGlucose(nightscoutURL: String, apiSecret: String, glucoseValues: [SensorGlucose]) {
        let nightscoutValues = glucoseValues.map { glucose in
            glucose.toNightscoutGlucose()
        }.compactMap { $0 }

        guard let nightscoutJson = try? JSONSerialization.data(withJSONObject: nightscoutValues) else {
            return
        }

        let session = URLSession.shared

        let urlString = "\(nightscoutURL)/api/v1/entries"
        guard let url = URL(string: urlString) else {
            DirectLog.error("Nightscout, bad nightscout url")
            return
        }

        let request = createRequest(url: url, method: "POST", apiSecret: apiSecret)

        let task = session.uploadTask(with: request, from: nightscoutJson) { data, response, error in
            if let error = error {
                DirectLog.info("Nightscout error: \(error)")
                return
            }

            if let response = response as? HTTPURLResponse {
                if response.statusCode != 200, let data = data {
                    let responseString = String(data: data, encoding: .utf8)
                    DirectLog.info("Nightscout error: \(response.statusCode) \(responseString)")
                }
            }
        }

        task.resume()
    }

    func isSensorStarted(nightscoutURL: String, apiSecret: String, serial: String, completionHandler: @escaping (Bool?) -> Void) {
        let session = URLSession.shared

        let urlString = "\(nightscoutURL)/api/v1/treatments?find[_id][$in][]=\(serial)&find[eventType][$in][]=Sensor%20Start"
        guard let url = URL(string: urlString) else {
            DirectLog.error("Nightscout, bad nightscout url")

            completionHandler(nil)
            return
        }

        let request = createRequest(url: url, method: "GET", apiSecret: apiSecret)

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DirectLog.info("Nightscout error: \(error)")

                completionHandler(nil)
                return
            }

            if let response = response as? HTTPURLResponse, let data = data {
                let status = response.statusCode
                if status != 200 {
                    let responseString = String(data: data, encoding: .utf8)

                    DirectLog.info("Nightscout error: \(response.statusCode) \(responseString)")
                    completionHandler(nil)
                } else {
                    do {
                        let results = try JSONDecoder().decode([Treatment].self, from: data)
                        completionHandler(!results.isEmpty)
                    } catch {
                        DirectLog.info("Nightscout, json decode failed: \(error)")
                        completionHandler(nil)
                    }
                }
            } else {
                completionHandler(nil)
            }
        }

        task.resume()
    }

    func addInsulinDelivery(nightscoutURL: String, apiSecret: String, insulinDeliveryValues: [InsulinDelivery]) {
        let nightscoutValues = insulinDeliveryValues.map { insulinDelivery in
            insulinDelivery.toNightscoutInsulinDelivery()
        }.compactMap { $0 }

        guard let nightscoutJson = try? JSONSerialization.data(withJSONObject: nightscoutValues) else {
            return
        }

        let session = URLSession.shared

        let urlString = "\(nightscoutURL)/api/v1/treatments"
        guard let url = URL(string: urlString) else {
            DirectLog.error("Nightscout, bad nightscout url")
            return
        }

        let request = createRequest(url: url, method: "POST", apiSecret: apiSecret)

        let task = session.uploadTask(with: request, from: nightscoutJson) { data, response, error in
            if let error = error {
                DirectLog.info("Nightscout error: \(error)")
                return
            }

            if let response = response as? HTTPURLResponse {
                if response.statusCode != 200, let data = data {
                    let responseString = String(data: data, encoding: .utf8)
                    DirectLog.info("Nightscout error: \(response.statusCode) \(responseString)")
                }
            }
        }

        task.resume()
    }

    // MARK: Private

    private func createRequest(url: URL, method: String, apiSecret: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiSecret, forHTTPHeaderField: "api-secret")

        return request
    }
}

// MARK: - Treatment

private struct Treatment: Decodable {
    let _id: String
    let eventType: String
    let created_at: String
    let enteredBy: String
}

private extension Sensor {
    func toNightscoutSensorStart() -> [String: Any]? {
        guard let startTimestamp = startTimestamp else {
            return nil
        }

        guard let serial = serial else {
            return nil
        }

        let nightscout: [String: Any] = [
            "_id": serial,
            "eventType": "Sensor Start",
            "created_at": startTimestamp.toISOStringFromDate(),
            "enteredBy": DirectConfig.projectName,
        ]

        return nightscout
    }
}

private extension BloodGlucose {
    func toNightscoutGlucose() -> [String: Any]? {
        let nightscout: [String: Any] = [
            "_id": id.uuidString,
            "device": DirectConfig.projectName,
            "date": timestamp.toMillisecondsAsInt64(),
            "dateString": timestamp.toISOStringFromDate(),
            "type": "mbg",
            "mbg": glucoseValue,
            "glucoseDirect": id.uuidString,
        ]

        return nightscout
    }
}

private extension SensorGlucose {
    func toNightscoutGlucose() -> [String: Any]? {
        let nightscout: [String: Any] = [
            "_id": id.uuidString,
            "device": DirectConfig.projectName,
            "date": timestamp.toMillisecondsAsInt64(),
            "dateString": timestamp.toISOStringFromDate(),
            "type": "sgv",
            "sgv": glucoseValue,
            "rawbg": rawGlucoseValue,
            "direction": trend.toNightscoutDirection(),
            "trend": trend.toNightscoutTrend(),
            "glucoseDirect": id.uuidString,
        ]

        return nightscout
    }
}

private extension InsulinDelivery {
    func toNightscoutInsulinDelivery() -> [String: Any]? {
        let nightscout: [String: Any] = [
            "_id": id.uuidString,
            "enteredBy": DirectConfig.projectName,
            "created_at": starts.toISOStringFromDate(),
            "eventType": type.toNightscoutEventType(),
            "insulin": units,
            "glucoseDirect": id.uuidString,
        ]

        return nightscout
    }
}

private extension InsulinType {
    func toNightscoutEventType() -> String {
        switch self {
        case .mealBolus:
            return "Meal Bolus"
        case .correctionBolus:
            return "Correction Bolus"
        case .basal:
            return "Temp Basal"
        case .snackBolus:
            return "Snack Bolus"
        }
    }
}

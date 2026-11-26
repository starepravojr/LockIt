import Foundation

/// JSON-encoded models in the App Group's UserDefaults, shared with the extensions.
struct SharedStore {
    private enum Key {
        static let brickState = "brickState"
        static let modes = "modes"
        static let settings = "settings"
        static let sessionLogs = "sessionLogs"
        static let schedules = "schedules"
    }

    private let defaults: UserDefaults

    init(suiteName: String = AppConfig.appGroupID) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("App Group \(suiteName) is not available")
        }
        self.defaults = defaults
    }

    var brickState: BrickState {
        get { read(Key.brickState) ?? BrickState() }
        nonmutating set { write(newValue, for: Key.brickState) }
    }

    var modes: [BrickMode] {
        get { read(Key.modes) ?? [] }
        nonmutating set { write(newValue, for: Key.modes) }
    }

    var settings: AppSettings {
        get { read(Key.settings) ?? AppSettings() }
        nonmutating set { write(newValue, for: Key.settings) }
    }

    var sessionLogs: [SessionLog] {
        get { read(Key.sessionLogs) ?? [] }
        nonmutating set { write(newValue, for: Key.sessionLogs) }
    }

    var schedules: [BrickSchedule] {
        get { read(Key.schedules) ?? [] }
        nonmutating set { write(newValue, for: Key.schedules) }
    }

    private func read<Value: Decodable>(_ key: String) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    private func write<Value: Encodable>(_ value: Value, for key: String) {
        do {
            defaults.set(try JSONEncoder().encode(value), forKey: key)
        } catch {
            assertionFailure("Could not encode \(key): \(error)")
        }
    }
}

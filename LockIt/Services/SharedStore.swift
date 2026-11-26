import Foundation

/// JSON-encoded models in the App Group's UserDefaults, shared with the extensions.
struct SharedStore {
    /// These are the names the data is stored under on the device. Some predate
    /// the Brick to Lock rename; changing one would orphan what is saved there.
    private enum Key {
        static let lockState = "brickState"
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

    var lockState: LockState {
        get { read(Key.lockState) ?? LockState() }
        nonmutating set { write(newValue, for: Key.lockState) }
    }

    var modes: [LockMode] {
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

    var schedules: [LockSchedule] {
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

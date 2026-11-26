import Foundation

/// Tells the app that the lock state in the App Group changed, including
/// when the monitor extension changed it from another process.
enum StateChangeSignal {
    /// Posted on `NotificationCenter.default` in the app after `startObserving()`.
    static let didChange = Notification.Name("LockItStateDidChange")

    private static var darwinName: CFNotificationName {
        CFNotificationName(AppConfig.stateChangeNotification as CFString)
    }

    static func post() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(), darwinName, nil, nil, true
        )
    }

    /// Call once at app launch.
    static func startObserving() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                NotificationCenter.default.post(name: StateChangeSignal.didChange, object: nil)
            },
            darwinName.rawValue,
            nil,
            .deliverImmediately
        )
    }
}

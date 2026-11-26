import Combine
import FamilyControls
import Foundation
import Observation

/// Screen Time (Family Controls) authorization and its live status.
@MainActor
@Observable
final class AuthorizationService {
    /// One instance for the whole app process.
    static let shared = AuthorizationService()

    private(set) var status: AuthorizationStatus

    @ObservationIgnored private let center = AuthorizationCenter.shared
    @ObservationIgnored private var statusObserver: AnyCancellable?

    init() {
        status = center.authorizationStatus
        statusObserver = center.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.status = status
            }
    }

    var isApproved: Bool {
        if #available(iOS 26.4, *), status == .approvedWithDataAccess { return true }
        return status == .approved
    }

    /// Shows the system prompt. Throws `FamilyControlsError` when the user
    /// declines or the device cannot grant access.
    func request() async throws {
        defer { refresh() }
        try await center.requestAuthorization(for: .individual)
    }

    func refresh() {
        status = center.authorizationStatus
    }

    /// Whether access is approved, allowing a moment for the status to load.
    /// It can read as not approved just after the app is launched in the
    /// background, which is how a Shortcuts action usually finds it.
    func waitUntilApproved(timeout: Duration = .seconds(2)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while true {
            refresh()
            if isApproved { return true }
            if ContinuousClock.now >= deadline { return false }
            try? await Task.sleep(for: .milliseconds(150))
        }
    }
}

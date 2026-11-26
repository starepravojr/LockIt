import Combine
import FamilyControls
import Foundation
import Observation

/// Screen Time (Family Controls) authorization and its live status.
@MainActor
@Observable
final class AuthorizationService {
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
}

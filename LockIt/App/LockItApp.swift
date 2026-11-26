import SwiftUI

@main
struct LockItApp: App {
    @State private var model = AppModel.shared
    @State private var authorization = AuthorizationService.shared

    init() {
        StateChangeSignal.startObserving()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(authorization)
        }
    }
}

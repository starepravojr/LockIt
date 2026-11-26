import SwiftUI

@main
struct LockItApp: App {
    @State private var model = AppModel()
    @State private var authorization = AuthorizationService()

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

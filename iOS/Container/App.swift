import KeyboardPreferences
import SwiftUI

@main
struct KeigoButtonApp: App {
    @StateObject private var session = UserSession()

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environmentObject(session)
                .task { await session.bootstrap() }
                .onAppear {
                    KeyboardSettingsStore.writeCloudAIEnabled(true)
                }
        }
    }
}

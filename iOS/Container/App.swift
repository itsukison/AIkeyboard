import KeyboardPreferences
import PostHog
import SwiftUI

enum PostHogEnv: String {
    case projectToken = "POSTHOG_PROJECT_TOKEN"
    case host = "POSTHOG_HOST"

    var value: String {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: rawValue) as? String,
            !value.isEmpty
        else {
            fatalError("Set \(rawValue) in Config/Local.xcconfig (copied from Local.example.xcconfig).")
        }
        return value
    }
}

@main
struct KeigoButtonApp: App {
    @StateObject private var session = UserSession()

    init() {
        let config = PostHogConfig(apiKey: PostHogEnv.projectToken.value, host: PostHogEnv.host.value)
        config.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(config)
    }

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

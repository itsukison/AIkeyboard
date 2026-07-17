import FirebaseCore
import KeyboardKit
import KeyboardPreferences
import PostHog
import SwiftUI
import UIKit

enum AppThemePreference: String, CaseIterable, Identifiable {
    case auto, light, dark

    static let storageKey = "aikJP.themePreference"

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .auto: return "自動"
        case .light: return "ライト"
        case .dark: return "ダーク"
        }
    }

    var iconName: String {
        switch self {
        case .auto: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}

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

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        AppAnalytics.cacheAppInstanceId()
        return true
    }
}

@main
struct KeigoButtonApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = UserSession()
    @Environment(\.scenePhase) private var scenePhase

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
                    AppAnalytics.cacheAppInstanceId()
                    flushKeyboardUsageDays()
                    reportZenzaiAutoDisableIfPending()
                    reportKeyboardEnabledIfNeeded()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        reportKeyboardEnabledIfNeeded()
                    }
                }
        }
    }

    /// Forwards the keyboard extension's completed daily usage tallies to
    /// analytics. The extension can't emit analytics itself (memory ceiling +
    /// no network in the typing path), so the container drains the App Group
    /// counters on launch. Group by the `date` property for DAU / time-in-app.
    private func flushKeyboardUsageDays() {
        for day in KeyboardUsageDailyStore.flushCompletedDays() {
            AppAnalytics.capture("keyboard_usage_day", properties: [
                "date": day.date,
                "opens": day.opens,
                "active_seconds": day.activeSeconds,
                "typed": day.typed,
            ])
        }
    }

    /// One-shot funnel event for the install → enabled-keyboard → typed
    /// activation funnel. Fired the first time the container sees the keyboard
    /// in the system list (checked on launch and on every return from
    /// Settings), since enabling happens outside the app and is otherwise
    /// invisible to analytics.
    private func reportKeyboardEnabledIfNeeded() {
        let reportedKey = "analytics.keyboardEnabledReported"
        guard !UserDefaults.standard.bool(forKey: reportedKey) else { return }
        let status = KeyboardStatusContext(bundleId: "com.core7.keigobutton.keyboard")
        guard status.isKeyboardEnabled else { return }
        AppAnalytics.capture("keyboard_enabled", properties: [
            "full_access": status.isFullAccessEnabled,
        ])
        UserDefaults.standard.set(true, forKey: reportedKey)
    }

    /// One-shot report that the Zenzai latency gate disabled neural
    /// conversion on this device (the SDK attaches the device model). Same
    /// bridge as usage days: the extension only sets an App Group flag, the
    /// container does the network.
    private func reportZenzaiAutoDisableIfPending() {
        if KeyboardSettingsStore.takeZenzaiAutoDisablePendingReport() {
            AppAnalytics.capture("zenzai_auto_disabled")
        }
    }
}

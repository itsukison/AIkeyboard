import CryptoKit
import Foundation
import KeyboardPreferences

/// Randomises the onboarding button builder so it doubles as the test of
/// whether authoring a button *causes* sustained use or merely marks a
/// high-intent user. Observational data cannot separate those, and every other
/// roadmap item downstream depends on the answer.
///
/// Assignment is a local hash of the anonymous device id rather than a remote
/// feature flag. The decision is needed in the first seconds of a first launch,
/// before sign-in and before any flag fetch could reliably have completed —
/// a flag that has not loaded yet evaluates to "off", which would quietly push
/// slow-network users into control and bias the very comparison the experiment
/// exists to make. The cost is that there is no remote kill switch: disabling
/// the builder needs a release.
enum OnboardingExperiment {
    enum BuilderArm: String {
        case control
        case builder
    }

    private static let armKey = "aikJP.onboardingBuilderArm"
    private static let exposureLoggedKey = "aikJP.onboardingBuilderArmLogged"

    #if DEBUG
    /// Forces an arm in debug builds. Set it in the Xcode scheme under
    /// Run → Arguments → "Arguments Passed On Launch":
    ///
    ///     -aikJP.onboardingBuilderArmOverride builder
    ///
    /// The argument domain outranks the persisted value, so the builder can be
    /// exercised without reinstalling until a 50/50 coin lands the right way.
    /// Nothing is written, so removing the argument restores the real arm.
    static let armOverrideKey = "aikJP.onboardingBuilderArmOverride"
    #endif

    /// Stable for the lifetime of the install. Persisted on first read so the
    /// arm can never flip, even if the anonymous device id is regenerated.
    static func builderArm(defaults: UserDefaults = .standard) -> BuilderArm {
        #if DEBUG
        if let override = defaults.string(forKey: armOverrideKey),
           let arm = BuilderArm(rawValue: override) {
            return arm
        }
        #endif
        if let stored = defaults.string(forKey: armKey),
           let arm = BuilderArm(rawValue: stored) {
            return arm
        }
        let arm = assign(deviceId: KeyboardSettingsStore.anonymousDeviceId())
        defaults.set(arm.rawValue, forKey: armKey)
        return arm
    }

    /// Salted so this split is independent of any other experiment keyed on the
    /// same device id.
    static func assign(deviceId: String) -> BuilderArm {
        let digest = SHA256.hash(data: Data("onboarding_builder:\(deviceId)".utf8))
        let firstByte = digest.withUnsafeBytes { $0.load(as: UInt8.self) }
        return firstByte % 2 == 0 ? .control : .builder
    }

    /// The exposure event the analysis anchors on. Fired once, when onboarding
    /// starts — not when the builder is reached, which would only ever log the
    /// treatment arm and leave the comparison with no control group.
    static func logExposureIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: exposureLoggedKey) else { return }
        defaults.set(true, forKey: exposureLoggedKey)
        let arm = builderArm(defaults: defaults).rawValue
        AppAnalytics.capture("onboarding_builder_assigned", properties: [
            "arm": arm,
            "onboarding_version": InteractiveOnboardingState.version,
            // Sets it on the person too, so the arm can be used to segment
            // events that carry no properties of their own.
            "$set": ["builder_arm": arm],
        ])
    }
}

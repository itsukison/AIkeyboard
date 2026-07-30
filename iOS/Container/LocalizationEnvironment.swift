import SwiftUI

/// User-selected UI language for the container app. `.system` follows the device
/// language; the others override it. Container-only — the keyboard extension is
/// not localized, so this lives in standard `UserDefaults` (not the App Group).
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case ja
    case en
    case zhHans

    static let storageKey = "aikJP.languagePreference"

    var id: String { rawValue }

    /// `nil` means "follow the device language" (no override).
    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .ja: return "ja"
        case .en: return "en"
        case .zhHans: return "zh-Hans"
        }
    }

    /// Row label for the picker. Language names are shown in their own script
    /// regardless of UI language (iOS convention); only the system row localizes.
    var pickerLabel: Text {
        switch self {
        case .system: return Text("端末の設定に従う")
        case .ja: return Text(verbatim: "日本語")
        case .en: return Text(verbatim: "English")
        case .zhHans: return Text(verbatim: "简体中文")
        }
    }

    var locale: Locale {
        localeIdentifier.map(Locale.init(identifier:)) ?? .current
    }
}

/// Resolves a localized string honoring the in-app language override. `Text`
/// picks the override up from `\.locale`, but plain `String(localized:)` reads
/// the device language — wrong for users who switch language in ProfileScreen
/// (e.g. Chinese users on Japanese devices). Use this for any user-facing
/// string built outside a `Text` literal.
func localizedAppString(_ keyAndValue: String.LocalizationValue) -> String {
    let preference = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        .flatMap(AppLanguage.init(rawValue:)) ?? .system
    if let identifier = preference.localeIdentifier,
       let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return String(localized: keyAndValue, bundle: bundle)
    }
    return String(localized: keyAndValue)
}

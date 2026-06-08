import Foundation

public enum AppGroup {
    public static let identifier = "group.com.core7.keigobutton"

    public static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    public static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}

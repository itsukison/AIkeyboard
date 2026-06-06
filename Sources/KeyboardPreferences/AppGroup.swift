import Foundation

public enum AppGroup {
    public static let identifier = "group.co.gastroduce-japan.bikey.japanese"

    public static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    public static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}

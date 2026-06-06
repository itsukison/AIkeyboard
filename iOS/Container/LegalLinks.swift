import Foundation

enum LegalLinks {
    static let privacy = URL(string: "https://bikey-five.vercel.app/privacy")!
    static let terms = URL(string: "https://bikey-five.vercel.app/terms")!
    static let support = URL(string: "https://bikey-five.vercel.app/support")!
    static let contactEmail = "itsukison00@gmail.com"
    static var contactMailto: URL { URL(string: "mailto:\(contactEmail)")! }
}

import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://eercsucvxnszqletxued.supabase.co")!
    static let authURL = URL(string: "https://auth.keigobutton.com")!
    static let oauthRedirectURL = URL(string: "keigobutton://auth-callback")!
    static let publishableKey = "sb_publishable_S8rEoVqCOV8iVGfDEErI6w_Slb79nCO"

    // Only the browser-visible auth leg uses the branded host. Data APIs stay
    // on the project URL configured on `supabase` below.
    static func brandedAuthURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.scheme = authURL.scheme
        components.host = authURL.host
        components.port = authURL.port
        return components.url ?? url
    }
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.publishableKey
)

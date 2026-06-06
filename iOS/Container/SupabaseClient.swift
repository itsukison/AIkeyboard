import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://eercsucvxnszqletxued.supabase.co")!
    static let publishableKey = "sb_publishable_S8rEoVqCOV8iVGfDEErI6w_Slb79nCO"
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.publishableKey
)

import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    let client: SupabaseClient

    private init() {
        let supabaseURLString = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String ?? ""
        let supabaseAnonKey = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String ?? ""
        
        let url = URL(string: supabaseURLString) ?? URL(string: "https://example.supabase.co")!
        
        let options = SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                emitLocalSessionAsInitialSession: true
            )
        )
        
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: supabaseAnonKey, options: options)
    }
}

import Supabase
import Foundation

let url = URL(string: "http://example.com")!
let client = SupabaseClient(
    supabaseURL: url,
    supabaseKey: "anon",
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.Auth(
            emitLocalSessionAsInitialSession: true
        )
    )
)

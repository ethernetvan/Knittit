package com.edanthom.knittit

import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.postgrest.Postgrest

object Supabase {
    // TODO: Replace with your actual Supabase URL and Anon Key
    const val SUPABASE_URL = "https://nidglxalnqgqibssjmol.supabase.co"
    const val SUPABASE_KEY = "sb_publishable_WHauEzUFRqivBDGCFH42Qw_q-fvSwrB"

    val client = createSupabaseClient(
        supabaseUrl = SUPABASE_URL,
        supabaseKey = SUPABASE_KEY
    ) {
        install(Postgrest)
        install(Auth)
    }
}
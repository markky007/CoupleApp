import Foundation
import Supabase

/// Configuration for Supabase client
/// Centralizes all Supabase-related configuration in one place
enum SupabaseConfig {
    /// Supabase project URL
    /// For local development: http://127.0.0.1:54321
    /// For production: Replace with your Supabase project URL
    static let url = URL(string: "http://127.0.0.1:54321")!

    /// Supabase anonymous key (public key)
    /// This key is safe to use in client applications
    /// Security is enforced through Row Level Security (RLS) policies
    static let anonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
}

/// Global Supabase client instance
/// Shared across the entire application for consistency
let supabase: SupabaseClient = {
    // Configure JSON decoder with ISO8601 date strategy
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    // Configure JSON encoder with ISO8601 date strategy
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    return SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey,
        options: SupabaseClientOptions(
            db: SupabaseClientOptions.DatabaseOptions(
                encoder: encoder,
                decoder: decoder
            )
        )
    )
}()

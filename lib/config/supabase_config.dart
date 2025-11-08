/// Supabase Configuration Constants
/// 
/// This file contains all Supabase credentials and configuration.
/// IMPORTANT: In production, use environment variables or secure storage instead of hardcoding.
library;

class SupabaseConfig {
  /// Supabase Project URL
  static const String supabaseUrl = "https://dhjbeonohnigxrndqpuj.supabase.co";

  /// Supabase Anonymous Key (Public Key)
  /// This key is safe to expose in client-side code
  static const String supabaseAnonKey =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRoamJlb25vaG5pZ3hybmRxcHVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgzNDE1NDksImV4cCI6MjA3MzkxNzU0OX0.60571MXNEznaluhHBU7WPQZOV8YTmbFhCl2iGrpchH8";

  /// Storage Bucket Name for Events
  static const String storageBucket = "events";

  /// REST API Base URL
  static String get restApiUrl => "$supabaseUrl/rest/v1";

  /// RPC Base URL (RPC functions are called via REST API)
  static String get rpcUrl => "$supabaseUrl/rest/v1/rpc";
}


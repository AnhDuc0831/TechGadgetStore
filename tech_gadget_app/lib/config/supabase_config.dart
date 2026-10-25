class SupabaseConfig {
  // Thay thế bằng thông tin Project của bạn từ Supabase Dashboard:
  // Settings -> API -> Project URL & Project API Keys (anon public)
  static const String supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // Backend .NET 8 API Base URL
  // Android Emulator: 'http://10.0.2.2:5203'
  // Windows / Web (Chrome): 'http://localhost:5203'
  // Thiết bị thật qua mạng LAN: 'http://192.168.x.x:5203'
  static const String apiBaseUrl = 'http://localhost:5203';
}

import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  static String get supabaseUrl => dotenv.isInitialized
      ? (dotenv.env['SUPABASE_URL'] ?? 'https://your-project-id.supabase.co')
      : 'https://your-project-id.supabase.co';

  static String get supabaseAnonKey => dotenv.isInitialized
      ? (dotenv.env['SUPABASE_ANON_KEY'] ?? 'your-cloud-anon-key')
      : 'your-cloud-anon-key';

  static String get onesignalAppId =>
      dotenv.isInitialized ? (dotenv.env['ONESIGNAL_APP_ID'] ?? '') : '';
}

import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static final ConfigService instance = ConfigService._();
  static const String _keyRecipientEmail = 'config_recipient_email';
  static const String _defaultEmail = 'orders@example.com';

  ConfigService._();

  Future<String> getRecipientEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRecipientEmail) ?? _defaultEmail;
  }

  Future<void> setRecipientEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRecipientEmail, email);
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyBaseUrl = 'api_base_url';

/// Production backend on Railway. Only this URL is used unless overridden in Settings.
const String kBaseUrlProduction =
    'https://speech-data-production.up.railway.app';

/// Resolved base URL (set after [initApiConfig]). Defaults to production.
String kBaseUrl = kBaseUrlProduction;

/// True if [url] looks like a local/dev URL (not production).
bool _isLocalUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('http://192.168.') ||
      u.startsWith('http://10.') ||
      u.startsWith('http://localhost') ||
      u.startsWith('http://127.0.0.1');
}

/// Call before runApp() so the app uses the correct backend URL.
/// Uses: 1) URL saved in Settings (if set and not local), 2) Production only.
Future<void> initApiConfig() async {
  final prefs = await SharedPreferences.getInstance();

  final saved = prefs.getString(_keyBaseUrl);
  if (saved != null && saved.trim().isNotEmpty && !_isLocalUrl(saved)) {
    kBaseUrl = saved.trim();
    if (kDebugMode) {
      debugPrint('[SpeechAPI] Using saved base URL: $kBaseUrl');
    }
    return;
  }

  // Clear any saved local URL so we never use it again
  if (saved != null && _isLocalUrl(saved)) {
    await prefs.remove(_keyBaseUrl);
  }

  kBaseUrl = kBaseUrlProduction;
  if (kDebugMode) {
    debugPrint('[SpeechAPI] Using production base URL: $kBaseUrl');
  }
}

/// Save server URL from in-app Settings. Restart app or call [initApiConfig] again to apply.
Future<void> setSavedBaseUrl(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyBaseUrl, trimmed);
  kBaseUrl = trimmed;
}

/// Currently saved URL (for Settings screen). Null if none saved.
Future<String?> getSavedBaseUrl() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_keyBaseUrl);
}

/// Clear saved URL and revert to production on next launch.
Future<void> clearSavedBaseUrl() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keyBaseUrl);
}

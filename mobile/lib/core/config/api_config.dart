import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyBaseUrl = 'api_base_url';

const String kBaseUrlEmulator = 'http://10.0.2.2:8000';
const String kBaseUrlRealDevice = 'http://192.168.1.1:8000';

/// Resolved base URL (set after [initApiConfig]).
String kBaseUrl = kBaseUrlEmulator;

/// Call before runApp() so the app uses the correct backend URL.
/// Order: 1) Saved URL in app, 2) --dart-define=BASE_URL=..., 3) Emulator vs device, 4) Default.
Future<void> initApiConfig() async {
  final prefs = await SharedPreferences.getInstance();

  // 1) URL saved in app (Settings → Server URL)
  final saved = prefs.getString(_keyBaseUrl);
  if (saved != null && saved.trim().isNotEmpty) {
    kBaseUrl = saved.trim();
    if (kDebugMode) {
      debugPrint('[SpeechAPI] Using saved base URL: $kBaseUrl');
    }
    return;
  }

  // 2) Passed at run: flutter run --dart-define=BASE_URL=http://192.168.1.5:8000
  const fromEnv = String.fromEnvironment(
    'BASE_URL',
    defaultValue: '',
  );
  if (fromEnv.isNotEmpty) {
    kBaseUrl = fromEnv;
    if (kDebugMode) {
      debugPrint('[SpeechAPI] Using BASE_URL from dart-define: $kBaseUrl');
    }
    return;
  }

  // 3) Auto-detect: emulator → 10.0.2.2, real device → kBaseUrlRealDevice
  if (Platform.isAndroid) {
    final deviceInfo = DeviceInfoPlugin();
    final android = await deviceInfo.androidInfo;
    final isEmulator = !android.isPhysicalDevice;
    kBaseUrl = isEmulator ? kBaseUrlEmulator : kBaseUrlRealDevice;
    if (kDebugMode) {
      debugPrint('[SpeechAPI] Android ${isEmulator ? "emulator" : "device"}: $kBaseUrl');
    }
    return;
  }

  // 4) iOS / other: default emulator URL (or use dart-define / in-app URL)
  kBaseUrl = kBaseUrlEmulator;
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

/// Clear saved URL and revert to auto/dart-define logic on next launch.
Future<void> clearSavedBaseUrl() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keyBaseUrl);
}

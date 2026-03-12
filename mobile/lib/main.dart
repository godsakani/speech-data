import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/theme/app_theme.dart';
import 'core/config/api_config.dart';
import 'presentation/splash/splash_screen.dart';
import 'bindings/initial_binding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initApiConfig();
  runApp(const SpeechParallelApp());
}

class SpeechParallelApp extends StatelessWidget {
  const SpeechParallelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Speech Parallel Data',
      debugShowCheckedModeBanner: false,
      initialBinding: InitialBinding(),
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}

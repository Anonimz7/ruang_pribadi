import 'package:flutter/material.dart';
import 'screens/main_page.dart';

// Export providers jika perlu diakses dari main.dart
export 'providers/settings_provider.dart';
export 'providers/quiz_provider.dart';
export 'providers/record_provider.dart';

class MathApp extends StatelessWidget {
  const MathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: MainPage(),
    );
  }
}

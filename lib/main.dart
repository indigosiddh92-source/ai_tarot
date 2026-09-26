import 'package:flutter/material.dart';

import 'config/app_theme.dart';
import 'screens/home_screen.dart';

void main() => runApp(const AiTarotApp());

class AiTarotApp extends StatelessWidget {
  const AiTarotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Tarot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}

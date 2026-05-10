import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/pin_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FamilyGarmentApp());
}

class FamilyGarmentApp extends StatelessWidget {
  const FamilyGarmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Garment',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const PinScreen(),
    );
  }
}
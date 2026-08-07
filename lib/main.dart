import 'package:flutter/material.dart';
import 'core/di/service_locator.dart';
import 'core/navigation/update_gate.dart';
import 'shared/theme/app_theme.dart';
import 'features/canvas/presentation/screens/canvas_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(
    UpdateGate(
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LogicPad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system, // Cambia automáticamente según el tema del sistema
      home: const CanvasScreen(),
    );
  }
}

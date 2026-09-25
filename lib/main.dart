import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 가로 모드 (Landscape) 고정 지원
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const LoreApp());
}

class LoreApp extends StatelessWidget {
  const LoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '또 다른 지식의 성전 (1993)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const MainGameScreen(),
    );
  }
}

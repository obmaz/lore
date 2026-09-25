import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/party_member.dart';
import 'screens/character_creation_screen.dart';
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

class LoreApp extends StatefulWidget {
  const LoreApp({super.key});

  @override
  State<LoreApp> createState() => _LoreAppState();
}

class _LoreAppState extends State<LoreApp> {
  List<PartyMember>? _party;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '또 다른 지식의 성전 (1993)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      // 파티가 결성되지 않았으면 원작 오프닝 및 캐릭터 생성 모드로 시작,
      // 생성이 완료되면 5인 파티를 들고 메인 게임 화면으로 진입!
      home: _party == null
          ? CharacterCreationScreen(
              onGameStart: (party) {
                setState(() => _party = party);
              },
            )
          : MainGameScreen(initialParty: _party),
    );
  }
}

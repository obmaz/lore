import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/lore_data.dart';
import 'data/lore_script.dart';
import 'models/party_member.dart';
import 'services/save_manager.dart';
import 'game/lore_world_manager.dart';
import 'game/sprite_sheet.dart';
import 'screens/character_creation_screen.dart';
import 'screens/main_game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Follow the device orientation so the mobile layout can use portrait space.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

  // 원작 데이터(몬스터/아이템/마법/맵)를 JSON에서 로드한다.
  // 실패하면 코드 내장 테이블로 자동 폴백하므로 게임은 항상 동작한다.
  await LoreData.instance.load();
  // 좌표 이벤트/NPC 대화 스크립트(assets/data/scripts.json)도 함께 로드한다.
  await LoreScriptEngine.instance.load();
  // 이미지 파일(PNG) 스프라이트 시트를 로드한다. 없으면 FNT 디코더로 폴백한다.
  await SpriteLibrary.instance.load();
  // 맵 연결(포털)과 표지판 규칙도 JSON에서 로드한다.
  await LoreWorldManager.instance.loadData();

  runApp(const LoreApp());
}

class LoreApp extends StatefulWidget {
  const LoreApp({super.key});

  @override
  State<LoreApp> createState() => _LoreAppState();
}

class _LoreAppState extends State<LoreApp> {
  List<PartyMember>? _party;
  SaveData? _initialSaveData;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '또 다른 지식의 성전 (1993)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      // 파티가 결성되지 않았고 세이브 로드가 없으면 캐릭터 생성 화면으로 시작,
      // 생성 완료 또는 세이브 로드 시 메인 게임 화면으로 진입!
      home: _party == null && _initialSaveData == null
          ? CharacterCreationScreen(
              onGameStart: (party) {
                // LORECRET.PAS `Last` writes the new party to all four slots
                // before the game starts; storage errors do not stop the game.
                unawaited(
                  SaveManager.instance
                      .writeNewGame(
                        party,
                        mapTitle: LoreWorldManager.mapRegistry[6]?.title ?? '',
                      )
                      .then((_) {}, onError: (Object _) {}),
                );
                setState(() => _party = party);
              },
              onLoadGame: (saveData) {
                setState(() {
                  _initialSaveData = saveData;
                  _party = saveData.party;
                });
              },
            )
          : MainGameScreen(
              initialParty: _party,
              initialSaveData: _initialSaveData,
            ),
    );
  }
}

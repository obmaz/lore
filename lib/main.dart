import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/lore_data.dart';
import 'models/party_member.dart';
import 'services/save_manager.dart';
import 'services/graphics_settings.dart';
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
  // 이미지 파일(PNG) 스프라이트 시트를 로드한다. 없으면 FNT 디코더로 폴백한다.
  await SpriteLibrary.instance.load();
  await GraphicsSettings.instance.restore();
  // 포털·시설·표지판은 원본 Dart 절차에서 선택한다.
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
  bool _creating = false;
  Object? _creationError;

  Future<void> _startNewGame(List<PartyMember> party) async {
    if (_creating || _creationError != null) return;
    setState(() => _creating = true);
    try {
      // LORECRET.Last completes all four writes before Set_All/gameplay.
      await SaveManager.instance.writeNewGame(
        party,
        mapTitle: LoreWorldManager.mapRegistry[6]?.title ?? '',
      );
      if (!mounted) return;
      setState(() {
        _party = party;
        _creating = false;
      });
    } catch (error) {
      if (!mounted) return;
      // Storage is a modern adapter; failure must not silently start play.
      setState(() {
        _creationError = error;
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '또 다른 지식의 성전 (1993)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      // 파티가 결성되지 않았고 세이브 로드가 없으면 캐릭터 생성 화면으로 시작,
      // 생성 완료 또는 세이브 로드 시 메인 게임 화면으로 진입!
      home: _party == null && _initialSaveData == null
          ? Stack(
              children: [
                ExcludeFocus(
                  excluding: _creating || _creationError != null,
                  child: IgnorePointer(
                    ignoring: _creating || _creationError != null,
                    child: CharacterCreationScreen(
                      onGameStart: _startNewGame,
                      onLoadGame: (saveData) {
                        setState(() {
                          _initialSaveData = saveData;
                          _party = saveData.party;
                        });
                      },
                    ),
                  ),
                ),
                if (_creating || _creationError != null)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: _creationError != null
                            ? const Text(
                                '새 게임 저장 실패. 앱을 다시 시작해 주세요.',
                                key: ValueKey('creation-storage-error'),
                              )
                            : const CircularProgressIndicator(
                                key: ValueKey('creation-saving'),
                              ),
                      ),
                    ),
                  ),
              ],
            )
          : MainGameScreen(
              initialParty: _party,
              initialSaveData: _initialSaveData,
            ),
    );
  }
}

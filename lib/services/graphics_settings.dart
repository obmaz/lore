import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/sprite_sheet.dart';

/// App presentation preferences, separate from SaveData and party.etc.
class GraphicsSettings extends ChangeNotifier {
  GraphicsSettings();
  static final GraphicsSettings instance = GraphicsSettings();
  static const preferenceKey = 'lore_graphics_skin';

  GraphicsSkin get skin => SpriteLibrary.instance.activeSkin;
  bool busy = false;
  String? error;

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(preferenceKey);
      final skin = GraphicsSkin.values
          .where((skin) => skin.id == id)
          .firstOrNull;
      if (skin != null) await SpriteLibrary.instance.activate(skin);
    } catch (_) {
      // Unavailable storage never prevents the game from starting.
    }
  }

  Future<void> select(GraphicsSkin next) async {
    if (busy || next == skin) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await SpriteLibrary.instance.activate(next);
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(preferenceKey, next.id)) {
          throw StateError('preference write failed');
        }
      } catch (_) {
        error = '그래픽이 변경되었습니다. 설정을 저장하지 못해 다음 실행에는 초기화될 수 있습니다.';
      }
    } catch (_) {
      error = '그래픽을 불러오지 못했습니다. 현재 스킨이 유지됩니다. 다시 시도해 주세요.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

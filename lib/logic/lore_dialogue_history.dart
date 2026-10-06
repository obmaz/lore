/// 지나간 NPC 대사: 한 번의 대화(원작의 `Print` 줄들과 `Talk`/`PressAnyKey`)를
/// 줄 그대로 한 덩어리로 보관한다. 원작은 키를 누르면 창을 지우고 다시 볼 수
/// 없으므로, 이것은 화면 어댑터(이전 대화 탭)이다. 이번 접속 동안만 기억한다.
library;

import 'package:flutter/foundation.dart';

class LoreDialogueHistory extends ChangeNotifier {
  /// 보관하는 대화 수의 상한(오래된 것부터 버린다).
  static const int maxBlocks = 200;

  final List<List<String>> _blocks = [];
  final List<List<(int, String)>> _coloredBlocks = [];

  List<List<(int, String)>> get coloredBlocks =>
      List.unmodifiable(_coloredBlocks);

  /// 오래된 것부터 최신 순서의 대화들.
  List<List<String>> get blocks => List.unmodifiable(_blocks);

  /// 한 번의 대화를 추가한다. 줄은 바꾸지 않고 그대로 둔다.
  void add(List<String> lines) =>
      addColored([for (final text in lines) (7, text)]);

  void addColored(List<(int, String)> colored) {
    if (colored.isEmpty) return;
    final lines = [for (final (_, text) in colored) text];
    _coloredBlocks.add(List.unmodifiable(colored));
    _blocks.add(List.unmodifiable(lines));
    if (_blocks.length > maxBlocks) {
      _coloredBlocks.removeRange(0, _blocks.length - maxBlocks);
      _blocks.removeRange(0, _blocks.length - maxBlocks);
    }
    notifyListeners();
  }

  void clear() {
    _blocks.clear();
    _coloredBlocks.clear();
    notifyListeners();
  }
}

import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_talk_mode.dart';

class TalkModeIo implements LoreTalkModeIo {
  final lines = <(int, String)>[];
  final pages = <List<(int, String)>>[];
  final tiles = <(int, int, int)>[];
  final messages = <String>[];
  final recruits = <String>[];
  bool open = true;
  int choice = 1;
  String key = 'Y';
  void Function()? beforeWait;
  void Function()? afterWait;
  int refreshes = 0;
  @override
  bool get isOpen => open;
  @override
  void clear() => lines.clear();
  @override
  void print(int color, String text) => lines.add((color, text));
  @override
  void cprint(
    int color,
    int highlight,
    String before,
    String word,
    String after,
  ) => print(color, before + word + after);
  @override
  void message(int color, String text) {
    clear();
    messages.add(text);
  }

  @override
  void setTile(int x, int y, int tile) => tiles.add((x, y, tile));
  @override
  void refresh() => refreshes++;
  @override
  Future<void> recruit(LoreScript procedure) async =>
      recruits.add(procedure.id);
  @override
  Future<String> challengeKey() async => key;
  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    required bool clean,
  }) async {
    pages.add(List.of(lines));
    clear();
    return choice;
  }

  @override
  Future<void> pressAnyKey() async {
    pages.add(List.of(lines));
    beforeWait?.call();
    clear();
    afterWait?.call();
  }

  String get text => pages.expand((p) => p).map((l) => l.$2).join('\n');
}

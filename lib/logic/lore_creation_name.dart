/// LORECRET.PAS Name byte-key state; mobile/IME editing is a separate adapter.
class LoreCreationName {
  LoreCreationName({this.text = '', int? counter})
    : counter = counter ?? text.length;
  String text;
  int counter;
  bool nameAccepted = false;
  int? sex;

  /// One ReadKey; zero also consumes a scan byte, then discards it.
  void readKey(int key, {int scan = 0}) {
    if (sex != null) return;
    key &= 255;
    if (nameAccepted) {
      if (key >= 97 && key <= 122) key -= 32; // Pascal UpCase
      if (key == 77 || key == 70) sex = key == 70 ? 1 : 0;
      return;
    }
    counter++;
    if (key == 0 || key == 8) {
      key = 0;
      counter--;
    }
    if (key != 13 && key != 27 && key != 0) {
      text += String.fromCharCode(key);
    }
    if (key == 27 || counter > 16) {
      counter = 0;
      text = '';
    }
    if (key == 13 && text.isEmpty) {
      key = 0;
      counter = 0;
    }
    nameAccepted = key == 13;
  }
}

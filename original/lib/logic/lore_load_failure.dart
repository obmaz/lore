/// LORESUB.Load.ErrorMessage: source file label, optional creation hint, Halt.
/// File names supplied by Load are ASCII short strings; rendering is modern.
class LoreLoadFailure implements Exception {
  const LoreLoadFailure(this.fileName, {this.needCreate = false, this.cause});
  final String fileName;
  final bool needCreate;
  final Object? cause;

  List<String> get lines => [
    '"$fileName" not found.',
    if (needCreate) 'You need to CREATE CHARACTER.',
  ];

  @override
  String toString() => lines.join('\n');
}

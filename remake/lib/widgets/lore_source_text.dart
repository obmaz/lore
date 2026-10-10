import 'package:flutter/material.dart';

import '../data/dialogue_spacing.dart';
import '../logic/lore_source_speech.dart';
import '../logic/lore_view_procedures.dart';
import '../theme/retro_theme.dart';
import 'mobile_art.dart';

/// Literal cPrint(a,b,prefix,word,suffix): preserve the word's own EGA color.
/// Dynamic/conflicting expressions remain owned by their explicit adapters.
Widget loreSourceText(String text, TextStyle style) {
  final lines = text.split('\n');
  final parts = [for (final line in lines) _sourceParts(line)];
  if (parts.every((line) => line == null)) {
    return SourceInk(child: Text(text, style: style));
  }
  return SourceInk(
    child: Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const TextSpan(text: '\n'),
            if (parts[i] case final colored?)
              for (final (color, part) in colored)
                TextSpan(
                  text: part,
                  style: TextStyle(color: RetroTheme.ega(color)),
                )
            else
              TextSpan(text: lines[i]),
          ],
        ],
      ),
      style: style,
    ),
  );
}

List<(int, String)>? _sourceParts(String line) {
  if (line == LoreViewProcedures.quickViewHeading) {
    return LoreViewProcedures.quickViewHeadingParts;
  }
  final literal = LoreSourceSpeech.spans[line];
  if (literal != null) return literal;
  for (final (color, wordColor, prefix, suffix) in LoreSourceSpeech.patterns) {
    if (line.startsWith(prefix) &&
        line.endsWith(suffix) &&
        line.length >= prefix.length + suffix.length) {
      return [
        if (prefix.isNotEmpty) (color, prefix),
        (wordColor, line.substring(prefix.length, line.length - suffix.length)),
        if (suffix.isNotEmpty) (color, suffix),
      ];
    }
  }
  return null;
}

/// Presents adjacent source `Print` calls as one naturally wrapping mobile
/// paragraph. Empty source lines remain paragraph breaks; ordinary source
/// line boundaries become spaces so the viewport decides where to wrap.
Widget loreDialogueText(
  List<(int, String)> lines, {
  TextStyle? style,
  bool correctSpacing = false,
}) {
  final spans = <InlineSpan>[];
  var hasText = false;
  var paragraphBreak = false;
  for (final (baseColor, rawText) in lines) {
    final text = rawText.trim();
    if (text.isEmpty) {
      if (hasText && !paragraphBreak) {
        spans.add(const TextSpan(text: '\n\n'));
        paragraphBreak = true;
      }
      continue;
    }
    if (hasText && !paragraphBreak) spans.add(const TextSpan(text: ' '));
    final parts = _sourceParts(rawText) ?? [(baseColor, text)];
    for (var i = 0; i < parts.length; i++) {
      final (color, part) = parts[i];
      spans.add(
        TextSpan(
          text: parts.length == 1
              ? part.trim()
              : i == 0
              ? part.trimLeft()
              : i == parts.length - 1
              ? part.trimRight()
              : part,
          style: TextStyle(color: RetroTheme.ega(color)),
        ),
      );
    }
    hasText = true;
    paragraphBreak = false;
  }
  return SourceInk(
    child: Text.rich(
      TextSpan(children: correctSpacing ? _correctSpacing(spans) : spans),
      style:
          style ??
          RetroTheme.dosFont.copyWith(
            color: RetroTheme.ega(lines.isEmpty ? 7 : lines.first.$1),
          ),
      softWrap: true,
    ),
  );
}

List<InlineSpan> _correctSpacing(List<InlineSpan> spans) {
  final result = <InlineSpan>[];
  final paragraph = <TextSpan>[];
  void flush() {
    final raw = paragraph.map((span) => span.text ?? '').join();
    final key = raw.replaceAll(RegExp(r'\s+'), '');
    final corrected = dialogueSpacing[key];
    if (corrected == null) {
      result.addAll(paragraph);
    } else {
      final colored = <(String, TextStyle?)>[
        for (final span in paragraph)
          for (final char in (span.text ?? '').split(''))
            if (char.trim().isNotEmpty) (char, span.style),
      ];
      var index = 0;
      for (final char in corrected.split('')) {
        result.add(
          TextSpan(
            text: char,
            style: char.trim().isEmpty ? null : colored[index++].$2,
          ),
        );
      }
    }
    paragraph.clear();
  }

  for (final span in spans.cast<TextSpan>()) {
    if (span.text == '\n\n') {
      flush();
      result.add(span);
    } else {
      paragraph.add(span);
    }
  }
  flush();
  return result;
}

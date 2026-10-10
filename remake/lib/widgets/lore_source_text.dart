import 'package:flutter/material.dart';

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
Widget loreDialogueText(List<(int, String)> lines, {TextStyle? style}) {
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
    for (final (color, part) in parts) {
      spans.add(
        TextSpan(
          text: part.trim().isEmpty ? part : part.trim(),
          style: TextStyle(color: RetroTheme.ega(color)),
        ),
      );
    }
    hasText = true;
    paragraphBreak = false;
  }
  return SourceInk(
    child: Text.rich(
      TextSpan(children: spans),
      style: style ?? RetroTheme.dosFont,
      softWrap: true,
    ),
  );
}

import 'package:flutter/material.dart';

import '../logic/lore_source_speech.dart';
import '../logic/lore_view_procedures.dart';
import '../theme/retro_theme.dart';

/// Literal cPrint(a,b,prefix,word,suffix): preserve the word's own EGA color.
/// Dynamic/conflicting expressions remain owned by their explicit adapters.
Text loreSourceText(String text, TextStyle style) {
  List<(int, String)>? sourceParts(String line) {
    if (line == LoreViewProcedures.quickViewHeading) {
      return LoreViewProcedures.quickViewHeadingParts;
    }
    final literal = LoreSourceSpeech.spans[line];
    if (literal != null) return literal;
    for (final (color, wordColor, prefix, suffix)
        in LoreSourceSpeech.patterns) {
      if (line.startsWith(prefix) &&
          line.endsWith(suffix) &&
          line.length >= prefix.length + suffix.length) {
        return [
          if (prefix.isNotEmpty) (color, prefix),
          (
            wordColor,
            line.substring(prefix.length, line.length - suffix.length),
          ),
          if (suffix.isNotEmpty) (color, suffix),
        ];
      }
    }
    return null;
  }

  final lines = text.split('\n');
  final parts = [for (final line in lines) sourceParts(line)];
  if (parts.every((line) => line == null)) return Text(text, style: style);
  return Text.rich(
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
  );
}

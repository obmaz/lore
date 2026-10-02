import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/bgi_font_decoder.dart';
import 'package:lore/theme/retro_theme.dart';

void main() {
  final source = File('repo_source/LORE_1993_src/LORESUB.PAS')
      .readAsStringSync(encoding: latin1);
  final setup = source.substring(source.lastIndexOf('Procedure Set_All;'));
  Color sourceColor(String pattern, String text) {
    final match = RegExp(pattern, caseSensitive: false).firstMatch(text)!;
    final index = int.parse(match.group(1)!);
    return index == 0 ? Colors.black : BgiFontDecoder.vgaPalette[index];
  }

  test('UI backgrounds and frames match source Set_All color indices', () {
    expect(
      RetroTheme.background,
      sourceColor(r'SetFillStyle\(1,(\d+)\);\s*Bar\(0,0,639,349\)', setup),
    );
    expect(
      RetroTheme.panelBg,
      sourceColor(r'SetFillStyle\(1,(\d+)\);\s*Bar\(21,241,616,330\)', setup),
    );
    expect(
      RetroTheme.partyBorderColor,
      sourceColor(
        r'SetColor\((\d+)\);\s*Line\(14,234,19,239\);\s*RectAngle\(10,230,627,341\)',
        setup,
      ),
    );
    expect(
      RetroTheme.borderColor,
      sourceColor(
        r'SetColor\((\d+)\);\s*Line\(224,14,229,19\);\s*RectAngle\(220,10,627,209\)',
        setup,
      ),
    );
    expect(
      RetroTheme.partyHeaderColor,
      sourceColor(r'SetColor\((\d+)\);\s*bHPrint\(78,213,', setup),
    );
  });

  test('party numbers and plain dialogue use source text colors', () {
    final status = source.substring(
      source.lastIndexOf('Procedure SimpleDisCond;'),
    );
    expect(
      RetroTheme.partyTextColor,
      sourceColor(r'begin\s*setcolor\((\d+)\)', status),
    );
    final talk = source.substring(
      source.indexOf('Procedure talk(s:string);\nbegin'),
    );
    expect(
      RetroTheme.dialogueTextColor,
      sourceColor(r'Print\((\d+),s\)', talk),
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/widgets/encounter_viewport_view.dart';

void main() {
  testWidgets('조우 선택 화면은 적 평균 민첩성과 두 선택을 표시한다', (tester) async {
    var engaged = 0;
    var fled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EncounterViewportView(
            enemies: [
              Monster.create(1)..agility = 10,
              Monster.create(2)..agility = 11,
            ],
            onEngage: () => engaged++,
            onFlee: () => fled++,
          ),
        ),
      ),
    );
    expect(find.textContaining('적의 평균 민첩성 : 10'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('encounter-engage')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('encounter-flee')));
    expect((engaged, fled), (1, 1));
  });
}

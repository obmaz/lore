import 'package:flutter/material.dart';

import '../services/save_manager.dart';
import '../theme/mobile_theme.dart';
import 'mobile_art.dart';
import 'mobile_dialog_action.dart';

/// Four existing slots only. Choosing a card does not write a save.
class MobileSaveView extends StatefulWidget {
  const MobileSaveView({super.key, required this.slots, required this.onLoad});
  final List<SaveData?> slots;
  final ValueChanged<SaveData> onLoad;
  @override
  State<MobileSaveView> createState() => _MobileSaveViewState();
}

class _MobileSaveViewState extends State<MobileSaveView> {
  int _selected = 0;
  @override
  void initState() {
    super.initState();
    final first = widget.slots.indexWhere((s) => s != null);
    if (first >= 0) _selected = first;
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '저장 불러오기',
                style: TextStyle(
                  color: MobileTheme.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => setState(() => _selected = i),
              child: Container(
                decoration: MobileTheme.card(selected: i == _selected),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    MobileArt(
                      widget.slots[i] == null ? 'status-scroll' : 'save-book',
                      size: 56,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '슬롯 ${i + 1}',
                            style: const TextStyle(
                              color: MobileTheme.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            SaveManager.slotNames[i],
                            style: const TextStyle(
                              color: MobileTheme.muted,
                              fontSize: 11,
                            ),
                          ),
                          if (widget.slots[i] case final save?) ...[
                            Text(
                              save.mapTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MobileTheme.ink,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${save.party.where((p) => p.name.isNotEmpty).map((p) => p.name).join(', ')}\n${save.timestamp.toLocal().toString().split('.').first}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MobileTheme.muted,
                                fontSize: 10,
                              ),
                            ),
                          ] else
                            const Text(
                              '비어 있음',
                              style: TextStyle(
                                color: MobileTheme.muted,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      i == _selected ? Icons.check_circle : Icons.chevron_right,
                      color: i == _selected
                          ? MobileTheme.mint
                          : MobileTheme.line,
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        ElevatedButton(
          onPressed: widget.slots[_selected] == null
              ? null
              : () => widget.onLoad(widget.slots[_selected]!),
          child: const Text(
            '이전의 게임을 재개',
            style: TextStyle(
              color: MobileTheme.ink,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),
        MobileDialogAction(
          label: '닫기',
          onPressed: () => Navigator.pop(context),
          secondary: true,
        ),
      ],
    ),
  );
}

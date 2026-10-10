import 'package:flutter/material.dart';

import '../models/party_member.dart';
import 'mobile_content_dialog.dart';
import 'mobile_dialog_action.dart';
import 'mobile_party_view.dart';

Future<List<int>?> showMobilePartyDialog(
  BuildContext context, {
  required List<PartyMember> party,
  int initialIndex = 0,
  Key? closeKey,
  bool returnToParent = false,
  Future<List<int>?> Function(int memberIndex)? prepareExtrasense,
}) => showDialog<List<int>>(
  context: context,
  builder: (ctx) => MobileContentDialog(
    title: '일행 상세',
    contentPadding: EdgeInsets.zero,
    content: MobilePartyView(
      party: party,
      initialIndex: initialIndex,
      showFooterActions: false,
      scrollable: false,
      onCast: () {},
      onExtrasense: prepareExtrasense == null
          ? null
          : (index) async {
              final choices = await prepareExtrasense(index);
              if (ctx.mounted && choices != null) Navigator.pop(ctx, choices);
            },
    ),
    footer: MobileDialogAction(
      key: closeKey,
      label: returnToParent ? '돌아가기' : '닫기',
      secondary: true,
      onPressed: () => Navigator.pop(ctx),
    ),
  ),
);

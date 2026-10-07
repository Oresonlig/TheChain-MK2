/// Rutan för [WhatsNewNote] (app/whats_new.dart). Går inte att trycka bort
/// utanför — bara OK eller SKIP, så att den hinner läsas (Niklas 2026-10-07).
library;

import 'package:flutter/material.dart';

import '../app/whats_new.dart';
import '../theme/chain_theme.dart';

Future<void> showWhatsNew(BuildContext context, WhatsNewNote note) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WhatsNewDialog(note: note),
    );

class _WhatsNewDialog extends StatelessWidget {
  const _WhatsNewDialog({required this.note});
  final WhatsNewNote note;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false, // bakåtknappen stänger inte heller — OK eller SKIP
      child: AlertDialog(
        title: Text("WHAT'S NEW", style: text.titleMedium!.copyWith(letterSpacing: 2)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final p in note.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('•  ', style: text.bodyMedium!.copyWith(color: c.accent)),
                  Expanded(child: Text(p, style: text.bodyMedium!.copyWith(color: c.textBody))),
                ]),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Skip')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}

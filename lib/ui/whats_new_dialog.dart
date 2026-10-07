/// Rutan för [WhatsNewNote] (app/whats_new.dart). Går inte att trycka bort
/// utanför — bara OK eller SKIP, så att den hinner läsas (Niklas 2026-10-07).
library;

import 'package:flutter/material.dart';

import '../app/whats_new.dart';
import '../theme/chain_theme.dart';

/// Sant = användaren kryssade "Don't show again". Null = stängd av systemet.
Future<bool?> showWhatsNew(BuildContext context, WhatsNewNote note) => showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WhatsNewDialog(note: note),
    );

class _WhatsNewDialog extends StatefulWidget {
  const _WhatsNewDialog({required this.note});
  final WhatsNewNote note;

  @override
  State<_WhatsNewDialog> createState() => _WhatsNewDialogState();
}

class _WhatsNewDialogState extends State<_WhatsNewDialog> {
  bool _never = false;

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
            for (final p in widget.note.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('•  ', style: text.bodyMedium!.copyWith(color: c.accent)),
                  Expanded(child: Text(p, style: text.bodyMedium!.copyWith(color: c.textBody))),
                ]),
              ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _never = !_never),
              child: Row(children: [
                Checkbox(value: _never, onChanged: (v) => setState(() => _never = v ?? false)),
                Expanded(child: Text("Don't show again", style: text.bodySmall)),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, _never), child: const Text('Skip')),
          TextButton(onPressed: () => Navigator.pop(context, _never), child: const Text('OK')),
        ],
      ),
    );
  }
}

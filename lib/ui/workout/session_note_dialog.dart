/// "How did it feel?" — vid FINISH SESSION och för att ändra anteckningen i
/// efterhand (History). Frivillig: tomt fält är ett giltigt svar.
library;

import 'package:flutter/material.dart';

/// Texten (kan vara tom) eller null om användaren avbröt — Cancel backar ett
/// steg, inget går framåt. [skipLabel] = gå vidare utan anteckning (FINISH,
/// Niklas 2026-10-06).
Future<String?> askSessionNote(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? skipLabel,
  String? initial,
}) {
  // Ingen dispose: dialogens stängningsanimation läser fältet efter pop.
  final field = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: field,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'How did it feel? (optional)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        if (skipLabel != null) TextButton(onPressed: () => Navigator.pop(ctx, ''), child: Text(skipLabel)),
        TextButton(onPressed: () => Navigator.pop(ctx, field.text.trim()), child: Text(confirmLabel)),
      ],
    ),
  );
}

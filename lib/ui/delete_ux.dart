/// Standard när användaren tar bort historik (Niklas 2026-10-06): bekräftelse
/// med ett extra tryck, sedan UNDO i 2,5 s. Triviala saker (anteckningar) får
/// bara UNDO.
library;

import 'package:flutter/material.dart';

/// Bekräftelse före radering. Sant = användaren tryckte [action].
Future<bool> confirmDelete(BuildContext context, {required String title, required String body, String action = 'Delete'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    ) ==
    true;

/// UNDO-meddelandet. Försvinner av sig självt efter 2,5 s (2026-10-05: 5 s var
/// "en evighet"); persist: false, annars ligger det kvar tills det dras bort.
void showUndo(ScaffoldMessengerState messenger, String message, VoidCallback onUndo) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(
    content: Text(message),
    action: SnackBarAction(label: 'UNDO', onPressed: onUndo),
    persist: false,
    duration: const Duration(milliseconds: 2500),
  ));

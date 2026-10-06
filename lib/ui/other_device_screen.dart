/// En enhet i taget (Niklas 2026-10-06): kontot är redan inloggat någon
/// annanstans. Varning + val INNAN något öppnas här — CANCEL på en kompis
/// telefon lämnar inget efter sig.
library;

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../theme/chain_theme.dart';
import '../theme/surfaces.dart';
import 'nanosuit_scaffold.dart';

class OtherDeviceScreen extends StatelessWidget {
  const OtherDeviceScreen({super.key, required this.app, this.now});

  final AppController app;
  final DateTime Function()? now;

  /// "active 2 h ago" / "active 3 days ago".
  static String ago(DateTime? t, DateTime now) {
    if (t == null) return 'last active unknown';
    final d = now.difference(t);
    if (d.inMinutes < 2) return 'active now';
    if (d.inHours < 1) return 'active ${d.inMinutes} min ago';
    if (d.inDays < 1) return 'active ${d.inHours} h ago';
    return 'active ${d.inDays} ${d.inDays == 1 ? 'day' : 'days'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final others = app.otherDevices ?? const <OtherSession>[];
    final t = (now ?? DateTime.now)();
    final n = others.length;
    return ChainScaffold(
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
          children: [
            Text('THE', style: text.displaySmall),
            Text('CHAIN',
                style: text.displaySmall!.copyWith(
                  color: c.accent,
                  shadows: [Shadow(color: c.accent.withValues(alpha: .6), blurRadius: 14)],
                )),
            const SizedBox(height: 32),
            Glass(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('SIGNED IN ELSEWHERE', style: text.titleMedium!.copyWith(letterSpacing: 2)),
                const SizedBox(height: 12),
                Text(
                  'Your account is signed in on ${n == 1 ? 'another device' : '$n other devices'}:',
                  style: text.bodyMedium!.copyWith(color: c.textBody),
                ),
                const SizedBox(height: 8),
                for (final o in others)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('•  ${o.isWebsite ? 'Website' : 'The Chain app'} · ${ago(o.lastActive, t)}',
                        style: text.bodyMedium!.copyWith(color: c.textStrong)),
                  ),
                const SizedBox(height: 8),
                Text(
                  'The Chain runs on one device at a time. Signing in here signs you out '
                  '${n == 1 ? 'there' : 'everywhere else'}.',
                  style: text.bodySmall!.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: app.busy ? null : app.confirmSignInHere,
                  child: Raised(
                    material: c.raisedActive,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(child: Text(app.busy ? 'SIGNING IN…' : 'SIGN IN HERE', style: text.labelLarge)),
                  ),
                ),
                const SizedBox(height: 10),
                GhostButton(label: 'CANCEL', onTap: app.busy ? null : app.cancelSignIn),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

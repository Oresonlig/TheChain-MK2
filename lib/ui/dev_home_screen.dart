/// F2 DEV-vy: visar att inloggning, import och synk fungerar på riktig data.
/// Ingen slutlig design — ersätts av kedjevyn i F3.
library;

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../data/sync_engine.dart';
import '../domain/domain.dart';
import '../theme/chain_theme.dart';
import '../theme/surfaces.dart';
import 'format.dart';
import 'nanosuit_scaffold.dart';
import 'theme_preview.dart';

class DevHomeScreen extends StatelessWidget {
  const DevHomeScreen({super.key, required this.app, this.email = '', this.buildLabel = ''});

  final AppController app;
  final String email;
  final String buildLabel;

  @override
  Widget build(BuildContext context) {
    return ChainScaffold(
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final repo = app.repo;
          final text = Theme.of(context).textTheme;
          final c = context.chain;
          if (repo == null) return const Center(child: CircularProgressIndicator());

          final history = repo.history();
          final program = repo.program();
          final chain = repo.chain();
          final settings = repo.settings();
          final prs = personalRecords(history, hidden: repo.hiddenRecords()).values.toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final workouts = history.whereType<WorkoutEntry>().toList()..sort((a, b) => b.date.compareTo(a.date));
          final weights = repo.bodyweight();
          final next = chain.next == null ? null : program.sessionById(chain.next!);
          final pending = Tables.all.fold<int>(0, (s, t) => s + repo.engine[t].pendingCount);

          Widget row(String k, String v) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(k, style: text.bodySmall)),
                  Text(v, style: text.bodyMedium!.copyWith(color: c.textStrong)),
                ]),
              );
          Widget button(String label, VoidCallback? onTap, {bool primary = false}) => Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Raised(
                    material: primary ? c.raisedActive : c.raisedIdle,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: Text(label, style: text.labelLarge!.copyWith(fontSize: 12))),
                  ),
                ),
              );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text('MK2 · F2 DATA CHECK', style: text.labelSmall!.copyWith(color: c.accent)),
              const SizedBox(height: 4),
              Text(email, style: text.titleMedium),
              Text(buildLabel, style: text.labelSmall),
              const SizedBox(height: 16),
              Glass(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('CHAIN', style: text.labelSmall),
                  row('Round', '${chain.round}'),
                  row('Done this round', '${chain.done.length} / ${program.sessions.length}'),
                  row('Next session', next == null ? '—' : '${next.id.value} · ${next.name}'),
                  row('Sessions in program', '${program.sessions.length}'),
                ]),
              ),
              const SizedBox(height: 12),
              Glass(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('DATA', style: text.labelSmall),
                  row('Workouts logged', '${workouts.length}'),
                  row('Rest days', '${history.whereType<RestEntry>().length}'),
                  row('Last workout', workouts.isEmpty ? '—' : fmtDate(workouts.first.date)),
                  row('Personal records', '${prs.length}'),
                  row('Bodyweight entries', '${weights.length}'),
                  row('Latest weight', weights.isEmpty ? '—' : fmtWeight(weights.last.kg, settings.weightUnit)),
                  row('Notes', '${repo.notes().length}'),
                  row('Waiting to sync', '$pending'),
                  row('Status', app.status ?? '—'),
                ]),
              ),
              if (prs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Glass(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('LATEST RECORDS', style: text.labelSmall),
                    for (final pr in prs.take(6))
                      row(repo.exercise(pr.exerciseId)?.name ?? pr.exerciseId.value, fmtRecord(pr, settings.weightUnit)),
                  ]),
                ),
              ],
              if (app.error != null) ...[
                const SizedBox(height: 12),
                Text(app.error!, style: text.bodySmall!.copyWith(color: const Color(0xFFFF6B6B))),
              ],
              const SizedBox(height: 20),
              Row(children: [
                button('SYNC NOW', app.busy ? null : app.syncNow, primary: true),
                const SizedBox(width: 8),
                // Avstängd efter flytten (och tills kontot kunnat kollas): en import
                // skulle ersätta appens data med hemsidans gamla.
                button('IMPORT', app.busy || app.moved != false ? null : () => _confirmImport(context)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                button('THEME PREVIEW', () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ThemePreviewScreen(channelLabel: buildLabel),
                    ))),
                const SizedBox(width: 8),
                button('SIGN OUT', app.busy ? null : app.signOut),
              ]),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmImport(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import from website?'),
        content: const Text(
            'Copies your history, program, records and weight from the website into the app. '
            'Running it again replaces app data with the website data. The website is not changed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
        ],
      ),
    );
    if (ok == true) await app.importFromWebsite();
  }
}

/// Settings → Data & Sync (ersätter gamla Data check, 2026-10-04): synkstatus
/// + SYNC NOW, backup, engångsimporten från hemsidan, kontoflytten och
/// kontrollsiffrorna.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app_controller.dart';
import '../../data/backup.dart';
import '../../data/sync_engine.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
import '../format.dart';
import 'settings_screen.dart';

class DataSyncScreen extends StatelessWidget {
  const DataSyncScreen({super.key, required this.app, this.email = '', this.versionLabel = ''});

  final AppController app;
  final String email;
  final String versionLabel;

  @override
  Widget build(BuildContext context) => SettingsPage(
        app: app,
        title: 'DATA & SYNC',
        builder: (context, app) {
          final repo = app.repo!;
          final text = Theme.of(context).textTheme;
          final c = context.chain;
          final history = repo.history();
          final program = repo.program();
          final chain = repo.chain();
          final settings = repo.settings();
          final prs = repo.records().values.toList()
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
          Widget tile(String title, String subtitle, IconData icon, VoidCallback? onTap, {Color? iconColor}) => ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: onTap != null,
                title: Text(title, style: text.titleMedium),
                subtitle: Text(subtitle, style: text.bodySmall),
                trailing: Icon(icon, color: iconColor ?? c.textMuted),
                onTap: onTap,
              );

          return [
            settingsSection(context, 'SYNC', [
              row('Status', app.status ?? '—'),
              row('Last synced', app.lastSync == null ? '—' : fmtDateTime(app.lastSync!)),
              row('Waiting to sync', '$pending'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: app.busy ? null : app.syncNow,
                child: Raised(
                  material: app.busy ? c.raisedIdle : c.raisedActive,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(app.busy ? 'SYNCING…' : 'SYNC NOW',
                        style: text.labelLarge!.copyWith(color: app.busy ? c.textFaint : c.textStrong)),
                  ),
                ),
              ),
            ]),
            settingsSection(context, 'BACKUP', [
              tile('Export backup', 'Everything in the app as one file — save it to Drive or mail it to yourself.', Icons.ios_share,
                  () => _exportBackup()),
            ]),
            settingsSection(context, 'WEBSITE', [
              if (app.moved == true)
                tile(
                  'Account lives in the app',
                  'Moved ${app.movedAt == null ? '' : fmtDate(app.movedAt!)} · the website is closed for this account and import is off.',
                  Icons.check_circle_outline,
                  null,
                  iconColor: c.success,
                )
              else ...[
                // Avstängd tills kontot kunnat kollas: en import efter flytten
                // skulle ersätta appens data med hemsidans gamla.
                tile('Import from the website', 'Copies history, program, records and weight into the app.', Icons.download,
                    app.busy || app.moved != false ? null : () => _confirmImport(context)),
                if (app.moved == false)
                  tile('Move my account to the app', 'The website stops working for this account.', Icons.phone_android,
                      () => _confirmMove(context)),
              ],
            ]),
            if (app.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(app.error!, style: text.bodySmall!.copyWith(color: c.fail)),
              ),
            settingsSection(context, 'IN THE APP', [
              row('Round', '${chain.round}'),
              row('Done this round', '${chain.done.length} / ${program.sessions.length}'),
              row('Next session', next == null ? '—' : next.name),
              row('Workouts logged', '${workouts.length}'),
              row('Forced rest days', '${history.whereType<RestEntry>().length}'),
              row('Last workout', workouts.isEmpty ? '—' : fmtDate(workouts.first.date)),
              row('Personal records', '${prs.length}'),
              row('Bodyweight entries', '${weights.length}'),
              row('Latest weight', weights.isEmpty ? '—' : fmtWeight(weights.last.kg, settings.weightUnit)),
              row('Notes', '${repo.notes().length}'),
            ]),
          ];
        },
      );

  Future<void> _exportBackup() async {
    final json = app.exportBackup(versionLabel);
    final name = backupFileName(DateTime.now());
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(Uint8List.fromList(utf8.encode(json)), mimeType: 'application/json', name: name)],
      fileNameOverrides: [name],
      subject: 'The Chain backup',
    ));
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

  Future<void> _confirmMove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move your account to the app?'),
        content: const Text(
          'The website will show that this account has moved and stop saving anything. '
          'Import is turned off, so the app\'s data can never be overwritten by the website\'s older data.\n\n'
          'Export a backup first if you want an extra copy.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Move')),
        ],
      ),
    );
    if (ok != true) return;
    final moved = await app.moveToApp(versionLabel);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(moved ? 'Your account now lives in the app' : (app.error ?? 'Could not move the account')),
      ));
    }
  }
}

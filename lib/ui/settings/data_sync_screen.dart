/// Settings → Data & Sync (ersätter gamla Data check, 2026-10-04): synkstatus
/// + SYNC NOW, backup, engångsimporten från hemsidan, kontoflytten och
/// kontrollsiffrorna.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
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
              if (app.updater != null) _updateRow(context),
            ]),
            settingsSection(context, 'BACKUP', [
              tile('Export backup', 'Everything in the app as one file — save it to Drive or mail it to yourself.', Icons.ios_share,
                  () => _exportBackup()),
              tile('Restore from backup', 'Brings back what is missing. Nothing is deleted; newer changes on this phone are kept.',
                  Icons.settings_backup_restore, app.busy ? null : () => _restoreBackup(context)),
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

  /// Vad versionskollen hittade — samma koll som SYNC NOW gör, svaret syns här
  /// i stället för bara på kedjevyn (Niklas 2026-10-04).
  Widget _updateRow(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final u = app.update;
    final String line;
    if (u != null) {
      line = 'Build ${u.build} ready';
    } else if (app.updateChecking) {
      line = 'Checking for updates…';
    } else if (app.updateCheckFailed) {
      line = 'Could not check for updates';
    } else if (app.updateCheckedAt case final t?) {
      line = 'Up to date · build ${app.updater!.currentBuild} · checked ${fmtTime(t)}';
    } else {
      return const SizedBox.shrink();
    }
    final downloading = app.updateStatus?.startsWith('Downloading') ?? false;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        Icon(
            u != null
                ? Icons.system_update
                : (app.updateCheckFailed ? Icons.error_outline : Icons.check_circle_outline),
            size: 16,
            color: u != null ? c.accent : (app.updateCheckFailed ? c.fail : c.textMuted)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(line, style: text.bodySmall!.copyWith(color: u != null ? c.textStrong : null)),
            if (u != null && app.updateStatus != null) Text(app.updateStatus!, style: text.bodySmall),
          ]),
        ),
        if (u != null)
          GestureDetector(
            onTap: downloading ? null : app.installUpdate,
            child: Raised(
              material: c.raisedActive,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(downloading ? '…' : 'UPDATE', style: text.labelLarge!.copyWith(fontSize: 12)),
            ),
          ),
      ]),
    );
  }

  Future<void> _exportBackup() async {
    final json = app.exportBackup(versionLabel);
    final name = backupFileName(DateTime.now());
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(Uint8List.fromList(utf8.encode(json)), mimeType: 'application/json', name: name)],
      fileNameOverrides: [name],
      subject: 'The Chain backup',
    ));
  }

  /// Väljer fil → visar vad som händer → återställer först efter ja.
  Future<void> _restoreBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Backup', extensions: ['json'], mimeTypes: ['application/json', 'text/plain', 'application/octet-stream']),
    ]);
    if (file == null) return;
    final RestorePlan plan;
    try {
      plan = app.planBackupRestore(await file.readAsString());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!context.mounted) return;
    if (plan.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Nothing to restore — everything in the backup is already here')));
      return;
    }
    final lines = [
      for (final (t, label) in const [
        (Tables.workouts, 'sessions, rest days and skips'),
        (Tables.bodyweight, 'weight entries'),
        (Tables.notes, 'notes'),
        (Tables.exercises, 'exercises and adjustments'),
        (Tables.program, 'program'),
        (Tables.settings, 'settings'),
      ])
        if (plan.count(t) > 0) '${plan.count(t)} $label',
    ];
    final other = plan.email != null && plan.email != email && email.isNotEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: Text([
          'Brings back: ${lines.join(', ')}.',
          if (plan.keptNewer > 0) '${plan.keptNewer} newer changes on this phone are kept.',
          'Nothing is deleted.',
          if (other) '\nThis backup belongs to ${plan.email}.',
        ].join('\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;
    await app.restore(plan);
    messenger.showSnackBar(SnackBar(content: Text('Restored ${lines.join(', ')}')));
  }

  /// Har appen redan ett eget program frågar importen om det ska behållas
  /// (Niklas 2026-10-05: inget nybyggt schema får försvinna tyst).
  Future<void> _confirmImport(BuildContext context) async {
    final hasOwnProgram = app.repo!.program().sessions.isNotEmpty;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import from website?'),
        content: Text(hasOwnProgram
            ? 'Brings your history, records, weight and notes from the website into the app.\n\n'
                'The app already has its own program. Keep it, or replace it with the website\'s? '
                'The website is not changed.'
            : 'Copies your history, program, records and weight from the website into the app. The website is not changed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          if (hasOwnProgram) ...[
            TextButton(onPressed: () => Navigator.pop(ctx, 'replace'), child: const Text("Use the website's")),
            TextButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: const Text('Keep my program')),
          ] else
            TextButton(onPressed: () => Navigator.pop(ctx, 'replace'), child: const Text('Import')),
        ],
      ),
    );
    if (choice == null) return;
    await app.importFromWebsite(keepProgram: choice == 'keep');
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
    if (ok != true || !context.mounted) return;
    // Aldrig importerat men hemsidan har data: efter flytten går historiken
    // inte att hämta in längre — fråga en gång till.
    if (!app.repo!.settings().importedFromWebsite) {
      await app.checkWebsiteData();
      if (app.websiteData == true && context.mounted) {
        final next = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Bring your website history first?'),
            content: const Text(
                "You haven't imported your history from the website. After the move, import is off for good "
                '— the website history stays there as a frozen backup.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, 'move'), child: const Text('Move anyway')),
              TextButton(onPressed: () => Navigator.pop(ctx, 'import'), child: const Text('Import first')),
            ],
          ),
        );
        if (next == null || !context.mounted) return;
        if (next == 'import') {
          await _confirmImport(context);
          return;
        }
      }
    }
    final moved = await app.moveToApp(versionLabel);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(moved ? 'Your account now lives in the app' : (app.error ?? 'Could not move the account')),
      ));
    }
  }
}

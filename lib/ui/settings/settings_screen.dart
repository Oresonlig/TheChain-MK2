/// Settings-fliken: enheter, rörlig bakgrund, datavy, utloggning, version.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app_controller.dart';
import '../../data/backup.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
import '../dev_home_screen.dart';
import '../format.dart';
import '../nanosuit_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.app, required this.email, required this.versionLabel});

  final AppController app;
  final String email;
  final String versionLabel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final repo = app.repo;
        if (repo == null) return const SizedBox.shrink();
        final c = context.chain;
        final text = Theme.of(context).textTheme;
        final s = repo.settings();

        UserSettings copy({WeightUnit? w, TempUnit? t, bool? ambient}) => UserSettings(
              weightUnit: w ?? s.weightUnit,
              tempUnit: t ?? s.tempUnit,
              restTimerEnabled: s.restTimerEnabled,
              restTimerSecs: s.restTimerSecs,
              weightGoalKg: s.weightGoalKg,
              ambientEffects: ambient ?? s.ambientEffects,
            );

        Widget choice(String label, bool on, VoidCallback onTap) => Expanded(
              child: GestureDetector(
                onTap: onTap,
                child: SizedBox(
                  height: 48,
                  child: on
                      ? Raised(material: c.raisedActive, padding: EdgeInsets.zero, child: Center(child: Text(label, style: text.labelLarge)))
                      : DecoratedBox(
                          decoration: BoxDecoration(border: Border.all(color: c.borderStrong)),
                          child: Center(child: Text(label, style: text.labelLarge!.copyWith(color: c.textMuted))),
                        ),
                ),
              ),
            );

        Widget section(String title, List<Widget> children) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Glass(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(title, style: text.labelSmall),
                  const SizedBox(height: 10),
                  ...children,
                ]),
              ),
            );

        return ChainScaffold(
          ambient: s.ambientEffects,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text('SETTINGS', style: text.titleLarge!.copyWith(letterSpacing: 4)),
              const SizedBox(height: 4),
              Text(email, style: text.bodySmall),
              const SizedBox(height: 16),
              section('WEIGHT UNIT', [
                Row(children: [
                  choice('KG', s.weightUnit == WeightUnit.kg, () => app.updateSettings(copy(w: WeightUnit.kg))),
                  const SizedBox(width: 8),
                  choice('LBS', s.weightUnit == WeightUnit.lbs, () => app.updateSettings(copy(w: WeightUnit.lbs))),
                ]),
              ]),
              section('TEMPERATURE UNIT', [
                Row(children: [
                  choice('°C', s.tempUnit == TempUnit.celsius, () => app.updateSettings(copy(t: TempUnit.celsius))),
                  const SizedBox(width: 8),
                  choice('°F', s.tempUnit == TempUnit.fahrenheit, () => app.updateSettings(copy(t: TempUnit.fahrenheit))),
                ]),
              ]),
              section('APPEARANCE', [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: s.ambientEffects,
                  onChanged: (v) => app.updateSettings(copy(ambient: v)),
                  title: Text('Moving background', style: text.titleMedium),
                  subtitle: Text('The hex wave behind the app. Turn off to save battery.', style: text.bodySmall),
                ),
              ]),
              section('DATA', [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Data check · import · sync', style: text.titleMedium),
                  trailing: Icon(Icons.chevron_right, color: c.textMuted),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => DevHomeScreen(app: app, email: email, buildLabel: versionLabel),
                  )),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Export backup', style: text.titleMedium),
                  subtitle: Text('Everything in the app as one file — save it to Drive or mail it to yourself.', style: text.bodySmall),
                  trailing: Icon(Icons.ios_share, color: c.textMuted),
                  onTap: () => _exportBackup(context),
                ),
                if (app.moved == false)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Move my account to the app', style: text.titleMedium),
                    subtitle: Text('The website stops working for this account.', style: text.bodySmall),
                    trailing: Icon(Icons.phone_android, color: c.textMuted),
                    onTap: () => _confirmMove(context),
                  )
                else if (app.moved == true)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Account lives in the app', style: text.titleMedium),
                    subtitle: Text(
                        'Moved ${app.movedAt == null ? '' : fmtDate(app.movedAt!)} · the website is closed for this account and import is off.',
                        style: text.bodySmall),
                    trailing: Icon(Icons.check_circle_outline, color: c.success),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Sign out', style: text.titleMedium),
                  trailing: Icon(Icons.logout, color: c.textMuted),
                  onTap: app.signOut,
                ),
              ]),
              const SizedBox(height: 8),
              Text(versionLabel, style: text.labelSmall, textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    final json = app.exportBackup(versionLabel);
    final name = backupFileName(DateTime.now());
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(Uint8List.fromList(utf8.encode(json)), mimeType: 'application/json', name: name)],
      fileNameOverrides: [name],
      subject: 'The Chain backup',
    ));
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

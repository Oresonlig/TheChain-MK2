/// Settings-fliken: enheter, rörlig bakgrund, datavy, utloggning, version.
library;

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
import '../dev_home_screen.dart';
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
}

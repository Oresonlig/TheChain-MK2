/// Settings-fliken: en hubb med undergrupper, som MK1 (Niklas 2026-10-04:
/// "lättare att finna t.ex. teman om det var vad man var ute efter, kontra
/// backup"). Kontot överst, SIGN OUT längst ner — aldrig gömd i en undersida.
library;

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
import '../nanosuit_scaffold.dart';
import 'data_sync_screen.dart';

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
        final synced = app.status == 'Synced';
        void open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
        void openData() => open(DataSyncScreen(app: app, email: email, versionLabel: versionLabel));

        return ChainScaffold(
          ambient: s.ambientEffects,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text('SETTINGS', style: text.titleLarge!.copyWith(letterSpacing: 4)),
              const SizedBox(height: 4),
              // Vem är inloggad — syns varje gång, utan att leta.
              Text(email, style: text.bodyMedium!.copyWith(color: c.textBody)),
              const SizedBox(height: 2),
              InkWell(
                onTap: openData,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  // Saira saknar ✓ — ikon i stället för tecken.
                  child: Text.rich(TextSpan(children: [
                    if (synced)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.check, size: 14, color: c.success),
                        ),
                      ),
                    TextSpan(
                      text: synced ? 'All changes synced' : (app.status ?? 'Not synced yet'),
                      style: text.labelSmall!.copyWith(color: synced ? c.success : c.textMuted),
                    ),
                    TextSpan(text: '  ·  $versionLabel  ›', style: text.labelSmall),
                  ])),
                ),
              ),
              const SizedBox(height: 12),
              SettingsRow(
                title: 'Training',
                subtitle: 'Units',
                onTap: () => open(TrainingSettingsScreen(app: app)),
              ),
              SettingsRow(
                title: 'Appearance',
                subtitle: 'Moving background',
                onTap: () => open(AppearanceSettingsScreen(app: app)),
              ),
              SettingsRow(
                title: 'Data & Sync',
                subtitle: 'Sync status · backup · import from the website · move account',
                onTap: openData,
              ),
              const SizedBox(height: 28),
              GhostButton(
                label: 'SIGN OUT',
                leadingIcon: Icons.logout,
                onTap: app.signOut,
                color: c.textMuted,
                borderColor: c.borderStrong,
                height: 52,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// En rad i hubben: namn + vad som finns där + pil.
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.title, required this.subtitle, required this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: title,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Glass(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: text.bodySmall),
                ]),
              ),
              Icon(Icons.chevron_right, color: c.textMuted),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Ram för en undersida: tillbaka-pil + rubrik + innehåll.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.app, required this.title, required this.builder});

  final AppController app;
  final String title;
  final List<Widget> Function(BuildContext context, AppController app) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final repo = app.repo;
        final c = context.chain;
        final text = Theme.of(context).textTheme;
        return ChainScaffold(
          ambient: repo?.settings().ambientEffects ?? true,
          child: repo == null
              ? const SizedBox.shrink() // utloggad; vyn stängs
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                    child: Row(children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back, color: c.textMuted),
                      ),
                      Expanded(child: Text(title, style: text.titleLarge!.copyWith(letterSpacing: 3))),
                    ]),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: builder(context, app),
                    ),
                  ),
                ]),
        );
      },
    );
  }
}

/// Glas med en liten rubrik över innehållet.
Widget settingsSection(BuildContext context, String title, List<Widget> children) {
  final text = Theme.of(context).textTheme;
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Glass(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: text.labelSmall),
        const SizedBox(height: 10),
        ...children,
      ]),
    ),
  );
}

UserSettings _copy(UserSettings s, {WeightUnit? w, TempUnit? t, bool? ambient}) => UserSettings(
      weightUnit: w ?? s.weightUnit,
      tempUnit: t ?? s.tempUnit,
      restTimerEnabled: s.restTimerEnabled,
      restTimerSecs: s.restTimerSecs,
      weightGoalKg: s.weightGoalKg,
      ambientEffects: ambient ?? s.ambientEffects,
    );

/// Två- eller flervalsknapp (KG / LBS).
Widget _choice(BuildContext context, String label, bool on, VoidCallback onTap) {
  final c = context.chain;
  final text = Theme.of(context).textTheme;
  return Expanded(
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
}

class TrainingSettingsScreen extends StatelessWidget {
  const TrainingSettingsScreen({super.key, required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) => SettingsPage(
        app: app,
        title: 'TRAINING',
        builder: (context, app) {
          final s = app.repo!.settings();
          return [
            settingsSection(context, 'WEIGHT UNIT', [
              Row(children: [
                _choice(context, 'KG', s.weightUnit == WeightUnit.kg, () => app.updateSettings(_copy(s, w: WeightUnit.kg))),
                const SizedBox(width: 8),
                _choice(context, 'LBS', s.weightUnit == WeightUnit.lbs, () => app.updateSettings(_copy(s, w: WeightUnit.lbs))),
              ]),
            ]),
            settingsSection(context, 'TEMPERATURE UNIT', [
              Row(children: [
                _choice(context, '°C', s.tempUnit == TempUnit.celsius, () => app.updateSettings(_copy(s, t: TempUnit.celsius))),
                const SizedBox(width: 8),
                _choice(context, '°F', s.tempUnit == TempUnit.fahrenheit, () => app.updateSettings(_copy(s, t: TempUnit.fahrenheit))),
              ]),
            ]),
          ];
        },
      );
}

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key, required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) => SettingsPage(
        app: app,
        title: 'APPEARANCE',
        builder: (context, app) {
          final s = app.repo!.settings();
          final text = Theme.of(context).textTheme;
          return [
            settingsSection(context, 'BACKGROUND', [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.ambientEffects,
                onChanged: (v) => app.updateSettings(_copy(s, ambient: v)),
                title: Text('Moving background', style: text.titleMedium),
                subtitle: Text('The hex wave behind the app. Turn off to save battery.', style: text.bodySmall),
              ),
            ]),
          ];
        },
      );
}

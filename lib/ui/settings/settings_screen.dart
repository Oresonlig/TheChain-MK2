/// Settings-fliken: en hubb med undergrupper, som MK1 (Niklas 2026-10-04:
/// "lättare att finna t.ex. teman om det var vad man var ute efter, kontra
/// backup"). Kontot överst, SIGN OUT längst ner — aldrig gömd i en undersida.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../app/haptics.dart';
import '../../app/report_problem.dart';
import '../../app/rest_timer.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/background_scope.dart';
import '../../theme/surfaces.dart';
import '../../theme/themes.dart';
import '../nanosuit_scaffold.dart';
import '../program/program_screen.dart';
import 'admin_screen.dart';
import 'data_sync_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.app, required this.email, required this.versionLabel, this.devTools = false});

  final AppController app;
  final String email;
  final String versionLabel;

  /// DEV-bygge: temaväljaren visar även teman som inte är släppta.
  final bool devTools;

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
            addRepaintBoundaries: glassListRepaintBoundaries,
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
                title: 'Program',
                subtitle: 'Sessions, exercises and their order',
                onTap: () => open(ProgramScreen(app: app)),
              ),
              SettingsRow(
                title: 'Training & App Functions',
                subtitle: 'Units · finish note · rest timer · vibration',
                onTap: () => open(TrainingSettingsScreen(app: app)),
              ),
              SettingsRow(
                title: 'Appearance',
                subtitle: 'Theme · moving background',
                onTap: () => open(AppearanceSettingsScreen(app: app, devTools: devTools)),
              ),
              SettingsRow(
                title: 'Data & Sync',
                subtitle: 'Sync status · backup · import from the website · move account',
                onTap: openData,
              ),
              SettingsRow(
                title: 'Report a problem',
                subtitle: 'Opens your email app · build and phone are filled in',
                onTap: () async {
                  if (await ReportProblem.open(versionLabel) || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No email app found. Write to $kReportEmail')),
                  );
                },
              ),
              // Bara Niklas — servern spärrar ändå alla andra (supabase/002).
              if (email.toLowerCase() == kAdminEmail)
                SettingsRow(
                  title: 'Admin',
                  subtitle: 'Users · app vs website · builds',
                  onTap: () => open(AdminScreen(app: app)),
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
                      addRepaintBoundaries: glassListRepaintBoundaries,
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

UserSettings _copy(UserSettings s,
        {WeightUnit? w, TempUnit? t, bool? ambient, bool? timer, int? timerSecs, bool? finishNote, bool? wakeScreen}) =>
    s.copyWith(
      restWakeScreen: wakeScreen,
      weightUnit: w,
      tempUnit: t,
      restTimerEnabled: timer,
      restTimerSecs: timerSecs,
      ambientEffects: ambient,
      finishNote: finishNote,
    );

/// Två- eller flervalsknapp (KG / LBS). Delas med välkomstskärmen.
Widget choiceButton(BuildContext context, String label, bool on, VoidCallback onTap) {
  final c = context.chain;
  final text = Theme.of(context).textTheme;
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: on
            ? Raised(material: c.raisedActive, padding: EdgeInsets.zero, child: _fit(Text(label, style: text.labelLarge)))
            : DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: c.borderStrong), borderRadius: c.buttonRadius),
                child: _fit(Text(label, style: text.labelLarge!.copyWith(color: c.textMuted))),
              ),
      ),
    ),
  );
}

/// Ett tema i väljaren, ritat i SITT eget tema (Niklas 2026-10-06): Nanosuit
/// är alltid en chevron i cyan och Saira, Cosmic alltid ett blad i mint och
/// Cinzel — knappen visar temats symbol, oavsett vilket tema som är valt.
/// Vald = temats aktiva yta, övriga = temats vilande yta.
class _ThemeButton extends StatelessWidget {
  const _ThemeButton({required this.choice, required this.on, required this.onTap});
  final ThemeChoice choice;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: '${choice.label} theme',
          child: GestureDetector(
            onTap: onTap,
            child: Theme(
              data: themeDataFor(choice.theme),
              child: Builder(builder: (context) {
                final c = context.chain;
                final text = Theme.of(context).textTheme;
                return SizedBox(
                  height: 56,
                  child: Raised(
                    material: on ? c.raisedActive : c.raisedIdle,
                    padding: EdgeInsets.zero,
                    child: _fit(Text(choice.label, style: text.labelLarge!.copyWith(color: on ? c.textStrong : c.accent))),
                  ),
                );
              }),
            ),
          ),
        ),
      );
}

/// Etiketten krymper hellre än bryts (Cinzel är bredare än Saira:
/// "COSMIC HORROR" bröts mot vänsterkanten, build 90).
Widget _fit(Widget label) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: label)),
    );

Future<void> _askRestSecs(BuildContext context, AppController app, UserSettings s) async {
  // Ingen dispose: dialogens stängningsanimation läser fältet efter pop.
  final field = TextEditingController(text: '${s.restTimerSecs}');
  final v = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Rest time'),
      content: TextField(
        controller: field,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(suffixText: 'seconds', helperText: '$kMinRestSecs–$kMaxRestSecs seconds'),
        onSubmitted: (t) => Navigator.pop(ctx, int.tryParse(t)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, int.tryParse(field.text)), child: const Text('Save')),
      ],
    ),
  );
  if (v != null) await app.updateSettings(_copy(s, timerSecs: clampRestSecs(v)));
}

/// Vilotimerns signal tänder skärmen. ON kräver en behörighet som Samsung kan
/// ha stängt av — då öppnas Androids sida för den (Niklas 2026-10-05: knappen
/// var för subtil, ska se ut som resten).
class _WakeScreenSection extends StatefulWidget {
  const _WakeScreenSection({required this.app, required this.settings});
  final AppController app;
  final UserSettings settings;

  @override
  State<_WakeScreenSection> createState() => _WakeScreenSectionState();
}

class _WakeScreenSectionState extends State<_WakeScreenSection> with WidgetsBindingObserver {
  /// Androids svar per behörighet (null = okänt). Läses av när sidan öppnas
  /// och när man kommer tillbaka från Androids inställningssida.
  /// [_granted] = låsskärmen (helskärm), [_overlay] = ovanpå andra appar.
  bool? _granted;
  bool? _overlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final alarm = widget.app.restTimer.alarm;
    final g = await alarm.canWakeScreen();
    final o = await alarm.canOverlay();
    if (!mounted) return;
    setState(() {
      _granted = g;
      _overlay = o;
    });
  }

  /// ON: frågar efter det som saknas, en behörighet i taget (Androids sidor).
  /// Kommer man tillbaka med något kvar säger statusraden det — ON igen tar nästa.
  Future<void> _on() async {
    await widget.app.updateSettings(_copy(widget.settings, wakeScreen: true));
    final alarm = widget.app.restTimer.alarm;
    final g = await alarm.requestWakeScreen();
    final o = g == true ? await alarm.requestOverlay() : await alarm.canOverlay();
    if (!mounted) return;
    setState(() {
      _granted = g == true;
      _overlay = o;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    String yes(bool? v) => v == null ? '—' : (v ? 'allowed' : 'not allowed');
    final missing = s.restWakeScreen && (_granted == false || _overlay == false);
    final status = !s.restWakeScreen
        ? 'Off: the alert beeps and vibrates, the screen stays dark.'
        : 'The rest-over screen takes over — also over other apps. The phone stays locked.\n'
            'Lock screen: ${yes(_granted)} · Over other apps: ${yes(_overlay)}'
            '${missing ? '\nTap ON to allow what is missing.' : ''}';
    return settingsSection(context, 'SCREEN WAKE-UP', [
      Row(children: [
        choiceButton(context, 'ON', s.restWakeScreen, _on),
        const SizedBox(width: 8),
        choiceButton(context, 'OFF', !s.restWakeScreen, () => widget.app.updateSettings(_copy(s, wakeScreen: false))),
      ]),
      const SizedBox(height: 8),
      Text(status, style: text.bodySmall!.copyWith(color: missing ? c.accent : c.textMuted)),
    ]);
  }
}

/// Haptik (Niklas 2026-10-06, väg A): eget reglage som respekterar telefonen.
/// ON med telefonens "vibration vid tryck" av → raden säger det och knappen
/// öppnar telefonens inställning. Läses av igen när man kommer tillbaka.
class _HapticsSection extends StatefulWidget {
  const _HapticsSection({required this.app, required this.settings});
  final AppController app;
  final UserSettings settings;

  @override
  State<_HapticsSection> createState() => _HapticsSectionState();
}

class _HapticsSectionState extends State<_HapticsSection> with WidgetsBindingObserver {
  bool? _phoneOn; // null = okänt

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final on = await Haptics.touchVibrationOn();
    if (mounted) setState(() => _phoneOn = on);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final blocked = s.haptics && _phoneOn == false;
    return settingsSection(context, 'VIBRATION', [
      Row(children: [
        choiceButton(context, 'ON', s.haptics, () {
          widget.app.updateSettings(s.copyWith(haptics: true));
          HapticFeedback.mediumImpact(); // känn efter direkt (inställningen hinner inte sparas först)
        }),
        const SizedBox(width: 8),
        choiceButton(context, 'OFF', !s.haptics, () => widget.app.updateSettings(s.copyWith(haptics: false))),
      ]),
      const SizedBox(height: 8),
      Text(
        !s.haptics
            ? 'Off: The Chain never vibrates on taps, even if your phone does.'
            : blocked
                ? 'Touch vibration is off on this phone, so nothing is felt. Turn it on in the phone settings.'
                : 'A short tap on LOG, DONE, FINISH and when a round is complete.',
        style: text.bodySmall!.copyWith(color: blocked ? c.accent : c.textMuted),
      ),
      if (blocked) ...[
        const SizedBox(height: 10),
        const GhostButton(label: 'OPEN PHONE SETTINGS', onTap: Haptics.openSoundSettings),
      ],
    ]);
  }
}

class TrainingSettingsScreen extends StatelessWidget {
  const TrainingSettingsScreen({super.key, required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) => SettingsPage(
        app: app,
        title: 'TRAINING & APP FUNCTIONS',
        builder: (context, app) {
          final s = app.repo!.settings();
          return [
            settingsSection(context, 'WEIGHT UNIT', [
              Row(children: [
                choiceButton(context, 'KG', s.weightUnit == WeightUnit.kg, () => app.updateSettings(_copy(s, w: WeightUnit.kg))),
                const SizedBox(width: 8),
                choiceButton(context, 'LBS', s.weightUnit == WeightUnit.lbs, () => app.updateSettings(_copy(s, w: WeightUnit.lbs))),
              ]),
            ]),
            settingsSection(context, 'TEMPERATURE UNIT', [
              Row(children: [
                choiceButton(context, '°C', s.tempUnit == TempUnit.celsius, () => app.updateSettings(_copy(s, t: TempUnit.celsius))),
                const SizedBox(width: 8),
                choiceButton(context, '°F', s.tempUnit == TempUnit.fahrenheit, () => app.updateSettings(_copy(s, t: TempUnit.fahrenheit))),
              ]),
            ]),
            settingsSection(context, 'NOTE WHEN FINISHING', [
              Row(children: [
                choiceButton(context, 'ON', s.finishNote, () => app.updateSettings(_copy(s, finishNote: true))),
                const SizedBox(width: 8),
                choiceButton(context, 'OFF', !s.finishNote, () => app.updateSettings(_copy(s, finishNote: false))),
              ]),
              const SizedBox(height: 8),
              Text('FINISH SESSION asks "How did it feel?" (optional). The note shows in History and at the end of COPY.',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.chain.textMuted)),
            ]),
            settingsSection(context, 'REST TIMER', [
              Row(children: [
                choiceButton(context, 'ON', s.restTimerEnabled, () => app.updateSettings(_copy(s, timer: true))),
                const SizedBox(width: 8),
                choiceButton(context, 'OFF', !s.restTimerEnabled, () {
                  app.restTimer.stop();
                  app.updateSettings(_copy(s, timer: false));
                }),
              ]),
              if (s.restTimerEnabled) ...[
                const SizedBox(height: 12),
                // Fri tid (Niklas 2026-10-05): korta intensiva pass vill ha t.ex. 45 s.
                Row(children: [
                  SizedBox(
                    width: 64,
                    child: GhostButton(
                      label: '−15',
                      semanticLabel: '15 seconds shorter',
                      onTap: s.restTimerSecs <= kMinRestSecs
                          ? null
                          : () => app.updateSettings(_copy(s, timerSecs: clampRestSecs(s.restTimerSecs - 15))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _askRestSecs(context, app, s),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(border: Border.all(color: context.chain.borderStrong)),
                        alignment: Alignment.center,
                        child: Text(fmtRestChoice(s.restTimerSecs),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: GhostButton(
                      label: '+15',
                      semanticLabel: '15 seconds longer',
                      onTap: s.restTimerSecs >= kMaxRestSecs
                          ? null
                          : () => app.updateSettings(_copy(s, timerSecs: clampRestSecs(s.restTimerSecs + 15))),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('Tap the time to type exact seconds. Starts when you log a set, warm-ups included. Signals with sound and '
                    'vibration, also when the phone is locked or you are in another app.',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.chain.textMuted)),
              ],
            ]),
            if (s.restTimerEnabled) _WakeScreenSection(app: app, settings: s),
            _HapticsSection(app: app, settings: s),
          ];
        },
      );
}

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key, required this.app, this.devTools = false});
  final AppController app;
  final bool devTools;

  @override
  Widget build(BuildContext context) => SettingsPage(
        app: app,
        title: 'APPEARANCE',
        builder: (context, app) {
          final s = app.repo!.settings();
          final text = Theme.of(context).textTheme;
          final choices = [for (final t in themeChoices) if (devTools || !t.devOnly) t];
          final current = themeFor(s.theme, devTools: devTools);
          return [
            // Bara ett tema släppt → ingen väljare i stable.
            if (choices.length > 1)
              settingsSection(context, 'THEME', [
                Row(children: [
                  for (final (i, t) in choices.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _ThemeButton(
                      choice: t,
                      on: identical(t.theme, current),
                      onTap: () => app.updateSettings(s.copyWith(theme: t.id)),
                    ),
                  ],
                ]),
                if (devTools) ...[
                  const SizedBox(height: 8),
                  Text('DEV: unreleased themes are not in the stable build.', style: text.bodySmall),
                ],
              ]),
            settingsSection(context, 'BACKGROUND', [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.ambientEffects,
                onChanged: (v) => app.updateSettings(_copy(s, ambient: v)),
                title: Text('Moving background', style: text.titleMedium),
                subtitle: Text('The theme\'s moving background. Turn off to save battery.', style: text.bodySmall),
              ),
            ]),
          ];
        },
      );
}

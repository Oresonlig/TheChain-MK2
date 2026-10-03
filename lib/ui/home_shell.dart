/// Hemmet efter inloggning: fyra flikar i nederkant (Niklas: "smidigt att
/// navigera med tummen"). Aktiv flik bär den upphöjda Nanosuit-ytan.
library;

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../domain/domain.dart';
import '../theme/chain_theme.dart';
import '../theme/surfaces.dart';
import 'chain/chain_screen.dart';
import 'progress/progress_screen.dart';
import 'settings/settings_screen.dart';
import 'weight/weight_screen.dart';
import 'workout/workout_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.app, required this.email, required this.versionLabel});

  final AppController app;
  final String email;
  final String versionLabel;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  /// Tillbaka från bakgrunden → hämta det andra enheter ändrat.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: widget.app.onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChainScreen(app: widget.app, email: widget.email, buildLabel: widget.versionLabel),
      WeightScreen(app: widget.app),
      ProgressScreen(app: widget.app),
      SettingsScreen(app: widget.app, email: widget.email, versionLabel: widget.versionLabel),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: ListenableBuilder(
        listenable: widget.app,
        builder: (context, _) {
          final active = widget.app.repo?.activeWorkouts().firstOrNull;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            // Förslag (a), Niklas ja 2026-10-02: pågående pass nås med ett tryck
            // från vilken flik som helst. Kedjefliken har redan CONTINUE-knappen.
            if (active != null && _tab != 0) _ContinueBar(app: widget.app, workout: active),
            _NavBar(index: _tab, onTap: (i) => setState(() => _tab = i)),
          ]);
        },
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.app, required this.workout});
  final AppController app;
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final session = app.repo!.program().sessionById(workout.sessionId);
    final done = workout.exercises.where((e) => e.status != ExerciseStatus.open).length;
    return Semantics(
      button: true,
      label: 'Continue session',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final wc = app.openWorkout(workout.sessionId);
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WorkoutScreen(controller: wc)));
        },
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.success.withValues(alpha: .6))),
          ),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${(session?.name ?? workout.sessionId.value)} · $done/${workout.exercises.length}',
                style: text.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('CONTINUE', style: text.labelLarge!.copyWith(color: c.success)),
            Icon(Icons.chevron_right, color: c.success),
          ]),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.link, 'CHAIN'),
    (Icons.monitor_weight_outlined, 'WEIGHT'),
    (Icons.emoji_events_outlined, 'PROGRESS'),
    (Icons.settings_outlined, 'SETTINGS'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.accent.withValues(alpha: .5))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(children: [
            for (final (i, (icon, label)) in _items.indexed)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: SizedBox(
                      height: 58, // stor träffyta för tummen
                      child: i == index
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Raised(
                                material: c.raisedActive,
                                inset: 6,
                                padding: EdgeInsets.zero,
                                child: _content(icon, label, c.textStrong, text),
                              ),
                            )
                          : _content(icon, label, c.textMuted, text),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _content(IconData icon, String label, Color color, TextTheme text) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(label, style: text.labelSmall!.copyWith(color: color, fontSize: 10, letterSpacing: 1)),
        ]),
      );
}

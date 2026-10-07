/// Hemmet efter inloggning: fyra flikar i nederkant (Niklas: "smidigt att
/// navigera med tummen"). Aktiv flik bär den upphöjda Nanosuit-ytan.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../domain/domain.dart';
import '../theme/chain_theme.dart';
import '../theme/surfaces.dart';
import 'chain/chain_screen.dart';
import 'progress/progress_screen.dart';
import 'settings/settings_screen.dart';
import 'weight/weight_screen.dart';
import 'workout/rest_timer_bar.dart';
import 'workout/workout_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.app, required this.email, required this.versionLabel, this.devTools = false});

  final AppController app;
  final String email;
  final String versionLabel;

  /// DEV-/lokalt bygge (aldrig STABLE): testknappar som aldrig skriver data.
  final bool devTools;

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
    widget.app.addListener(_onApp);
  }

  @override
  void dispose() {
    widget.app.removeListener(_onApp);
    _lifecycle.dispose();
    super.dispose();
  }

  /// Rundan stängdes från en annan flik ("in progress"-bannern): till kedjan,
  /// där ROUND COMPLETE visas.
  void _onApp() {
    if (widget.app.pendingRound != null && _tab != 0 && mounted) setState(() => _tab = 0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChainScreen(
        app: widget.app,
        email: widget.email,
        buildLabel: widget.versionLabel,
        visible: _tab == 0,
        devTools: widget.devTools,
      ),
      WeightScreen(app: widget.app),
      ProgressScreen(app: widget.app),
      SettingsScreen(app: widget.app, email: widget.email, versionLabel: widget.versionLabel, devTools: widget.devTools),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: ListenableBuilder(
        listenable: widget.app,
        builder: (context, _) {
          final active = widget.app.repo?.activeWorkouts().firstOrNull;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            // Vilan och REST OVER syns på alla flikar — öppnas appen på kedjan
            // medan larmet ringer ska DISMISS finnas där (Niklas 2026-10-05).
            RestTimerBar(timer: widget.app.restTimer),
            // Förslag (a), Niklas ja 2026-10-02: pågående pass nås med ett tryck
            // från vilken flik som helst. Kedjefliken har redan CONTINUE-knappen.
            if (active != null && _tab != 0)
              _ContinueBar(app: widget.app, workout: active, onEnded: () => setState(() => _tab = 0)),
            _NavBar(index: _tab, onTap: (i) => setState(() => _tab = i)),
          ]);
        },
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.app, required this.workout, required this.onEnded});
  final AppController app;
  final Workout workout;

  /// Passet avslutades (eller kasserades) i passvyn: till kedjan, inte
  /// tillbaka till fliken passet öppnades från (Niklas 2026-10-07: FINISH
  /// "kastade in" honom i Settings).
  final VoidCallback onEnded;

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
        onTap: () async {
          final wc = app.openWorkout(workout.sessionId);
          await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WorkoutScreen(controller: wc, app: app)));
          // Bakåtpilen med passet kvar = stanna där man var.
          final stillActive = app.repo?.activeWorkouts().any((w) => w.id == workout.id) ?? false;
          if (!stillActive) onEnded();
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
                      child: i == index && c.navMark == NavMark.fang
                          ? Stack(clipBehavior: Clip.none, children: [
                              Positioned.fill(child: _content(icon, label, c.textStrong, text)),
                              const Positioned(top: -7, left: 0, right: 0, child: Center(child: _Fang())),
                            ])
                          : i == index
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

  static Widget _content(IconData icon, String label, Color color, TextTheme text) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(label, style: text.labelSmall!.copyWith(color: color, fontSize: 10, letterSpacing: 1)),
        ]),
      );
}

/// Cosmic Horror: aktiv flik = en huggtand ner från menyradens kant som
/// pulserar långsamt (MK1 chTabPulse 4,2 s). Stilla = full styrka.
class _Fang extends StatefulWidget {
  const _Fang();

  @override
  State<_Fang> createState() => _FangState();
}

class _FangState extends State<_Fang> with SingleTickerProviderStateMixin {
  late final _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _ctl.stop();
    } else if (!_ctl.isAnimating) {
      _ctl.repeat();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final still = !_ctl.isAnimating;
        final a = still ? 1.0 : .7 + .3 * (.5 + .5 * math.sin(_ctl.value * 2 * math.pi));
        return CustomPaint(size: const Size(16, 11), painter: _FangPainter(c.accent.withValues(alpha: a)));
      },
    );
  }
}

class _FangPainter extends CustomPainter {
  const _FangPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Lätt böjd tand, inte en rak triangel.
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..quadraticBezierTo(size.width * .62, size.height * .45, size.width * .5, size.height)
      ..quadraticBezierTo(size.width * .38, size.height * .45, 0, 0)
      ..close();
    canvas
      ..drawPath(p, Paint()
        ..color = color.withValues(alpha: color.a * .6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4))
      ..drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FangPainter old) => old.color != color;
}

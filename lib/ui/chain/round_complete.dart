/// "ROUND COMPLETE" — ett fönster med rundans summering (Niklas 2026-10-06:
/// "som ett litet pris i slutet av ett lopp"). Bokstäverna tänds en i taget
/// som en våg, kedjan pulserar, rundnumret flippar som en fallbladsklocka
/// (nya siffran faller ner över den gamla), sedan byggs kedjan upp igen en
/// bokstav i taget. En runda tar 8–9 dagar, så animationen får ta sin tid:
/// den går INTE att trycka bort och stänger sig själv. Minska rörelse: samma
/// fönster stilla, slutläget direkt.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/haptics.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';

class RoundComplete extends StatefulWidget {
  const RoundComplete({
    super.key,
    required this.summary,
    required this.letters,
    required this.restIds,
    required this.newPrs,
    required this.onDone,
  });

  final RoundSummary summary;

  /// Kedjans bokstäver i programordning (A, B, V …) och vilka som är vilodagar.
  final List<(SessionId, String)> letters;
  final Set<SessionId> restIds;
  final int newPrs;
  final VoidCallback onDone;

  @override
  State<RoundComplete> createState() => _RoundCompleteState();
}

/// Tidslinjen i millisekunder, räknad ur antalet bokstäver.
class _Timeline {
  _Timeline(int n) {
    waveEnd = waveStart + n * 150;
    pulseEnd = waveEnd + 400;
    flipStart = pulseEnd + 200;
    flipEnd = flipStart + 900;
    rebuildStart = flipEnd + 200;
    rebuildEnd = rebuildStart + n * 220;
    fadeStart = rebuildEnd + 1500;
    total = fadeStart + 500;
  }

  static const fadeIn = 500, waveStart = 600, statsStart = 300, statStep = 180;
  late final int waveEnd, pulseEnd, flipStart, flipEnd, rebuildStart, rebuildEnd, fadeStart, total;

  /// 0–1 mellan [a] och [b] vid tiden [ms].
  static double seg(double ms, int a, int b) => ((ms - a) / (b - a)).clamp(0.0, 1.0);
}

class _RoundCompleteState extends State<RoundComplete> with SingleTickerProviderStateMixin {
  late final _Timeline _tl = _Timeline(widget.letters.length);
  late final AnimationController _a = AnimationController(vsync: this, duration: Duration(milliseconds: _tl.total));
  bool _closing = false;
  bool _started = false;
  bool _still = false;
  bool _landed = false;
  Timer? _hold;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    Haptics.heavy(); // appens reglage + telefonens vibration vid tryck

    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      _hold = Timer(const Duration(seconds: 4), _close);
    } else {
      _a.addListener(_onTick);
      _a.forward().whenComplete(_close);
    }
  }

  /// Ett tungt "klack" när den nya siffran landar.
  void _onTick() {
    if (!_landed && _a.value * _tl.total >= _tl.flipEnd) {
      _landed = true;
      Haptics.medium();
    }
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    // Absorberar alla tryck: går inte att trycka bort, och inget under nås.
    return AbsorbPointer(
      child: _still
          ? _frame(context, c, 0, still: true)
          : AnimatedBuilder(animation: _a, builder: (context, _) => _frame(context, c, _a.value * _tl.total)),
    );
  }

  Widget _frame(BuildContext context, ChainTheme c, double ms, {bool still = false}) {
    final text = Theme.of(context).textTheme;
    final s = widget.summary;
    final tl = _tl;
    final n = widget.letters.length;

    final fadeIn = still ? 1.0 : _Timeline.seg(ms, 0, _Timeline.fadeIn);
    final fadeOut = still ? 0.0 : _Timeline.seg(ms, tl.fadeStart, tl.total);
    final opacity = (fadeIn * (1 - fadeOut)).clamp(0.0, 1.0);
    final wave = still ? 1.0 : _Timeline.seg(ms, _Timeline.waveStart, tl.waveEnd);
    final p = _Timeline.seg(ms, tl.waveEnd, tl.pulseEnd);
    final pulse = still ? 1.0 : 1 + .06 * math.sin(p * math.pi);
    final flip = still ? 1.0 : Curves.easeIn.transform(_Timeline.seg(ms, tl.flipStart, tl.flipEnd));
    final reset = still || ms >= tl.flipEnd;
    final rebuild = still ? 1.0 : _Timeline.seg(ms, tl.rebuildStart, tl.rebuildEnd);

    final days = s.end.difference(s.start).inDays + 1;
    final stats = [
      ('${s.sessions}', s.sessions == 1 ? 'SESSION' : 'SESSIONS'),
      ('${s.sets}', 'SETS'),
      ('${widget.newPrs}', widget.newPrs == 1 ? 'NEW PR' : 'NEW PRS'),
      ('$days', days == 1 ? 'DAY' : 'DAYS'),
      ('${s.restDays}', s.restDays == 1 ? 'REST DAY' : 'REST DAYS'),
      ('${s.skipped}', 'SKIPPED'),
    ];

    return Opacity(
      opacity: opacity,
      child: ColoredBox(
        color: c.background.withValues(alpha: .72),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Transform.scale(
                scale: .94 + .06 * Curves.easeOut.transform(fadeIn),
                child: Glass(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('ROUND', style: text.labelLarge!.copyWith(color: c.textMuted, letterSpacing: 6)),
                    const SizedBox(height: 10),
                    _FlipCounter(from: s.round, to: s.round + 1, t: flip),
                    const SizedBox(height: 12),
                    // Stilla läge: båda raderna på en gång (annars syns aldrig "COMPLETE").
                    if (still) ...[
                      _complete(context, c, s.round),
                      const SizedBox(height: 4),
                      _fresh(context, c),
                    ] else
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: reset
                            ? KeyedSubtree(key: const ValueKey(true), child: _fresh(context, c))
                            : KeyedSubtree(key: const ValueKey(false), child: _complete(context, c, s.round)),
                      ),
                    const SizedBox(height: 18),
                    // Summeringen: tänds en ruta i taget — "priset".
                    for (var row = 0; row < 2; row++)
                      Padding(
                        padding: EdgeInsets.only(top: row == 0 ? 0 : 12),
                        child: Row(children: [
                          for (var col = 0; col < 3; col++)
                            Expanded(
                              child: Opacity(
                                opacity: still
                                    ? 1
                                    : _Timeline.seg(
                                        ms,
                                        _Timeline.statsStart + (row * 3 + col) * _Timeline.statStep,
                                        _Timeline.statsStart + (row * 3 + col + 1) * _Timeline.statStep + 200,
                                      ),
                                child: _stat(context, c, stats[row * 3 + col].$1, stats[row * 3 + col].$2,
                                    warn: row * 3 + col == 5 && s.skipped > 0),
                              ),
                            ),
                        ]),
                      ),
                    const SizedBox(height: 22),
                    Transform.scale(
                      scale: pulse,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (i, (id, letter)) in widget.letters.indexed)
                            _letter(context, c, letter, i, n,
                                rest: widget.restIds.contains(id), lit: !reset && wave * n > i, reset: reset, rebuild: rebuild),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _complete(BuildContext context, ChainTheme c, int round) => Text(
        'ROUND $round COMPLETE',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium!.copyWith(
          color: c.accent,
          letterSpacing: 3,
          shadows: [Shadow(color: c.accent.withValues(alpha: .6), blurRadius: 16)],
        ),
      );

  Widget _fresh(BuildContext context, ChainTheme c) => Text(
        'A fresh chain — next up: ${widget.letters.first.$2}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.textBody),
      );

  Widget _stat(BuildContext context, ChainTheme c, String value, String label, {bool warn = false}) {
    final text = Theme.of(context).textTheme;
    return Column(children: [
      Text(value, style: text.headlineSmall!.copyWith(color: warn ? c.fail : c.textStrong)),
      const SizedBox(height: 2),
      Text(label, textAlign: TextAlign.center, style: text.labelSmall!.copyWith(color: c.textMuted, letterSpacing: 1.5)),
    ]);
  }

  /// Före omladdningen: tänds av vågen. Efter: borta, och byggs upp igen en
  /// bokstav i taget (skalas in från 60 %).
  Widget _letter(BuildContext context, ChainTheme c, String letter, int i, int n,
      {required bool rest, required bool lit, required bool reset, required double rebuild}) {
    final text = Theme.of(context).textTheme;
    var scale = 1.0, opacity = 1.0;
    if (reset) {
      final k = (rebuild * n - i).clamp(0.0, 1.0);
      opacity = k;
      scale = .6 + .4 * Curves.easeOutBack.transform(k);
    }
    final color = rest ? c.restGold : (lit ? c.textStrong : c.accent);
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Raised(
            material: lit ? c.raisedActive : c.raisedIdle,
            padding: EdgeInsets.zero,
            child: Center(child: Text(letter, style: text.titleMedium!.copyWith(color: color))),
          ),
        ),
      ),
    );
  }
}

/// Rundnumret som fallbladsklocka: bara siffror som ändras flippar (18 → 19
/// flippar entalet, 19 → 20 båda).
class _FlipCounter extends StatelessWidget {
  const _FlipCounter({required this.from, required this.to, required this.t});

  final int from, to;
  final double t;

  @override
  Widget build(BuildContext context) {
    final b = '$to', a = '$from'.padLeft(b.length);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < b.length; i++)
        Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
          child: _FlipDigit(from: a[i], to: b[i], t: a[i] == b[i] ? 1 : t),
        ),
    ]);
  }
}

/// En fallbladssiffra. Första halvan: gamla siffrans övre halva fälls ner och
/// visar den nya bakom. Andra halvan: nya siffrans nedre halva faller ner över
/// den gamla. Glipan mellan halvorna är klockans skarv.
class _FlipDigit extends StatelessWidget {
  const _FlipDigit({required this.from, required this.to, required this.t});

  final String from, to;
  final double t;

  static const _w = 58.0, _h = 84.0, _gap = 2.0;

  Widget _tile(BuildContext context, String d) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    return Container(
      width: _w,
      height: _h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.raisedIdle.top, c.raisedIdle.bottom],
        ),
        border: Border.all(color: c.raisedIdle.edge),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        d.trim(),
        style: text.displaySmall!.copyWith(
          color: c.textStrong,
          fontSize: 58,
          height: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
          shadows: [Shadow(color: c.accent.withValues(alpha: .45), blurRadius: 14)],
        ),
      ),
    );
  }

  Widget _half(BuildContext context, String d, {required bool top}) => ClipRect(
        child: Align(
          alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
          heightFactor: .5,
          child: _tile(context, d),
        ),
      );

  Matrix4 _fold(double angle) => Matrix4.identity()
    ..setEntry(3, 2, .004) // perspektiv
    ..rotateX(angle);

  @override
  Widget build(BuildContext context) {
    final first = t < .5;
    final k = first ? t * 2 : (t - .5) * 2; // 0–1 inom halvan
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(children: [
        _half(context, t <= 0 ? from : to, top: true),
        if (t > 0 && first)
          Transform(
            alignment: Alignment.bottomCenter,
            transform: _fold(k * math.pi / 2), // överkanten fälls mot tittaren
            child: _half(context, from, top: true),
          ),
      ]),
      const SizedBox(height: _gap),
      Stack(children: [
        _half(context, t >= 1 ? to : from, top: false),
        if (!first && t < 1)
          Transform(
            alignment: Alignment.topCenter,
            transform: _fold(-(1 - k) * math.pi / 2), // faller ner från vågrätt, mot tittaren
            child: _half(context, to, top: false),
          ),
      ]),
    ]);
  }
}

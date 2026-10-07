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
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/haptics.dart';
import '../../domain/domain.dart';
import '../../theme/ambient_life.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
import 'chain_strip.dart' show ClawPainter, ScarPainter, SkippedLetter, TabMark;

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
  _Timeline(int n, {this.heartbeat = false}) {
    waveEnd = heartbeat ? waveStart + (n + 1) ~/ 2 * beatMs : waveStart + n * 150;
    pulseEnd = waveEnd + 400;
    flipStart = pulseEnd + 200;
    flipEnd = flipStart + 900;
    rebuildStart = flipEnd + 200;
    rebuildEnd = rebuildStart + n * 220;
    fadeStart = rebuildEnd + 1500;
    total = fadeStart + 500;
  }

  static const fadeIn = 500, waveStart = 600, statsStart = 300, statStep = 180;

  /// Hjärtslaget: ett slag (lub + dub) tänder två bokstäver.
  /// ~130 slag/min — ett upphetsat hjärta, och fönstret håller sig kring 8 s.
  static const beatMs = 460, dubMs = 150;
  final bool heartbeat;
  late final int waveEnd, pulseEnd, flipStart, flipEnd, rebuildStart, rebuildEnd, fadeStart, total;

  /// När bokstav [i] tänds av hjärtslaget: jämna på lub, udda på dub.
  static int litAt(int i) => waveStart + i ~/ 2 * beatMs + (i.isOdd ? dubMs : 0);

  /// 0–1 mellan [a] och [b] vid tiden [ms].
  static double seg(double ms, int a, int b) => ((ms - a) / (b - a)).clamp(0.0, 1.0);
}

class _RoundCompleteState extends State<RoundComplete> with SingleTickerProviderStateMixin {
  late final bool _heart = context.chain.details.round == RoundStyle.heartbeat;
  late final _Timeline _tl = _Timeline(widget.letters.length, heartbeat: _heart);
  late final AnimationController _a = AnimationController(vsync: this, duration: Duration(milliseconds: _tl.total));
  bool _closing = false;
  bool _started = false;
  bool _still = false;
  bool _landed = false;
  int _beaten = 0;
  Timer? _hold, _dub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Appens reglage + telefonens vibration vid tryck. Hjärtslag: lub-dub.
    _heart ? _lubDub() : Haptics.heavy();

    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      _hold = Timer(const Duration(seconds: 4), _close);
    } else {
      _a.addListener(_onTick);
      _a.forward().whenComplete(_close);
    }
  }

  void _lubDub() {
    Haptics.heavy();
    _dub?.cancel();
    _dub = Timer(const Duration(milliseconds: 140), Haptics.medium);
  }

  /// Ett tungt "klack" när den nya siffran landar. Hjärtslag: varje slag
  /// känns och går genom ådrorna i bakgrunden.
  void _onTick() {
    final ms = _a.value * _tl.total;
    if (_heart) {
      while (_beaten < widget.letters.length && ms >= _Timeline.litAt(_beaten)) {
        if (_beaten.isEven) {
          Haptics.medium();
          AmbientLife.heartbeat();
        } else {
          Haptics.light();
        }
        _beaten++;
      }
    }
    if (!_landed && ms >= _tl.flipEnd) {
      _landed = true;
      if (_heart) {
        _lubDub();
        AmbientLife.heartbeat();
      } else {
        Haptics.medium();
      }
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
    _dub?.cancel();
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
    double thump(double c, double w) => math.exp(-math.pow((p - c) / w, 2).toDouble());
    final pulse = still
        ? 1.0
        : _heart
            ? 1 + .05 * (thump(.25, .12) + .6 * thump(.65, .12)) // kedjan slår: lub-dub
            : 1 + .06 * math.sin(p * math.pi);
    final flip = still ? 1.0 : Curves.easeIn.transform(_Timeline.seg(ms, tl.flipStart, tl.flipEnd));
    final reset = still || ms >= tl.flipEnd;
    final rebuild = still ? 1.0 : _Timeline.seg(ms, tl.rebuildStart, tl.rebuildEnd);

    final days = s.end.difference(s.start).inDays + 1;
    // Vilka pass som hoppades över, i kedjans ordning: "C · D".
    final skippedLetters = [
      for (final (id, letter) in widget.letters)
        if (s.skippedIds.contains(id)) letter,
    ].join(' · ');
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
                    _FlipCounter(from: s.round, to: s.round + 1, t: flip, lid: _heart),
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
                        // Överkant: "C · D" under SKIPPED får inte lyfta radens siffror.
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                                    warn: row * 3 + col == 5 && s.skipped > 0,
                                    detail: row * 3 + col == 5 ? skippedLetters : null),
                              ),
                            ),
                        ]),
                      ),
                    const SizedBox(height: 22),
                    Transform.scale(
                      scale: pulse,
                      // Hjärtslag: bokstäverna sitter på en åder (stumpen före
                      // varje böna) i stället för mellanrum.
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: _heart ? 0 : 8,
                        runSpacing: 8,
                        children: [
                          for (final (i, (id, letter)) in widget.letters.indexed)
                            _letter(context, c, id, letter, i, n,
                                rest: widget.restIds.contains(id),
                                lit: !reset && (_heart ? (still || ms >= _Timeline.litAt(i)) : wave * n > i),
                                litAge: _heart && !still ? ms - _Timeline.litAt(i) : null,
                                skipped: s.skippedIds.contains(id),
                                reset: reset,
                                rebuild: rebuild),
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

  Widget _stat(BuildContext context, ChainTheme c, String value, String label, {bool warn = false, String? detail}) {
    final text = Theme.of(context).textTheme;
    return Column(children: [
      Text(value, style: text.headlineSmall!.copyWith(color: warn ? c.fail : c.textStrong)),
      const SizedBox(height: 2),
      Text(label, textAlign: TextAlign.center, style: text.labelSmall!.copyWith(color: c.textMuted, letterSpacing: 1.5)),
      if (detail != null && detail.isNotEmpty)
        Text(detail, textAlign: TextAlign.center, style: text.labelSmall!.copyWith(color: c.fail, letterSpacing: 1.5)),
    ]);
  }

  /// Före omladdningen: tänds av vågen — ett överhoppat pass tänds INTE utan
  /// får temats överhopps-markering (Nanosuit: X), som i kedjan (Niklas
  /// 2026-10-06: "kryssa för de passen jag hoppade över"). Efter: borta, och
  /// byggs upp igen en bokstav i taget (skalas in från 60 %), alla rena.
  ///
  /// Markörerna är kedjans egna (Niklas 2026-10-07: inte lånade): samma form
  /// som fliken i kedjeremsan, och temats markering över hela bönan — ärr på
  /// det gjorda, klösmärken på det överhoppade — där temat har en.
  Widget _letter(BuildContext context, ChainTheme c, SessionId id, String letter, int i, int n,
      {required bool rest,
      required bool lit,
      required double? litAge,
      required bool skipped,
      required bool reset,
      required double rebuild}) {
    final text = Theme.of(context).textTheme;
    var scale = 1.0, opacity = 1.0;
    if (reset) {
      final k = (rebuild * n - i).clamp(0.0, 1.0);
      opacity = k;
      scale = _heart
          // Växer fram: sväller upp ur ingenting med ett darr som klingar av.
          ? .3 + .7 * Curves.easeOut.transform(k) + .07 * math.sin(k * 3 * math.pi) * (1 - k)
          : .6 + .4 * Curves.easeOutBack.transform(k);
    } else if (litAge != null && litAge >= 0) {
      scale = 1 + .14 * math.exp(-litAge / 140); // slaget går igenom bönan
    }
    final crossed = lit && skipped; // vågen har nått ett överhoppat pass
    final on = lit && !skipped;
    final color = crossed ? c.textMuted : (rest ? c.restGold : (on ? c.textStrong : c.accent));
    final glyph = Text(letter, style: text.titleMedium!.copyWith(color: color));
    final seed = shapeSeed(id.value);
    final bean = SizedBox(
      width: 44,
      height: 44,
      child: TabMark(
        shape: raisedShape(c, seed: seed),
        painter: crossed
            ? (c.skippedMark == SkippedMark.claw ? ClawPainter(c.fail, tab: true) : null)
            : on && c.doneMark == DoneMark.scar
                ? ScarPainter(c.accent)
                : null,
        child: Raised(
          material: on ? c.raisedActive : c.raisedIdle,
          seed: seed,
          padding: EdgeInsets.zero,
          child: Center(
            child: crossed && c.skippedMark == SkippedMark.cross
                ? SkippedLetter(mark: c.skippedMark, color: c.fail, child: glyph)
                : glyph,
          ),
        ),
      ),
    );
    return Opacity(
      opacity: opacity,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_heart && i > 0) _VeinStub(lit: lit || reset),
        Transform.scale(scale: scale, child: bean),
      ]),
    );
  }
}

/// Åderstumpen mellan två bönor i hjärtslagets kedja: mörk tills slaget har
/// gått igenom, sedan lyser den.
class _VeinStub extends StatelessWidget {
  const _VeinStub({required this.lit});
  final bool lit;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 12,
        height: 44,
        child: CustomPaint(painter: _VeinStubPainter(lit: lit, theme: context.chain)),
      );
}

class _VeinStubPainter extends CustomPainter {
  _VeinStubPainter({required this.lit, required this.theme});
  final bool lit;
  final ChainTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final path = Path()
      ..moveTo(-2, cy)
      ..cubicTo(size.width * .3, cy - 3, size.width * .7, cy + 3, size.width + 2, cy);
    if (lit) {
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = theme.hexEnergy.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = lit ? theme.hexEnergy.withValues(alpha: .85) : theme.hexLine);
  }

  @override
  bool shouldRepaint(_VeinStubPainter old) => old.lit != lit || old.theme != theme;
}

/// Rundnumret som fallbladsklocka: bara siffror som ändras flippar (18 → 19
/// flippar entalet, 19 → 20 båda).
class _FlipCounter extends StatelessWidget {
  const _FlipCounter({required this.from, required this.to, required this.t, this.lid = false});

  final int from, to;
  final double t;

  /// Hjärtslag (Cosmic): siffran blinkar fram bakom ett ögonlock i stället.
  final bool lid;

  @override
  Widget build(BuildContext context) {
    final b = '$to', a = '$from'.padLeft(b.length);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < b.length; i++)
        Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
          child: lid
              ? _LidDigit(from: a[i], to: b[i], t: a[i] == b[i] ? 1 : t)
              : _FlipDigit(from: a[i], to: b[i], t: a[i] == b[i] ? 1 : t),
        ),
    ]);
  }
}

/// En siffra bakom ett ögonlock: locken sluter sig över den gamla siffran,
/// ligger stängda ett ögonblick, och öppnar sig över den nya.
class _LidDigit extends StatelessWidget {
  const _LidDigit({required this.from, required this.to, required this.t});

  final String from, to;
  final double t;

  @override
  Widget build(BuildContext context) {
    final closed = t < .45
        ? Curves.easeIn.transform(t / .45)
        : t < .55
            ? 1.0
            : 1 - Curves.easeOut.transform((t - .55) / .45);
    return Stack(children: [
      _FlipDigit.tile(context, t < .5 ? from : to), // hel ruta, ingen fallbladsskarv
      if (closed > 0)
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CustomPaint(painter: _LidPainter(closed: closed, theme: context.chain)),
          ),
        ),
    ]);
  }
}

class _LidPainter extends CustomPainter {
  _LidPainter({required this.closed, required this.theme});
  final double closed;
  final ChainTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, k = closed;
    // Lockets kant: rak när det är öppet eller stängt, buktar mitt i rörelsen.
    final e = k * h / 2, bulge = k * (1 - k) * h * .6;
    // Huden: mörk vid roten, ljusare mot kanten — ett lock som syns, inte
    // bara en linje. Följer kanten när den rör sig.
    final m = theme.raisedActive;
    final reach = math.max(1.0, e + bulge);
    final upperSkin = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, reach), [theme.background, m.top]);
    final lowerSkin = Paint()
      ..shader = ui.Gradient.linear(Offset(0, h), Offset(0, h - reach), [theme.background, m.top]);
    // Lockets skugga på siffran under.
    final shade = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Colors.black.withValues(alpha: .55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final upper = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, e)
      ..quadraticBezierTo(w / 2, e + bulge, 0, e)
      ..close();
    final lower = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(w, h - e)
      ..quadraticBezierTo(w / 2, h - e - bulge, 0, h - e)
      ..close();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = theme.accent.withValues(alpha: .8);
    final upperEdge = Path()
      ..moveTo(0, e)
      ..quadraticBezierTo(w / 2, e + bulge, w, e);
    final lowerEdge = Path()
      ..moveTo(0, h - e)
      ..quadraticBezierTo(w / 2, h - e - bulge, w, h - e);
    canvas
      ..drawPath(upperEdge.shift(const Offset(0, 3)), shade)
      ..drawPath(lowerEdge.shift(const Offset(0, -3)), shade)
      ..drawPath(upper, upperSkin)
      ..drawPath(lower, lowerSkin)
      ..drawPath(upperEdge, edge)
      ..drawPath(lowerEdge, edge);
  }

  @override
  bool shouldRepaint(_LidPainter old) => old.closed != closed || old.theme != theme;
}

/// En fallbladssiffra. Första halvan: gamla siffrans övre halva fälls ner och
/// visar den nya bakom. Andra halvan: nya siffrans nedre halva faller ner över
/// den gamla. Glipan mellan halvorna är klockans skarv.
class _FlipDigit extends StatelessWidget {
  const _FlipDigit({required this.from, required this.to, required this.t});

  final String from, to;
  final double t;

  static const _w = 58.0, _h = 84.0, _gap = 2.0;

  static Widget tile(BuildContext context, String d) {
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
          child: tile(context, d),
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

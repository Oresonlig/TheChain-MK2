/// Kedjans slider. TVÅ KANALER (MK1-lärdom 3.81.1 — blanda dem aldrig):
///   * STATUS bor på BOKSTAVEN: kvar = temats accent, avklarad = dämpad men
///     ALDRIG osynlig, vilodag = guld (dämpat guld när avklarad), överhoppad =
///     dämpad som avklarad + temats [SkippedMark] (Nanosuit: X över bokstaven).
///   * NÄRHET bor på BEHÅLLAREN: vald = upphöjd aktiv yta + fullt namn,
///     granne ("på glänt") = kortnamn, övriga = bara bokstav.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../theme/active_mark.dart';
import '../../theme/chain_theme.dart';
import '../../theme/eye_tab.dart';
import '../../theme/surfaces.dart';

class ChainStrip extends StatefulWidget {
  const ChainStrip({
    super.key,
    required this.program,
    required this.chain,
    required this.selected,
    required this.onSelect,
    this.inProgress = const {},
    this.animate = true,
  });

  final Program program;
  final ChainState chain;
  final SessionId selected;
  final ValueChanged<SessionId> onSelect;
  final Set<SessionId> inProgress;

  /// Användarens ambient-inställning (av = pågående pass markeras stillastående).
  final bool animate;

  /// Visningsbokstav: pass får A, B, C … i ordning; vilodagar ALLTID "V".
  static Map<SessionId, String> letters(Program p) {
    const abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    var i = 0;
    return {for (final s in p.sessions) s.id: s.isRest ? 'V' : abc[(i++) % abc.length]};
  }

  @override
  State<ChainStrip> createState() => _ChainStripState();
}

class _ChainStripState extends State<ChainStrip> {
  final _keys = <SessionId, GlobalKey>{};

  @override
  void didUpdateWidget(ChainStrip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _scrollToSelected();
  }

  @override
  void initState() {
    super.initState();
    _scrollToSelected();
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[widget.selected]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: .3, duration: const Duration(milliseconds: 250));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final base = Theme.of(context).textTheme.labelLarge!.copyWith(
      letterSpacing: 1.2,
      fontVariations: const [FontVariation.weight(700), FontVariation.width(80)],
    );
    final sessions = widget.program.sessions;
    final selIndex = sessions.indexWhere((s) => s.id == widget.selected);
    final letter = ChainStrip.letters(widget.program);

    // Ögonfliken (Cosmic) behöver plats utanför sig själv — innanför scrollen,
    // som annars klipper vid flikens kant (samma mekanism som fyrkantspulsen).
    final eyeRoom = c.activeMark == ActiveMark.eye && widget.inProgress.isNotEmpty;
    return Glass(
      padding: EdgeInsets.symmetric(vertical: eyeRoom ? 0 : 10, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(vertical: eyeRoom ? eyeTabRoom : 0, horizontal: eyeRoom ? 8 : 0),
        child: Row(children: [
          for (final (i, s) in sessions.indexed)
            () {
              final skipped = widget.chain.isSkipped(s.id);
              // Överhoppat = hanterat: dämpas som avklarat, plus temats markering.
              final done = widget.chain.isDone(s.id) || skipped;
              final distance = (i - selIndex).abs();
              final selected = distance == 0;
              // STATUS → bokstavens färg.
              final letterColor = s.isRest
                  ? (done ? c.restGold.withValues(alpha: .45) : c.restGold)
                  : (done ? c.textFaint : c.accent);
              final letterText = Text(letter[s.id]!, style: base.copyWith(fontSize: 20, color: selected && !done ? c.textStrong : letterColor));
              // NÄRHET → behållarens yta och hur mycket namn som visas.
              final material = selected ? c.raisedActive : (done ? c.raisedDone : c.raisedIdle);
              final name = s.isRest
                  ? null
                  : selected
                      ? s.name.toUpperCase()
                      : distance == 1
                          ? (s.name.length <= 3 ? s.name : s.name.substring(0, 3)).toUpperCase()
                          : null;
              final running = widget.inProgress.contains(s.id);
              final eyes = running && c.activeMark == ActiveMark.eye;
              final shape = raisedShape(c, seed: shapeSeed(s.id.value));
              final tab = TabMark(
                shape: shape,
                painter: skipped
                    ? (c.skippedMark == SkippedMark.claw
                        ? ClawPainter(c.fail, tab: true, seed: widget.chain.marks[s.id] ?? 0)
                        : null)
                    : done && c.doneMark == DoneMark.scar
                        ? ScarPainter(c.accent, seed: widget.chain.marks[s.id] ?? 0)
                        : null,
                child: Raised(
                  material: material,
                  seed: shapeSeed(s.id.value),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    // Bokstavsmarkering bara för teman utan eget fliklager.
                    if (skipped && c.skippedMark == SkippedMark.cross)
                      SkippedLetter(mark: c.skippedMark, color: c.textMuted, child: letterText)
                    else
                      letterText,
                    if (name != null) ...[
                      const SizedBox(width: 10),
                      Text(name, style: base.copyWith(color: selected ? c.textStrong : letterColor)),
                    ],
                    // Grön prick = pågår. Ögonen (Cosmic) ersätter den.
                    if (running && !eyes) ...[
                      const SizedBox(width: 6),
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle)),
                    ],
                  ]),
                ),
              );
              return Padding(
                key: _keys.putIfAbsent(s.id, GlobalKey.new),
                padding: const EdgeInsets.only(right: 6),
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: '${s.isRest ? 'Forced rest day' : s.name}${running ? ', in progress' : skipped ? ', skipped' : done ? ', done' : ''}',
                  child: GestureDetector(
                    onTap: () => widget.onSelect(s.id),
                    // Pågående pass: temats markering runt fliken (Nanosuit:
                    // puls). Cosmic Horror: ögon över hela fliken (EyeTab).
                    child: eyes
                        ? EyeTab(
                            key: ValueKey(EyeChoice.current),
                            variant: EyeChoice.current,
                            shape: shape,
                            membrane: material,
                            animate: widget.animate,
                            child: tab,
                          )
                        : ActiveMarkFrame(active: running, animate: widget.animate, child: tab),
                  ),
                ),
              );
            }(),
        ]),
      ),
    );
  }
}

/// Status-kanalen för ett överhoppat pass: temats [SkippedMark] ritad ÖVER
/// bokstaven (aldrig på behållaren — där bor närheten).
class SkippedLetter extends StatelessWidget {
  const SkippedLetter({super.key, required this.mark, required this.color, required this.child});

  final SkippedMark mark;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => switch (mark) {
        SkippedMark.cross => CustomPaint(foregroundPainter: _CrossPainter(color), child: child),
        // Klösmärkena har alltid temats fail-färg — det är deras betydelse.
        SkippedMark.claw => CustomPaint(foregroundPainter: ClawPainter(context.chain.fail), child: child),
      };
}

/// Status som eget lager över HELA fliken (Niklas 2026-10-06: rivmärkena var
/// för små på bokstaven). Klippt till flikens form. Flikens yta, kant och
/// storlek rörs inte — där bor närheten, och den kanalen blandas aldrig.
class TabMark extends StatelessWidget {
  const TabMark({super.key, required this.shape, required this.painter, required this.child});

  final ShapeBorder shape;
  final CustomPainter? painter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = painter;
    if (p == null) return child;
    return Stack(children: [
      child,
      Positioned.fill(
        child: IgnorePointer(
          child: ClipPath(clipper: ShapeBorderClipper(shape: shape), child: CustomPaint(painter: p)),
        ),
      ),
    ]);
  }
}

/// Ärrens och klösmärkenas variant (Niklas 2026-10-09: fem var, så att inte
/// varje avklarat/överhoppat pass ser likadant ut). Fröet är passets
/// historikpost ([ChainState.marks]) — samma pass ser likadant ut efter
/// omstart och i ROUND COMPLETE, nästa runda får ett nytt. Variant och
/// småjitter (läge, böj, vinkel) ur samma frö.
class MarkChoice {
  MarkChoice._();
  static const variants = 5;

  /// DEV-knappen: samma variant på alla flikar (null = följ posten).
  static int? forced;
  static void cycle() => forced = switch (forced) {
        null => 0,
        final f when f + 1 < variants => f + 1,
        _ => null,
      };

  /// Darts Random ger nästan samma första tal för närliggande frön — fröet
  /// (en tidsstämpel) blandas först (murmur3 fmix32).
  static int mix(int x) {
    var h = (x ^ (x >> 32)) & 0xffffffff;
    h = ((h ^ (h >> 16)) * 0x85ebca6b) & 0xffffffff;
    h = ((h ^ (h >> 13)) * 0xc2b2ae35) & 0xffffffff;
    return h ^ (h >> 16);
  }

  static (int, math.Random) pick(int seed) {
    final h = mix(seed);
    return (forced ?? h % variants, math.Random(h));
  }
}

/// Klösmärken snett över ytan, spetsiga i ändarna. [tab] = över en hel flik
/// (grövre blad, lite bredare), annars över en bokstav. Varianter
/// ([MarkChoice]): tre klor, fyra smala, två djupa, spegelvänt, hugg i kors.
class ClawPainter extends CustomPainter {
  ClawPainter(this.color, {this.tab = false, this.seed = 0}) : forced = MarkChoice.forced;
  final Color color;
  final bool tab;
  final int seed;
  final int? forced;

  @override
  void paint(Canvas canvas, Size size) {
    final (variant, r) = MarkChoice.pick(seed);
    double j(double spread) => (r.nextDouble() * 2 - 1) * spread;
    final tilt = j(.06), shift = j(.05);
    switch (variant) {
      case 0:
        _claws(canvas, size, count: 3, tilt: tilt, shift: shift);
      case 1:
        _claws(canvas, size, count: 4, gapScale: .75, bladeScale: .8, tilt: tilt, shift: shift);
      case 2:
        _claws(canvas, size, count: 2, gapScale: 1.3, bladeScale: 1.5, tilt: tilt, shift: shift);
      case 3:
        _claws(canvas, size, count: 3, mirror: true, tilt: tilt, shift: shift);
      default:
        _claws(canvas, size, count: 3, tilt: tilt, shift: shift);
        _claws(canvas, size, count: 2, mirror: true, bladeScale: .7, alpha: .7, tilt: -tilt, shift: -shift);
    }
  }

  void _claws(Canvas canvas, Size size,
      {required int count,
      bool mirror = false,
      double gapScale = 1,
      double bladeScale = 1,
      double alpha = 1,
      double tilt = 0,
      double shift = 0}) {
    final w = size.width, h = size.height;
    final blade = (tab ? 2.4 : 1.1) * bladeScale;
    final gap = (tab ? math.min(9.0, w * .1) : 4.2) * gapScale;
    final glow = Paint()
      ..color = color.withValues(alpha: .35 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final p = Paint()..color = color.withValues(alpha: (tab ? .85 : 1) * alpha);
    double x(double v) => mirror ? w - v : v;
    for (var k = 0; k < count; k++) {
      final dx = (k - (count - 1) / 2) * gap;
      // Över en flik: från övre högra till nedre vänstra (spegelvänt: tvärtom), kant till kant.
      final a = tab ? Offset(x(w * (.72 + shift + tilt) + dx), -2) : Offset(x(w * (.85 + shift) + dx), h * .1);
      final b = tab ? Offset(x(w * (.3 + shift - tilt) + dx), h + 2) : Offset(x(w * (.1 + shift) + dx), h * .88);
      final mid = Offset.lerp(a, b, .5)! + Offset(mirror ? -blade : blade, blade * .7); // lätt böj
      final n = Offset(-(b - a).dy, (b - a).dx) / (b - a).distance;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx + n.dx * blade, mid.dy + n.dy * blade, b.dx, b.dy)
        ..quadraticBezierTo(mid.dx - n.dx * blade, mid.dy - n.dy * blade, a.dx, a.dy);
      if (tab) canvas.drawPath(path, glow);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(ClawPainter old) =>
      old.color != color || old.tab != tab || old.seed != seed || old.forced != forced;
}

/// Förseglat: läkt ärr med stygn över fliken — under textens mitt, så namnet
/// går att läsa. Varianter ([MarkChoice]): lång linje, kors, kort snett ärr,
/// sicksack, korsstygn.
class ScarPainter extends CustomPainter {
  ScarPainter(this.color, {this.seed = 0}) : forced = MarkChoice.forced;
  final Color color;
  final int seed;
  final int? forced;

  @override
  void paint(Canvas canvas, Size size) {
    final (variant, r) = MarkChoice.pick(seed);
    double j(double spread) => (r.nextDouble() * 2 - 1) * spread;
    final w = size.width, h = size.height;
    final y = h * (.74 + j(.04));
    final bend = 3 + j(1.2);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: .7);
    switch (variant) {
      case 0:
        _scar(canvas, Offset(-2, y + 2), Offset(w + 2, y - 2), bend, line);
      case 1:
        _scar(canvas, Offset(-2, h * .56), Offset(w + 2, h * .92), bend, line);
        _scar(canvas, Offset(-2, h * .92), Offset(w + 2, h * .56), -bend, line);
      case 2:
        final x0 = w * (.38 + j(.08));
        _scar(canvas, Offset(x0, h + 2), Offset(math.min(w + 2, x0 + w * .55), h * .5), bend * .6, line);
      case 3:
        _zigzag(canvas, w, y, line);
      default:
        _scar(canvas, Offset(-2, y + 2), Offset(w + 2, y - 2), bend, line, cross: true);
    }
  }

  /// S-böjd linje a → b med stygn var ~12:e px (korsstygn: ×).
  void _scar(Canvas canvas, Offset a, Offset b, double bend, Paint line, {bool cross = false}) {
    final d = (b - a) / (b - a).distance;
    final n = Offset(-d.dy, d.dx);
    final c1 = Offset.lerp(a, b, .3)! - n * bend;
    final c2 = Offset.lerp(a, b, .6)! + n * bend;
    canvas.drawPath(Path()..moveTo(a.dx, a.dy)..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, b.dx, b.dy), line);
    final count = math.max(2, ((b - a).distance / 12).floor());
    for (var i = 1; i < count; i++) {
      final t = i / count, u = 1 - t;
      final p = a * (u * u * u) + c1 * (3 * u * u * t) + c2 * (3 * u * t * t) + b * (t * t * t);
      if (cross) {
        final s1 = n * 3.5 + d * 2.5, s2 = n * 3.5 - d * 2.5;
        canvas.drawLine(p - s1, p + s1, line);
        canvas.drawLine(p - s2, p + s2, line);
      } else {
        final s = n * 4 + d * 1.2;
        canvas.drawLine(p - s, p + s, line);
      }
    }
  }

  /// Taggig linje från kant till kant, stygn över varannan topp.
  void _zigzag(Canvas canvas, double w, double y, Paint line) {
    final n = math.max(4, (w / 9).floor());
    double x(int i) => -2 + (w + 4) * i / n;
    final path = Path()..moveTo(-2, y);
    for (var i = 1; i <= n; i++) {
      path.lineTo(x(i), y + (i.isOdd ? -3.0 : 3.0));
    }
    canvas.drawPath(path, line);
    for (var i = 1; i < n; i += 2) {
      canvas.drawLine(Offset(x(i) - 1.2, y - 7), Offset(x(i) + 1.2, y + 1), line);
    }
  }

  @override
  bool shouldRepaint(ScarPainter old) => old.color != color || old.seed != seed || old.forced != forced;
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Lite utanför bokstaven så att X:et läses som en markering, inte som glyf.
    final r = Rect.fromCenter(center: size.center(Offset.zero), width: size.width + 6, height: size.height * .72);
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(r.topLeft, r.bottomRight, p)
      ..drawLine(r.topRight, r.bottomLeft, p);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.color != color;
}

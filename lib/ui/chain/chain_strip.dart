/// Kedjans slider. TVÅ KANALER (MK1-lärdom 3.81.1 — blanda dem aldrig):
///   * STATUS bor på BOKSTAVEN: kvar = temats accent, avklarad = dämpad men
///     ALDRIG osynlig, vilodag = guld (dämpat guld när avklarad), överhoppad =
///     dämpad som avklarad + temats [SkippedMark] (Nanosuit: X över bokstaven).
///   * NÄRHET bor på BEHÅLLAREN: vald = upphöjd aktiv yta + fullt namn,
///     granne ("på glänt") = kortnamn, övriga = bara bokstav.
library;

import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../theme/active_mark.dart';
import '../../theme/chain_theme.dart';
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

    return Glass(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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
              return Padding(
                key: _keys.putIfAbsent(s.id, GlobalKey.new),
                padding: const EdgeInsets.only(right: 6),
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: '${s.isRest ? 'Forced rest day' : s.name}${skipped ? ', skipped' : done ? ', done' : ''}',
                  child: GestureDetector(
                    onTap: () => widget.onSelect(s.id),
                    // Pågående pass: temats markering runt fliken (Nanosuit: puls).
                    child: ActiveMarkFrame(
                      active: widget.inProgress.contains(s.id),
                      animate: widget.animate,
                      child: Raised(
                      material: material,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (skipped) SkippedLetter(mark: c.skippedMark, color: c.textMuted, child: letterText) else letterText,
                        if (name != null) ...[
                          const SizedBox(width: 10),
                          Text(name, style: base.copyWith(color: selected ? c.textStrong : letterColor)),
                        ],
                        if (widget.inProgress.contains(s.id)) ...[
                          const SizedBox(width: 6),
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle)),
                        ],
                      ]),
                    ),
                    ),
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
      };
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

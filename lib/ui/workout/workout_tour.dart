/// Rundturen första gången passvyn öppnas (onboarding, Niklas 2026-10-05):
/// tre steg som pekar på riktiga knappar — LOG, DONE, ⋮. SKIP när som helst.
/// Visas en gång (UserSettings.workoutTourSeen), aldrig av misstag igen.
library;

import 'package:flutter/material.dart';

import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';

class TourStep {
  const TourStep(this.target, this.title, this.body);
  final GlobalKey target;
  final String title;
  final String body;
}

/// Nycklarna till knapparna rundturen pekar på (sätts på det expanderade kortet).
class TourKeys {
  final log = GlobalKey(debugLabel: 'tour-log');
  final done = GlobalKey(debugLabel: 'tour-done');
  final menu = GlobalKey(debugLabel: 'tour-menu');
}

class WorkoutTour extends StatefulWidget {
  const WorkoutTour({super.key, required this.steps, required this.onFinished});
  final List<TourStep> steps;
  final VoidCallback onFinished;

  @override
  State<WorkoutTour> createState() => _WorkoutTourState();
}

class _WorkoutTourState extends State<WorkoutTour> {
  int _i = 0;
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    _show();
  }

  /// Scrollar fram knappen och mäter den efter nästa bildruta.
  Future<void> _show() async {
    setState(() => _hole = null);
    final ctx = widget.steps[_i].target.currentContext;
    if (ctx == null) return _next(); // knappen finns inte (t.ex. inget set) — hoppa över steget
    await Scrollable.ensureVisible(ctx, alignment: .35, duration: const Duration(milliseconds: 250));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = widget.steps[_i].target.currentContext?.findRenderObject() as RenderBox?;
      final me = context.findRenderObject() as RenderBox?;
      if (box == null || me == null || !box.hasSize) return;
      final topLeft = box.localToGlobal(Offset.zero, ancestor: me);
      setState(() => _hole = (topLeft & box.size).inflate(6));
    });
  }

  void _next() {
    if (_i + 1 >= widget.steps.length) {
      widget.onFinished();
      return;
    }
    _i++;
    _show();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final step = widget.steps[_i];
    final last = _i == widget.steps.length - 1;
    return LayoutBuilder(builder: (context, size) {
      final hole = _hole;
      final below = hole == null || hole.center.dy < size.maxHeight / 2;
      return Stack(children: [
        // Hinnan fångar trycken: man följer rundturen eller trycker SKIP.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: CustomPaint(painter: _Dim(hole, c.background.withValues(alpha: .82), c.accent)),
          ),
        ),
        if (hole != null)
          Positioned(
            left: 16,
            right: 16,
            top: below ? hole.bottom + 12 : null,
            bottom: below ? null : size.maxHeight - hole.top + 12,
            child: Glass(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(step.title, style: text.titleMedium!.copyWith(color: c.accent)),
                const SizedBox(height: 6),
                Text(step.body, style: text.bodyMedium!.copyWith(color: c.textBody)),
                const SizedBox(height: 14),
                Row(children: [
                  Text('${_i + 1}/${widget.steps.length}', style: text.labelSmall),
                  const Spacer(),
                  if (!last)
                    TextButton(
                      onPressed: widget.onFinished,
                      style: TextButton.styleFrom(minimumSize: const Size(64, 48), foregroundColor: c.textMuted),
                      child: const Text('SKIP'),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _next,
                    child: Raised(
                      material: c.raisedActive,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      child: Text(last ? 'GOT IT' : 'NEXT', style: text.labelLarge!.copyWith(fontSize: 13)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
      ]);
    });
  }
}

class _Dim extends CustomPainter {
  _Dim(this.hole, this.color, this.edge);
  final Rect? hole;
  final Color color;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final h = hole;
    if (h == null) {
      canvas.drawPath(all, Paint()..color = color);
      return;
    }
    final cut = Path()..addRect(h);
    canvas.drawPath(Path.combine(PathOperation.difference, all, cut), Paint()..color = color);
    canvas.drawRect(h, Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_Dim old) => old.hole != hole || old.color != color;
}

/// "ROUND 18 COMPLETE" (Niklas 2026-10-05: en heads-up när rundan är över,
/// gärna något grafiskt, utan extra knapp). Bokstäverna tänds en i taget som
/// en våg, kedjan pulserar, sedan laddas den om: "ROUND 19". Försvinner av sig
/// själv efter ~3,5 s; ett tryck var som helst stänger direkt. Minska rörelse:
/// bara texten, stilla.
library;

import 'dart:async';

import 'package:flutter/material.dart';

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

class _RoundCompleteState extends State<RoundComplete> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
  bool _closing = false;
  bool _started = false;
  Timer? _hold;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _a.value = .5; // allt tänt, ingen våg
      _hold = Timer(const Duration(milliseconds: 2500), _close);
    } else {
      _a.forward().whenComplete(_close);
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
    final text = Theme.of(context).textTheme;
    final s = widget.summary;
    final days = s.end.difference(s.start).inDays + 1;
    final stats = [
      '${s.trained} ${s.trained == 1 ? 'session' : 'sessions'}',
      '$days ${days == 1 ? 'day' : 'days'}',
      if (widget.newPrs > 0) '${widget.newPrs} new ${widget.newPrs == 1 ? 'PR' : 'PRs'}',
      if (s.skipped > 0) '${s.skipped} skipped',
    ].join(' · ');
    final n = widget.letters.length;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) {
          final t = _a.value;
          // 0–0,4: vågen tänder bokstäverna · 0,4–0,55: puls · 0,62: omladdning · 0,9–1: tona ut.
          final wave = (t / .4).clamp(0.0, 1.0);
          final pulse = t > .4 && t < .55 ? 1 + .06 * (1 - ((t - .475).abs() / .075)) : 1.0;
          final reset = t >= .62;
          final fade = t > .9 ? 1 - (t - .9) / .1 : (t < .05 ? t / .05 : 1.0);
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: ColoredBox(
              color: c.background.withValues(alpha: .86),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        reset ? 'ROUND ${s.round + 1}' : 'ROUND ${s.round} COMPLETE',
                        key: ValueKey(reset),
                        textAlign: TextAlign.center,
                        style: text.headlineSmall!.copyWith(
                          color: c.accent,
                          letterSpacing: 3,
                          shadows: [Shadow(color: c.accent.withValues(alpha: .6), blurRadius: 16)],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(reset ? 'A fresh chain — next up: ${widget.letters.first.$2}' : stats,
                        textAlign: TextAlign.center, style: text.bodyMedium!.copyWith(color: c.textBody)),
                    const SizedBox(height: 24),
                    Transform.scale(
                      scale: pulse,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (i, (id, letter)) in widget.letters.indexed)
                            _chip(context, letter, rest: widget.restIds.contains(id), lit: !reset && wave * n > i),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(BuildContext context, String letter, {required bool rest, required bool lit}) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final color = rest ? c.restGold : (lit ? c.textStrong : c.accent);
    return SizedBox(
      width: 48,
      height: 48,
      child: Raised(
        material: lit ? c.raisedActive : c.raisedIdle,
        padding: EdgeInsets.zero,
        child: Center(child: Text(letter, style: text.titleMedium!.copyWith(color: color))),
      ),
    );
  }
}

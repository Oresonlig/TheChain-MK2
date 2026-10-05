/// Vilotimerns list i nederkant av passvyn: tid kvar + −30 / +30 / ✕ (48 px,
/// tummen når). Sista 10 s i accentfärg — inte rött, rött betyder fail.
library;

import 'package:flutter/material.dart';

import '../../app/rest_timer.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';

class RestTimerBar extends StatelessWidget {
  const RestTimerBar({super.key, required this.timer});
  final RestTimer timer;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: timer,
      builder: (context, _) {
        if (!timer.running) return const SizedBox.shrink();
        final c = context.chain;
        final text = Theme.of(context).textTheme;
        final left = timer.remainingSecs;
        final over = left <= 0;
        final hot = over || left <= 10;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Raised(
            material: c.raisedIdle,
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            child: Row(children: [
              Text(over ? 'REST OVER' : 'REST', style: text.labelSmall!.copyWith(color: hot ? c.accent : c.textMuted)),
              const SizedBox(width: 12),
              Expanded(
                child: over
                    ? const SizedBox.shrink()
                    : Text(
                        fmtRest(left),
                        style: text.titleLarge!.copyWith(
                          color: hot ? c.accent : c.textStrong,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
              ),
              if (!over) ...[
                SizedBox(
                  width: 56,
                  child: GhostButton(label: '−30', semanticLabel: 'Rest 30 seconds less', onTap: () => timer.adjust(-RestTimer.step)),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 56,
                  child: GhostButton(label: '+30', semanticLabel: 'Rest 30 seconds more', onTap: () => timer.adjust(RestTimer.step)),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 48,
                  child: GhostButton(label: '', icon: Icons.close, semanticLabel: 'Stop rest timer', onTap: timer.stop, color: c.textMuted),
                ),
              ] else ...[
                // Larmet ringer: samma val som larmvyn över låsskärmen.
                SizedBox(
                  width: 72,
                  child: GhostButton(label: '+30 S', semanticLabel: 'Rest 30 seconds more', onTap: () => timer.adjust(RestTimer.step)),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 104,
                  child: GhostButton(label: 'DISMISS', onTap: timer.stop, color: c.accent),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}

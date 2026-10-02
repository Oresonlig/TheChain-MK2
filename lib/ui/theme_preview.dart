/// F1 punkt 4 — statisk förhandsvisning av Nanosuit-grunden i DEV-appen.
/// Ingen logik: bara temat (färger, Saira, glas, upphöjda ytor, hex-väv) på en
/// skiss av kedjevyn, för Niklas bedömning. Ersätts av riktiga vyer i F3.
library;

import 'package:flutter/material.dart';

import '../theme/chain_theme.dart';
import '../theme/hex_field.dart';
import '../theme/surfaces.dart';

class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key, this.channelLabel = ''});

  final String channelLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.4,
                  colors: [c.backgroundGlow, c.background],
                  stops: const [0, .62],
                ),
              ),
            ),
          ),
          Positioned.fill(child: HexFieldBackground(line: c.hexLine)),
          // #1: allt innehåll under statusraden och ovanför navigeringslisten.
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _Header(channelLabel: channelLabel),
                const SizedBox(height: 16),
                Text('1/7 sessions done · Round 18', style: text.bodySmall),
                const SizedBox(height: 10),
                const _ChainStrip(),
                const SizedBox(height: 20),
                const _ExerciseCard(),
                const SizedBox(height: 24),
                Text('Nanosuit preview — static mock, not functional', style: text.labelSmall, textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.channelLabel});
  final String channelLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    return Glass(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('THE', style: text.displaySmall),
                Text('CHAIN',
                    style: text.displaySmall!.copyWith(
                      color: c.accent,
                      shadows: [Shadow(color: c.accent.withValues(alpha: .6), blurRadius: 14)],
                    )),
              ],
            ),
          ),
          Text(channelLabel, style: text.labelSmall),
        ],
      ),
    );
  }
}

/// #2: kedjan med djup. Tre tillstånd + vilodag, distinkta men aldrig osynliga.
class _ChainStrip extends StatelessWidget {
  const _ChainStrip();

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    // Sairas smala bredd (wdth 80) för passnamnen — hela kedjan ryms bättre.
    final label = Theme.of(context).textTheme.labelLarge!.copyWith(
      letterSpacing: 1.2,
      fontVariations: const [FontVariation.weight(700), FontVariation.width(80)],
    );
    Widget tab(RaisedMaterial m, String letter, {String? name, Color? letterColor}) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Raised(
            material: m,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(letter, style: label.copyWith(fontSize: 20, color: letterColor)),
              if (name != null) ...[
                const SizedBox(width: 10),
                Text(name, style: label.copyWith(color: letterColor)),
              ],
            ]),
          ),
        );
    return Glass(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          tab(c.raisedDone, 'A', name: 'CHE', letterColor: c.textFaint),
          tab(c.raisedActive, 'B', name: 'BACK HEAVY + BICEPS', letterColor: c.textStrong),
          tab(c.raisedIdle, 'C', name: 'LEG', letterColor: c.accent),
          tab(c.raisedIdle, 'V', letterColor: c.restGold),
          tab(c.raisedIdle, 'D', letterColor: c.accent),
        ]),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard();

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    Widget field(String value, String unit) => Expanded(
          child: Column(children: [
            Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.background, border: Border.all(color: c.borderStrong)),
              child: Text(value, style: text.titleMedium),
            ),
            const SizedBox(height: 4),
            Text(unit, style: text.labelSmall),
          ]),
        );
    // #3: sekundära knappar — dämpade, låga, inga skrikiga färger.
    Widget secondary(String label) => Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: c.secondaryAction,
              side: BorderSide(color: c.secondaryAction.withValues(alpha: .5)),
              minimumSize: const Size(0, 36),
              shape: const RoundedRectangleBorder(),
              textStyle: text.labelSmall,
            ),
            onPressed: () {},
            child: Text(label),
          ),
        );
    return Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('B  BACK HEAVY + BICEPS  ·  NEXT UP', style: text.labelSmall!.copyWith(color: c.accent)),
          const SizedBox(height: 12),
          Text('Dead Hang', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Bodyweight + added load', style: text.bodyMedium),
          Text('Supinated or neutral', style: text.bodySmall!.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text('Last (18d ago): BW + 0 kg · 80 s', style: text.bodySmall),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 36, child: Padding(padding: const EdgeInsets.only(top: 12), child: Text('S1', style: text.titleMedium))),
            field('0', '+ KG'),
            const SizedBox(width: 8),
            field('—', 'SEC'),
            const SizedBox(width: 8),
            field('0', '+F'),
            const SizedBox(width: 10),
            Raised(
              material: c.raisedActive,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('LOG', style: text.labelLarge),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [secondary('+ WARM-UP'), const SizedBox(width: 8), secondary('+ WORK SET')]),
        ],
      ),
    );
  }
}

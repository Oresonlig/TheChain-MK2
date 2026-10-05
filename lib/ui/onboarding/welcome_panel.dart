/// Första gången appen är tom (Niklas 2026-10-05: "mindre frågor och sidor
/// desto bättre"): idén i en mening, enheterna, och ETT val — ta med datan från
/// hemsidan (bara om den finns) eller bygg kedjan i programbyggaren.
library;

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
import '../program/program_screen.dart';
import '../settings/settings_screen.dart' show choiceButton;

class WelcomePanel extends StatefulWidget {
  const WelcomePanel({super.key, required this.app});
  final AppController app;

  @override
  State<WelcomePanel> createState() => _WelcomePanelState();
}

class _WelcomePanelState extends State<WelcomePanel> {
  @override
  void initState() {
    super.initState();
    widget.app.checkWebsiteData();
  }

  void _build() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProgramScreen(app: widget.app)));

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final s = app.repo!.settings();
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final canImport = app.websiteData == true && app.moved != true;

    Widget primary(String label, VoidCallback? onTap) => GestureDetector(
          onTap: onTap,
          child: Raised(
            material: onTap == null ? c.raisedIdle : c.raisedActive,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(label, style: text.labelLarge!.copyWith(color: onTap == null ? c.textFaint : c.textStrong)),
            ),
          ),
        );

    return Glass(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Welcome', style: text.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Your training is a chain of sessions — A, B, C … and a rest day. '
          'Train them in any order; when all are done, the round is complete.',
          style: text.bodyMedium!.copyWith(color: c.textBody),
        ),
        const SizedBox(height: 20),
        Text('UNITS', style: text.labelSmall),
        const SizedBox(height: 8),
        Row(children: [
          choiceButton(context, 'KG', s.weightUnit == WeightUnit.kg, () => app.updateSettings(s.copyWith(weightUnit: WeightUnit.kg))),
          const SizedBox(width: 8),
          choiceButton(context, 'LBS', s.weightUnit == WeightUnit.lbs, () => app.updateSettings(s.copyWith(weightUnit: WeightUnit.lbs))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          choiceButton(context, '°C', s.tempUnit == TempUnit.celsius, () => app.updateSettings(s.copyWith(tempUnit: TempUnit.celsius))),
          const SizedBox(width: 8),
          choiceButton(
              context, '°F', s.tempUnit == TempUnit.fahrenheit, () => app.updateSettings(s.copyWith(tempUnit: TempUnit.fahrenheit))),
        ]),
        const SizedBox(height: 24),
        if (canImport) ...[
          primary(app.busy ? 'BRINGING YOUR DATA…' : 'BRING MY WEBSITE DATA', app.busy ? null : app.importFromWebsite),
          const SizedBox(height: 6),
          Text('History, records, program and weight from thechain.training.',
              style: text.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          GhostButton(label: 'START FRESH — BUILD MY CHAIN', onTap: app.busy ? null : _build),
        ] else ...[
          primary('BUILD MY CHAIN', _build),
          if (app.websiteData == null) ...[
            const SizedBox(height: 8),
            Text('Checking for website data…', style: text.labelSmall, textAlign: TextAlign.center),
          ],
        ],
        if (app.error != null) ...[
          const SizedBox(height: 12),
          Text(app.error!, style: text.bodySmall!.copyWith(color: c.fail)),
        ],
      ]),
    );
  }
}

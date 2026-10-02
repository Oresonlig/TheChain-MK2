/// Weight-fliken: logga dagens vikt, se senaste vägningarna. Kurva och trend
/// kommer i F4.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
import '../nanosuit_scaffold.dart';

const _lbsPerKg = 2.20462;

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key, required this.app});
  final AppController app;

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String _fmt(double kg, WeightUnit u) {
    final v = u == WeightUnit.lbs ? kg * _lbsPerKg : kg;
    return '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} ${u == WeightUnit.lbs ? 'lbs' : 'kg'}';
  }

  Future<void> _log(UserSettings s) async {
    final v = double.tryParse(_ctl.text.trim().replaceAll(',', '.'));
    if (v == null) return;
    final kg = s.weightUnit == WeightUnit.lbs ? v / _lbsPerKg : v;
    if (kg < 20 || kg > 300) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid weight')));
      return;
    }
    await widget.app.logBodyweight(kg);
    _ctl.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final repo = widget.app.repo;
        if (repo == null) return const SizedBox.shrink();
        final c = context.chain;
        final text = Theme.of(context).textTheme;
        final s = repo.settings();
        final entries = repo.bodyweight().reversed.toList();
        final today = AppController.dayKey(DateTime.now());
        final todays = entries.where((e) => e.date == today).firstOrNull;

        return ChainScaffold(
          ambient: s.ambientEffects,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text('WEIGHT', style: text.titleLarge!.copyWith(letterSpacing: 4)),
              const SizedBox(height: 16),
              Glass(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(todays == null ? 'TODAY' : 'TODAY · ${_fmt(todays.kg, s.weightUnit)} logged', style: text.labelSmall),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: TextField(
                          controller: _ctl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                          textAlign: TextAlign.center,
                          style: text.titleLarge!.copyWith(color: c.textStrong),
                          onSubmitted: (_) => _log(s),
                          decoration: InputDecoration(
                            hintText: s.weightUnit == WeightUnit.lbs ? 'lbs' : 'kg',
                            hintStyle: text.titleMedium!.copyWith(color: c.textFaint),
                            filled: true,
                            fillColor: c.background,
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: c.borderStrong), borderRadius: BorderRadius.zero),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: c.accent), borderRadius: BorderRadius.zero),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _log(s),
                      child: SizedBox(
                        width: 96,
                        height: 56,
                        child: Raised(
                          material: c.raisedActive,
                          padding: EdgeInsets.zero,
                          child: Center(child: Text('LOG', style: text.labelLarge)),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              Glass(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('RECENT', style: text.labelSmall),
                  if (entries.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('No weigh-ins yet', style: text.bodySmall)),
                  for (final e in entries.take(30))
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                      child: Row(children: [
                        Expanded(child: Text(e.date, style: text.bodyMedium)),
                        Text(_fmt(e.kg, s.weightUnit), style: text.titleMedium),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => widget.app.deleteBodyweight(e.date),
                          icon: Icon(Icons.close, size: 18, color: c.textFaint),
                        ),
                      ]),
                    ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Hemmet efter inloggning: fyra flikar i nederkant (Niklas: "smidigt att
/// navigera med tummen"). Aktiv flik bär den upphöjda Nanosuit-ytan.
library;

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../theme/chain_theme.dart';
import '../theme/surfaces.dart';
import 'chain/chain_screen.dart';
import 'progress/progress_screen.dart';
import 'settings/settings_screen.dart';
import 'weight/weight_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.app, required this.email, required this.versionLabel});

  final AppController app;
  final String email;
  final String versionLabel;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChainScreen(app: widget.app, email: widget.email, buildLabel: widget.versionLabel),
      WeightScreen(app: widget.app),
      ProgressScreen(app: widget.app),
      SettingsScreen(app: widget.app, email: widget.email, versionLabel: widget.versionLabel),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _NavBar(index: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.link, 'CHAIN'),
    (Icons.monitor_weight_outlined, 'WEIGHT'),
    (Icons.emoji_events_outlined, 'PROGRESS'),
    (Icons.settings_outlined, 'SETTINGS'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.accent.withValues(alpha: .5))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(children: [
            for (final (i, (icon, label)) in _items.indexed)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: SizedBox(
                      height: 58, // stor träffyta för tummen
                      child: i == index
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Raised(
                                material: c.raisedActive,
                                inset: 6,
                                padding: EdgeInsets.zero,
                                child: _content(icon, label, c.textStrong, text),
                              ),
                            )
                          : _content(icon, label, c.textMuted, text),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _content(IconData icon, String label, Color color, TextTheme text) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(label, style: text.labelSmall!.copyWith(color: color, fontSize: 10, letterSpacing: 1)),
        ]),
      );
}

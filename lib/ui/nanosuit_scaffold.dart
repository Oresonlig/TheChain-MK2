/// Gemensam ram för skärmar: temats bakgrund (sken + hex-väv) och SafeArea,
/// så att inget hamnar under statusraden (Niklas #1).
library;

import 'package:flutter/material.dart';

import '../theme/chain_theme.dart';
import '../theme/hex_field.dart';

class ChainScaffold extends StatelessWidget {
  const ChainScaffold({super.key, required this.child, this.ambient = true});

  final Widget child;
  final bool ambient;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    return Scaffold(
      body: Stack(children: [
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
        if (c.hasAmbient) Positioned.fill(child: HexFieldBackground(line: c.hexLine, enabled: ambient)),
        // Skärmens glas delar en bakgrundsläsning (se Glass.grouped).
        BackdropGroup(child: SafeArea(child: child)),
      ]),
    );
  }
}

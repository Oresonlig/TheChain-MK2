/// Gemensam ram för skärmar: temats bakgrund (sken + hex-väv) och SafeArea,
/// så att inget hamnar under statusraden (Niklas #1).
///
/// Ramen äger hex-vävens modell och delar den med skärmens glas
/// ([BackgroundScope]) — ritat glas ritar en mjuk kopia av samma väv.
library;

import 'package:flutter/material.dart';

import '../theme/background_scope.dart';
import '../theme/chain_theme.dart';
import '../theme/hex_field.dart';

class ChainScaffold extends StatefulWidget {
  const ChainScaffold({super.key, required this.child, this.ambient = true});

  final Widget child;
  final bool ambient;

  @override
  State<ChainScaffold> createState() => _ChainScaffoldState();
}

class _ChainScaffoldState extends State<ChainScaffold> {
  final _model = HexFieldModel();
  late final _backdrop = BlurredBackdrop(_model);
  final _canvas = GlobalKey();

  @override
  void dispose() {
    _backdrop.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final animated = widget.ambient && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          key: _canvas,
          child: DecoratedBox(decoration: BoxDecoration(gradient: backgroundGradient(c))),
        ),
        if (c.hasAmbient) Positioned.fill(child: HexFieldBackground(line: c.hexLine, enabled: widget.ambient, model: _model)),
        // Skärmens glas delar en bakgrundsläsning (se Glass.grouped).
        BackdropGroup(
          child: BackgroundScope(
            model: _model,
            backdrop: _backdrop,
            canvasKey: _canvas,
            animated: c.hasAmbient && animated,
            child: SafeArea(child: widget.child),
          ),
        ),
      ]),
    );
  }
}

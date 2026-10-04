/// Bakgrunden som glaset står på: ChainScaffold delar hex-vävens modell och
/// ytan den ritas på, så att RITAT glas kan rita en mjuk kopia av exakt det
/// som ligger bakom kortet — utan motorns bakgrundsblur, som tappades under
/// scroll på Niklas S26 Ultra (2026-10-04, build 47–48).
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'chain_theme.dart';
import 'hex_field.dart';

class BackgroundScope extends InheritedWidget {
  const BackgroundScope({
    super.key,
    required this.model,
    required this.canvasKey,
    required this.animated,
    required super.child,
  });

  final HexFieldModel model;

  /// Ytan bakgrunden ritas på (hela skärmen) — glaset räknar sin plats mot den.
  final GlobalKey canvasKey;
  final bool animated;

  static BackgroundScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<BackgroundScope>();

  @override
  bool updateShouldNotify(BackgroundScope old) => old.model != model || old.animated != animated;
}

/// Bakgrundens sken — samma gradient i ramen och i ritat glas.
Gradient backgroundGradient(ChainTheme c) => RadialGradient(
      center: Alignment.topCenter,
      radius: 1.4,
      colors: [c.backgroundGlow, c.background],
      stops: const [0, .62],
    );

/// Fyller sin yta med det som ligger bakom: bakgrundens sken + en uppmjukad
/// kopia av hex-väven, båda i skärmens koordinater (står still när kortet
/// scrollar). Ogenomskinligt — den skarpa väven bakom syns aldrig igenom.
class PaintedBackdrop extends LeafRenderObjectWidget {
  const PaintedBackdrop({super.key, required this.scope, required this.theme});

  final BackgroundScope scope;
  final ChainTheme theme;

  @override
  RenderPaintedBackdrop createRenderObject(BuildContext context) => RenderPaintedBackdrop(scope, theme);

  @override
  void updateRenderObject(BuildContext context, RenderPaintedBackdrop renderObject) => renderObject
    ..scope = scope
    ..theme = theme;
}

class RenderPaintedBackdrop extends RenderBox {
  RenderPaintedBackdrop(this._scope, this._theme);

  BackgroundScope _scope;
  ChainTheme _theme;

  set scope(BackgroundScope s) {
    if (identical(s.model, _scope.model) && s.animated == _scope.animated) {
      _scope = s;
      return;
    }
    if (attached) _scope.model.removeListener(markNeedsPaint);
    _scope = s;
    if (attached) _scope.model.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  set theme(ChainTheme t) {
    if (t == _theme) return;
    _theme = t;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scope.model.addListener(markNeedsPaint); // vågorna rör sig
  }

  @override
  void detach() {
    _scope.model.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvasBox = _scope.canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasBox == null || !canvasBox.hasSize) return;
    // Var kortet står på bakgrunden just nu (räknas om varje gång det ritas).
    final origin = localToGlobal(Offset.zero) - canvasBox.localToGlobal(Offset.zero);
    final area = origin & size;
    final canvas = context.canvas
      ..save()
      ..clipRect(offset & size)
      ..translate(offset.dx - origin.dx, offset.dy - origin.dy);
    canvas.drawRect(area, Paint()..shader = backgroundGradient(_theme).createShader(Offset.zero & canvasBox.size));
    if (_theme.hasAmbient && _scope.model.hexes.isNotEmpty) {
      paintHexField(canvas, _scope.model,
          line: _theme.hexLine, animated: _scope.animated, only: area, blur: _theme.glassBlur);
    }
    canvas.restore();
  }
}

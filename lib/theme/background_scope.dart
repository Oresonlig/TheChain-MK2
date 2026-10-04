/// Bakgrunden som glaset står på. Motorns bakgrundsblur (BackdropFilter)
/// tappades under scroll på Niklas S26 Ultra (2026-10-04, build 46–49) — ritat
/// glas höll. Så här ritas det billigt:
///
///   * [BlurredBackdrop]: bakgrunden (sken + hex-väv med vågor) ritas EN gång
///     per vävsteg som en liten bild (1/4 upplösning) och blurras där —
///     utanför skärmen, där scroll inte påverkar något.
///   * [PaintedBackdrop]: varje glaskort visar sin bit av bilden, på exakt den
///     plats kortet står på skärmen. Ogenomskinligt — skarp väv lyser aldrig igenom.
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'chain_theme.dart';
import 'hex_field.dart';

/// Värdet till `ListView(addRepaintBoundaries: ...)` på skärmar med glas:
/// AV. Ritat glas räknar ut var det står när det ritas, så korten måste ritas
/// om när listan scrollar (inte bara flyttas som färdiga lager).
const glassListRepaintBoundaries = false;

/// Bakgrundens sken — samma gradient i ramen och i glasets bild.
Gradient backgroundGradient(ChainTheme c) => RadialGradient(
      center: Alignment.topCenter,
      radius: 1.4,
      colors: [c.backgroundGlow, c.background],
      stops: const [0, .62],
    );

/// Den blurrade, nedskalade bakgrundsbilden. Görs om bara när väven tagit ett
/// steg (eller ytan/temat ändrats) — alla kort i samma bildruta delar den.
class BlurredBackdrop {
  BlurredBackdrop(this.model);

  final HexFieldModel model;

  /// Bilden har 1/4 av skärmens upplösning: blurren döljer det, och den kostar nästan inget.
  static const scale = 0.25;

  ui.Image? _image;
  int _frame = -1;
  Size _size = Size.zero;
  bool _animated = false;
  ChainTheme? _theme;

  ui.Image? imageFor(Size canvas, ChainTheme theme, {required bool animated}) {
    final fresh = _image != null &&
        _frame == model.frame &&
        _size == canvas &&
        _animated == animated &&
        identical(_theme, theme);
    if (fresh) return _image;
    final w = (canvas.width * scale).ceil(), h = (canvas.height * scale).ceil();
    if (w <= 0 || h <= 0) return null;

    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder)..scale(scale);
    final area = Offset.zero & canvas;
    c.saveLayer(
      area,
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: theme.glassBlur, sigmaY: theme.glassBlur, tileMode: TileMode.clamp),
    );
    c.drawRect(area, Paint()..shader = backgroundGradient(theme).createShader(area));
    if (theme.hasAmbient && model.hexes.isNotEmpty) {
      paintHexField(c, model, line: theme.hexLine, animated: animated);
    }
    c.restore();
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    // Säkert: kort som redan ritat den gamla bilden håller sin egen referens.
    _image?.dispose();
    _image = image;
    _frame = model.frame;
    _size = canvas;
    _animated = animated;
    _theme = theme;
    return image;
  }

  void dispose() {
    _image?.dispose();
    _image = null;
  }
}

class BackgroundScope extends InheritedWidget {
  const BackgroundScope({
    super.key,
    required this.model,
    required this.backdrop,
    required this.canvasKey,
    required this.animated,
    required super.child,
  });

  final HexFieldModel model;
  final BlurredBackdrop backdrop;

  /// Ytan bakgrunden ritas på (hela skärmen) — glaset räknar sin plats mot den.
  final GlobalKey canvasKey;
  final bool animated;

  static BackgroundScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<BackgroundScope>();

  @override
  bool updateShouldNotify(BackgroundScope old) =>
      old.model != model || old.backdrop != backdrop || old.animated != animated;
}

/// Fyller sin yta med kortets bit av den blurrade bakgrundsbilden.
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
    if (identical(s.model, _scope.model) && identical(s.backdrop, _scope.backdrop) && s.animated == _scope.animated) {
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
    final image = _scope.backdrop.imageFor(canvasBox.size, _theme, animated: _scope.animated);
    if (image == null) return;
    // Var kortet står på bakgrunden just nu (räknas om varje gång det ritas).
    final origin = localToGlobal(Offset.zero) - canvasBox.localToGlobal(Offset.zero);
    // Bara den del som ligger på bakgrunden (ett kort kan sticka ut ur skärmen).
    final onCanvas = (origin & size).intersect(Offset.zero & canvasBox.size);
    if (onCanvas.isEmpty) return;
    const k = BlurredBackdrop.scale;
    final src = Rect.fromLTRB(onCanvas.left * k, onCanvas.top * k, onCanvas.right * k, onCanvas.bottom * k);
    final dst = onCanvas.shift(offset - origin);
    context.canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.medium);
  }
}

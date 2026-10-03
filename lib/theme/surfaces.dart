/// Temats ytor som widgets: frostat glas, upphöjd yta och Nanosuits
/// hexagon-chevron (LOG-formen). Färgerna kommer alltid från ChainTheme.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'chain_theme.dart';

/// Frostat glas: låg opacitet + blur. Gradienten går från [ChainTheme.glassTop]
/// till [ChainTheme.glassBottom].
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 6, this.border = true});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.glassTop, c.glassBottom],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: border ? Border.all(color: c.border) : null,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Sekundärknapp: kontur på eget glas. Standard för knappar utan eget material
/// (DONE/FINISH har [Raised]) — ingen knapp får drunkna i bakgrunden
/// (Niklas 2026-10-03).
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.semanticLabel,
    this.icon,
    this.leadingIcon,
    this.borderColor,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final String? semanticLabel;

  /// Ersätter texten (minus-tecknet är för litet i Saira).
  final IconData? icon;

  /// Ikon före texten (t.ex. UNDO).
  final IconData? leadingIcon;
  final Color? borderColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final col = color ?? c.secondaryAction;
    final style = OutlinedButton.styleFrom(
      foregroundColor: col,
      disabledForegroundColor: c.textFaint,
      side: BorderSide(color: onTap == null ? c.border : borderColor ?? col.withValues(alpha: .5)),
      minimumSize: Size(0, height), // stora träffytor
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: const RoundedRectangleBorder(),
      textStyle: Theme.of(context).textTheme.labelSmall,
    );
    final Widget button = icon != null
        ? OutlinedButton(onPressed: onTap, style: style, child: Icon(icon, size: 22))
        : leadingIcon != null
            ? OutlinedButton.icon(onPressed: onTap, style: style, icon: Icon(leadingIcon, size: 18), label: Text(label))
            : OutlinedButton(onPressed: onTap, style: style, child: Text(label));
    return Semantics(
      label: semanticLabel,
      // Konturen är kanten — glaset ritar ingen egen.
      child: Glass(padding: EdgeInsets.zero, radius: 0, border: false, child: button),
    );
  }
}

/// Nanosuits chevron: avfasade spetsar i vänster/höger kant (MK1 clip-path).
class ChevronBorder extends OutlinedBorder {
  const ChevronBorder({this.inset = 8, super.side});

  final double inset;

  Path _path(Rect r) => Path()
    ..moveTo(r.left + inset, r.top)
    ..lineTo(r.right - inset, r.top)
    ..lineTo(r.right, r.center.dy)
    ..lineTo(r.right - inset, r.bottom)
    ..lineTo(r.left + inset, r.bottom)
    ..lineTo(r.left, r.center.dy)
    ..close();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect.deflate(side.width));
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(_path(rect), side.toPaint());
  }

  @override
  ChevronBorder copyWith({BorderSide? side}) => ChevronBorder(inset: inset, side: side ?? this.side);
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);
  @override
  ShapeBorder scale(double t) => ChevronBorder(inset: inset * t, side: side.scale(t));
}

/// Upphöjd yta i chevron-form: gradient topp→botten, ljus överkant, kant, glöd.
class Raised extends StatelessWidget {
  const Raised({super.key, required this.material, required this.child, this.padding, this.inset = 8});

  final RaisedMaterial material;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final m = material;
    final shape = ChevronBorder(inset: inset, side: BorderSide(color: m.edge));
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [m.top, m.bottom]),
        shadows: [if (m.glow.a > 0) BoxShadow(color: m.glow, blurRadius: 12)],
      ),
      child: DecoratedBox(
        // inset-highlight: en tunn ljus linje i överkant
        decoration: ShapeDecoration(
          shape: ChevronBorder(inset: inset),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, .08, .08],
            colors: [m.highlight, m.highlight.withValues(alpha: 0), m.highlight.withValues(alpha: 0)],
          ),
        ),
        child: Padding(padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: child),
      ),
    );
  }
}

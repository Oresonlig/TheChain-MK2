/// DIAGNOS (DEV, 2026-10-04): motorns bakgrundsblur (BackdropFilter) tappas
/// medan listor scrollar på Niklas S26 Ultra — även med stilla väv och även
/// när korten ritas om varje bildruta (build 48). Ritat glas höll (build 49).
///   * painted — STANDARD: kortet visar sin bit av en blurrad bakgrundsbild
///               (background_scope.dart). Ingen bakgrundsläsning.
///   * engine  — som förut, för jämförelse ett bygge till.
/// Bara i minnet. Tas bort (med motorns blur) när Niklas bekräftat ritat glas.
library;

import 'package:flutter/foundation.dart';

enum GlassMode { painted, engine }

final glassMode = ValueNotifier<GlassMode>(GlassMode.painted);

/// Värdet till `ListView(addRepaintBoundaries: ...)` på skärmar med glas.
/// Ritat glas måste ritas om när kortet flyttas (det räknar ut var det står).
bool get glassListRepaintBoundaries => glassMode.value == GlassMode.engine;

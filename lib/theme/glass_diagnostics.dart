/// DIAGNOS (DEV, 2026-10-04): glaset tappar sin blur medan listor scrollar
/// (Niklas S26 Ultra, build 47–48).
///   * engine        — som förut: motorns bakgrundsblur (BackdropFilter).
///   * engineRepaint — samma, men listorna ritar om korten varje bildruta.
///                     Build 48: lagade INTE felet → inte lageråteranvändning.
///   * painted       — glaset ritar själv bakgrundens ton + en mjuk kopia av
///                     hex-väven (ingen bakgrundsläsning alls).
/// Bara i minnet — nollställs vid omstart. Tas bort när frågan är avgjord
/// (dödkod rensas i samma version som ersätter den).
library;

import 'package:flutter/foundation.dart';

enum GlassMode { engine, engineRepaint, painted }

final glassMode = ValueNotifier<GlassMode>(GlassMode.engine);

/// Värdet till `ListView(addRepaintBoundaries: ...)` på skärmar med glas.
/// Ritat glas måste ritas om när kortet flyttas (det räknar ut var det står).
bool get glassListRepaintBoundaries => glassMode.value == GlassMode.engine;

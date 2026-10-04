/// DIAGNOS (DEV, 2026-10-04): glaset tappar sin blur medan listor scrollar
/// (Niklas S26 Ultra, build 47). Hypotes: renderingsmotorn tappar blur-steget
/// för listkort vars färdiga lager återanvänds och bara flyttas under scroll.
///
/// "Repaint while scrolling" stänger av listornas repaint boundaries så att
/// korten ritas om varje bildruta i stället. Lagar det felet är mekanismen
/// bekräftad. Bara i minnet — nollställs vid omstart. Tas bort när frågan är
/// avgjord (dödkod rensas i samma version som ersätter den).
library;

import 'package:flutter/foundation.dart';

final repaintWhileScrolling = ValueNotifier<bool>(false);

/// Värdet till `ListView(addRepaintBoundaries: ...)` på skärmar med glas.
bool get glassListRepaintBoundaries => !repaintWhileScrolling.value;

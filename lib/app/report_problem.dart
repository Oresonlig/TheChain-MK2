/// "Report a problem" (LT 2026-10-08: "No way to report on app"). Öppnar
/// telefonens mejlapp med ett färdigt mejl — build, kanal och telefonmodell
/// (Android-sidan lägger till modellen) står redan där. Skärmdumpar bifogas i
/// mejlappen. Ingen server, ingen kostnad.
library;

import 'package:flutter/services.dart';

const kReportEmail = 'oresonlig@proton.me';

class ReportProblem {
  ReportProblem._();

  static const _ch = MethodChannel('the_chain/rest_alarm');

  /// Mejlets text före telefonens uppgifter. Ren funktion — testbar.
  static String body(String versionLabel) => 'What happened?\n\n\n'
      'What did you expect?\n\n\n'
      '---\n'
      '$versionLabel\n';

  /// True = mejlappen öppnades. False = ingen mejlapp (eller ingen Android-kod).
  static Future<bool> open(String versionLabel) async {
    try {
      return await _ch.invokeMethod<bool>('reportProblem', {
            'to': kReportEmail,
            'subject': 'The Chain — problem report',
            'body': body(versionLabel),
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}

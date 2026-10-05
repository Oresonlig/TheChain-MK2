/// Självuppdatering (MK1-lärdomar, LESSONS_MK1_ANDROID.md §6–7):
///   * versionskollen läser en version.json som CI lägger i releasen — ingen
///     GitHub-API-kvot;
///   * APK:n laddas ner I APPEN och lämnas till Androids installationsdialog —
///     användaren bekräftar alltid (aldrig tyst; Samsung Auto Blocker);
///   * SHA-256 kontrolleras innan installation.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';

/// Telefonens installationsspärr (Samsungs Auto Blocker släpper bara Play/Galaxy
/// Store) — allmänt formulerat, Samsungs sökväg som exempel.
const _autoBlocker =
    "Turn off your phone's auto blocker (Samsung: Settings › Security and privacy › Auto Blocker) and tap Update again.";

class UpdateInfo {
  const UpdateInfo({required this.build, required this.apkUrl, this.sha256});
  final int build;
  final String apkUrl;
  final String? sha256;
}

class UpdateCheckFailed implements Exception {
  const UpdateCheckFailed(this.reason);
  final String reason;
  @override
  String toString() => 'UpdateCheckFailed: $reason';
}

/// Kanalens release i MK2-repot. DEV = `dev-latest`.
String releaseBase(String channel) =>
    'https://github.com/Oresonlig/TheChain-MK2/releases/download/${channel == 'dev' ? 'dev-latest' : 'stable-latest'}';

/// Tolkar version.json; null om filen är trasig.
UpdateInfo? parseVersionJson(String body, String base) {
  try {
    final j = (jsonDecode(body) as Map).cast<String, Object?>();
    final build = (j['build'] as num?)?.toInt();
    if (build == null) return null;
    return UpdateInfo(build: build, apkUrl: '$base/${j['apk'] ?? 'thechain.apk'}', sha256: j['sha256'] as String?);
  } catch (_) {
    return null;
  }
}

class Updater {
  Updater({required this.channel, required this.currentBuild, http.Client? client}) : _client = client ?? http.Client();

  final String channel;
  final int currentBuild;
  final http.Client _client;

  /// Nyare bygge finns, eller null = senaste. Kastar [UpdateCheckFailed] vid
  /// nätfel eller trasig fil — "kunde inte kolla" får aldrig se ut som
  /// "senaste" (Data & Sync visar skillnaden, 2026-10-04).
  Future<UpdateInfo?> check() async {
    if (currentBuild <= 0) return null; // lokala byggen uppdaterar inte sig själva
    final base = releaseBase(channel);
    final http.Response res;
    try {
      res = await _client
          .get(Uri.parse('$base/version.json?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw UpdateCheckFailed('$e');
    }
    if (res.statusCode != 200) throw UpdateCheckFailed('HTTP ${res.statusCode}');
    final info = parseVersionJson(res.body, base);
    if (info == null) throw const UpdateCheckFailed('broken version.json');
    return info.build > currentBuild ? info : null;
  }

  /// Laddar ner och öppnar installationsdialogen. Strömmar läsbar status.
  Stream<String> install(UpdateInfo info) async* {
    yield 'Downloading…';
    await for (final e in OtaUpdate().execute(
      info.apkUrl,
      destinationFilename: 'thechain-update.apk',
      sha256checksum: info.sha256,
    )) {
      switch (e.status) {
        case OtaStatus.DOWNLOADING:
          yield 'Downloading… ${e.value ?? ''}%';
        case OtaStatus.INSTALLING:
          // Auto Blocker stoppar installationen TYST — pluginet får inget fel
          // tillbaka. Tipset måste därför stå här, innan, tills appen finns på
          // Google Play (Niklas 2026-10-03).
          yield 'Confirm the install in the dialog. Nothing happens? $_autoBlocker';
        case OtaStatus.INSTALLATION_DONE:
          yield 'Installed';
        case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
          yield 'Allow ${channel == 'dev' ? 'The Chain DEV' : 'The Chain'} to install apps, then tap Update again';
        case OtaStatus.CHECKSUM_ERROR:
          yield 'Download was corrupted — tap Update again';
        case OtaStatus.ALREADY_RUNNING_ERROR:
          yield 'An update is already downloading';
        case OtaStatus.CANCELED:
          yield 'Update canceled';
        case OtaStatus.INSTALLATION_ERROR:
          yield 'Install blocked. $_autoBlocker';
        case OtaStatus.DOWNLOAD_ERROR || OtaStatus.INTERNAL_ERROR:
          yield 'Update failed: ${e.value ?? 'unknown error'}';
      }
    }
  }
}

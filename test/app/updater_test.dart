import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:the_chain/app/updater.dart';

void main() {
  test('version.json tolkas; trasig fil ger null', () {
    final i = parseVersionJson('{"build": 21, "sha256": "abc", "apk": "thechain-dev.apk"}', 'https://x');
    expect(i!.build, 21);
    expect(i.apkUrl, 'https://x/thechain-dev.apk');
    expect(i.sha256, 'abc');
    expect(parseVersionJson('nope', 'https://x'), isNull);
    expect(parseVersionJson('{"apk": "a"}', 'https://x'), isNull);
  });

  test('nyare bygge → uppdatering; samma eller äldre → ingen', () async {
    final client = MockClient((r) async => http.Response('{"build": 21, "sha256": "abc"}', 200));
    expect((await Updater(channel: 'dev', currentBuild: 20, client: client).check())!.build, 21);
    expect(await Updater(channel: 'dev', currentBuild: 21, client: client).check(), isNull);
    expect(await Updater(channel: 'dev', currentBuild: 25, client: client).check(), isNull);
  });

  test('nätfel, 404 och lokala byggen ger tyst null', () async {
    final notFound = MockClient((r) async => http.Response('', 404));
    final broken = MockClient((r) async => throw Exception('offline'));
    expect(await Updater(channel: 'dev', currentBuild: 20, client: notFound).check(), isNull);
    expect(await Updater(channel: 'dev', currentBuild: 20, client: broken).check(), isNull);
    final any = MockClient((r) async => http.Response('{"build": 99}', 200));
    expect(await Updater(channel: 'dev', currentBuild: 0, client: any).check(), isNull);
  });

  test('frågar DEV-kanalens release och undviker cache', () async {
    late Uri asked;
    final client = MockClient((r) async {
      asked = r.url;
      return http.Response('{"build": 1}', 200);
    });
    await Updater(channel: 'dev', currentBuild: 5, client: client).check();
    expect(asked.toString(), startsWith('https://github.com/Oresonlig/TheChain-MK2/releases/download/dev-latest/version.json?t='));
  });
}

// En enhet i taget (Niklas 2026-10-06): inloggning hittar andra inloggningar
// → varning + val INNAN telefonens data öppnas. SIGN IN HERE loggar ut de
// andra; CANCEL lämnar inget efter sig.
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/ui/other_device_screen.dart';

import 'fake_backend.dart';

Future<(AppController, FakeBackend)> _signedIn({List<OtherSession>? others}) async {
  final b = FakeBackend()..others = others;
  final app = AppController(b, syncDelay: Duration.zero);
  await app.start();
  await app.signIn('x', 'secret');
  await pumpEventQueue();
  return (app, b);
}

final _phone = [OtherSession(userAgent: 'Dart/3.9 (dart:io)', lastActive: DateTime(2026, 10, 6, 7))];

void main() {
  test('annan enhet inloggad: varning innan något öppnas; SIGN IN HERE loggar ut den', () async {
    final (app, b) = await _signedIn(others: _phone);
    expect(app.phase, Phase.confirmDevice);
    expect(app.otherDevices!.single.isWebsite, isFalse);
    expect(b.storeOpens, 0, reason: 'inget öppnat före valet');

    await app.confirmSignInHere();
    await pumpEventQueue();
    expect(b.othersSignedOut, 1);
    expect(app.phase, Phase.ready);
    expect(b.storeOpens, 1);
    app.dispose();
  });

  test('CANCEL: bara den här enheten loggas ut, de andra rörs inte, inget öppnat', () async {
    final (app, b) = await _signedIn(others: _phone);
    await app.cancelSignIn();
    await pumpEventQueue();
    expect(app.phase, Phase.signedOut);
    expect(b.userId, isNull);
    expect(b.othersSignedOut, 0);
    expect(b.storeOpens, 0);
    expect(app.error, isNull, reason: 'egen handling — inget "utloggad av annan enhet"');
    app.dispose();
  });

  test('inga andra, eller okänt svar (SQL ej körd / nätfel): öppnar direkt, loggar inte ut någon', () async {
    for (final others in [const <OtherSession>[], null]) {
      final (app, b) = await _signedIn(others: others);
      expect(app.phase, Phase.ready);
      expect(b.othersSignedOut, 0);
      app.dispose();
    }
  });

  test('utloggad av en inloggning på annan enhet: besked; egen utloggning: inget besked', () async {
    final (app, b) = await _signedIn();
    expect(app.phase, Phase.ready);
    await b.signOut(); // servern: sessionen återkallad (inte användarens tryck)
    await pumpEventQueue();
    expect(app.phase, Phase.signedOut);
    expect(app.error, contains('another device'));
    app.dispose();

    final (app2, _) = await _signedIn();
    await app2.signOut();
    await pumpEventQueue();
    expect(app2.error, isNull);
    app2.dispose();
  });

  test('"active … ago"', () {
    final now = DateTime(2026, 10, 6, 12);
    expect(OtherDeviceScreen.ago(DateTime(2026, 10, 6, 10), now), 'active 2 h ago');
    expect(OtherDeviceScreen.ago(DateTime(2026, 10, 3, 12), now), 'active 3 days ago');
    expect(OtherDeviceScreen.ago(null, now), 'last active unknown');
  });
}

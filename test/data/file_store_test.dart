import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/data/file_store.dart';
import 'package:the_chain/data/sync_engine.dart';
import 'package:the_chain/domain/sync.dart';

TableState stateWith(int n) => TableState(
      items: {for (var i = 0; i < n; i++) 'w$i': Synced('w$i', Stamp(1000 + i, 0, 'phone'), {'i': i, 'pad': 'x' * 2000})},
      cursor: n,
      dirty: {'w${n - 1}'},
    );

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('chain_store_'));
  tearDown(() async => dir.delete(recursive: true));

  test('många samtidiga sparningar (en per tangenttryck, ej inväntade) → filen är hel och har SENASTE läget', () async {
    final store = FileLocalStore(dir);
    // Som _apply: varje ändring sparar utan att vänta på förra sparningen.
    final saves = [for (var n = 1; n <= 40; n++) store.save('mk2_workouts', stateWith(n))];
    await Future.wait(saves);
    final back = await FileLocalStore(dir).load('mk2_workouts');
    expect(back.items.length, 40);
    expect(back.cursor, 40);
    expect(back.dirty, {'w39'});
  });

  test('trasig fil: börjar om men sparar undan originalet (aldrig tyst borta)', () async {
    final f = File('${dir.path}${Platform.pathSeparator}mk2_notes.json');
    await f.writeAsString('{"items": {"n": {"s": "inte en lista"}}}');
    final back = await FileLocalStore(dir).load('mk2_notes');
    expect(back.items, isEmpty);
    final kept = dir.listSync().whereType<File>().where((x) => x.path.contains('mk2_notes.json.corrupt'));
    expect(kept, hasLength(1));
  });
}

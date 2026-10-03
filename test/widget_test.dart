import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/hex_field.dart';

void main() {
  test('hex-väven: layout fyller ytan och vågor lever och dör', () {
    final m = HexFieldModel();
    m.layout(const Size(400, 800));
    expect(m.hexes.length, greaterThan(500));
    for (var i = 0; i < 400; i++) {
      m.step();
    }
    expect(m.frame, 400);
    expect(m.waves.length, lessThan(12));
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin source text and web resources remain valid UTF-8 without mojibake', () {
    final forbidden = RegExp(r'\u00c3[\u0080-\u00bf\u0152\u0153\u0160\u0161\u0178\u017d\u017e\u0192\u02c6\u02dc\u2013-\u2026\u2030\u2039\u203a\u20ac\u2122]|\u00c2[\u0080-\u00bf]|\u00e2[\u0080\u0082\u20ac\u201a]|\u00f0[\u009f\u0178]|[\u0080-\u009f\ufffd]');
    final offenders = <String>[];
    for (final root in ['lib', 'web', 'scripts']) {
      for (final file in Directory(root).listSync(recursive: true).whereType<File>()) {
        if (!['.dart', '.js', '.mjs', '.html', '.json', '.css', '.ps1', '.arb'].any(file.path.endsWith)) continue;
        if (forbidden.hasMatch(file.readAsStringSync())) offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });
}

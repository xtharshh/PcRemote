// Pure-Dart tests: theme + API request shaping (no plugins, no network).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pcremote/theme.dart';

void main() {
  test('dark theme is Material 3 with dark seed scheme', () {
    final t = AppTheme.dark;
    expect(t.useMaterial3, isTrue);
    expect(t.colorScheme.brightness, Brightness.dark);
  });

  test('light theme is Material 3 with light seed scheme', () {
    final t = AppTheme.light;
    expect(t.useMaterial3, isTrue);
    expect(t.colorScheme.brightness, Brightness.light);
  });
}

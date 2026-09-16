// Pure-Dart tests: theme + profile accents (no plugins, no network).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pc_remote/links.dart';
import 'package:pc_remote/theme.dart';

void main() {
  test('dark theme is Material 3 dark', () {
    final t = AppTheme.dark;
    expect(t.useMaterial3, isTrue);
    expect(t.colorScheme.brightness, Brightness.dark);
  });

  test('light theme is Material 3 light', () {
    final t = AppTheme.light;
    expect(t.useMaterial3, isTrue);
    expect(t.colorScheme.brightness, Brightness.light);
  });

  test('each profile has a distinct accent', () {
    final accents = {
      AppTheme.profileAccent('admin'),
      AppTheme.profileAccent('guest'),
      AppTheme.profileAccent('kid'),
    };
    expect(accents.length, 3);
  });

  test('windows download links point at GitHub releases', () {
    expect(AppLinks.githubRepo, contains('github.com/xtharshh/PcRemote'));
    expect(AppLinks.windowsDownload, contains('github.com/xtharshh/PcRemote'));
    expect(AppLinks.windowsDownload, contains('releases'));
    expect(Uri.tryParse(AppLinks.windowsDownload)?.hasAbsolutePath, isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Single place for the public GitHub links.
///
/// The Android app cannot bundle the PC side — Windows needs its own
/// module (daemon + installer, `LumenDesk-Setup-*.exe`). Point users
/// here so they can download it from GitHub Releases from inside the app.
class AppLinks {
  /// Public repo (code + releases page).
  static const githubRepo = 'https://github.com/xtharshh/PcRemote';

  /// Always resolves to the newest published release.
  /// Users pick `LumenDesk-Setup-<version>.exe` (or `LumenDesk.exe`)
  /// from the release assets and run it on their Windows PC.
  static const windowsDownload =
      'https://github.com/xtharshh/PcRemote/releases/latest';

  static Future<void> open(
      BuildContext context, String url, String label) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        _fallback(context, url, label);
      }
    } catch (_) {
      if (context.mounted) _fallback(context, url, label);
    }
  }

  static void _fallback(BuildContext context, String url, String label) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open $label — link copied: $url')),
    );
  }

  static Future<void> openWindowsDownload(BuildContext context) =>
      open(context, windowsDownload, 'Windows download');

  static Future<void> openRepo(BuildContext context) =>
      open(context, githubRepo, 'GitHub repo');

  static Future<void> copyWindowsLink(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: windowsDownload));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Windows download link copied')),
      );
    }
  }
}

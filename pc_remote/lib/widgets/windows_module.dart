import 'package:flutter/material.dart';
import '../links.dart';
import 'ui.dart';

/// "Get the Windows module" card.
///
/// Shown on the login (gate) screen for first-time setup AND on Home
/// (especially when offline — which usually means the PC side isn't
/// installed/running yet). Opens GitHub Releases in the browser so the
/// user can download `LumenDesk-Setup-*.exe` onto their Windows PC.
class WindowsModuleCard extends StatelessWidget {
  /// Compact variant for the gate screen (tighter copy).
  final bool compact;
  const WindowsModuleCard({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.computer_outlined, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Windows module needed?',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            compact
                ? 'Install Lumen Desk on your Windows PC first, then find it on WiFi below.'
                : 'This phone app talks to Lumen Desk on your PC. Grab the Windows setup from GitHub Releases and run it on your PC (same WiFi).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          SelectableText(
            AppLinks.windowsDownload,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => AppLinks.openWindowsDownload(context),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Download Windows module'),
              ),
              OutlinedButton.icon(
                onPressed: () => AppLinks.openRepo(context),
                icon: const Icon(Icons.code, size: 18),
                label: const Text('GitHub repo'),
              ),
              IconButton(
                tooltip: 'Copy link',
                onPressed: () => AppLinks.copyWindowsLink(context),
                icon: const Icon(Icons.copy, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'On your PC: run LumenDesk-Setup-.exe → set PIN → keep it on the same WiFi.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

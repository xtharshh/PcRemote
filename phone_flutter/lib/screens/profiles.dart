import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/ui.dart';

/// Profiles tab: admin / guest / kid segmented control + JSON editor
/// + Load / Save / Start / Stop. Shared JSON state lives in the parent.
class ProfilesScreen extends StatefulWidget {
  final PcApi api;
  final String profileName;
  final ValueChanged<String> onProfileChange;
  final TextEditingController editor;

  const ProfilesScreen({
    super.key,
    required this.api,
    required this.profileName,
    required this.onProfileChange,
    required this.editor,
  });

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  static const names = ['admin', 'guest', 'kid'];
  String _note = '';

  Future<void> _run(Future<Map<String, dynamic>> Function() fn) async {
    try {
      final r = await fn();
      if (mounted) setState(() => _note = const JsonEncoder.withIndent('  ').convert(r));
    } catch (e) {
      if (mounted) setState(() => _note = 'ERR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        ResponsiveCard(
          child: Column(
            children: [
              Semantics(
                label: 'Select profile',
                child: SegmentedButton<String>(
                  segments: names
                      .map((n) => ButtonSegment(value: n, label: Text(n)))
                      .toList(),
                  selected: {widget.profileName},
                  onSelectionChanged: (s) => widget.onProfileChange(s.first),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: widget.editor,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Profile JSON',
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => _run(() async {
                      final r = await widget.api
                          .profileGet(widget.profileName);
                      widget.editor.text =
                          const JsonEncoder.withIndent('  ').convert(r['data']);
                      return r;
                    }),
                    child: const Text('Load'),
                  ),
                  ElevatedButton(
                    onPressed: () => _run(() => widget.api.profileSave(
                          widget.profileName,
                          jsonDecode(widget.editor.text)
                              as Map<String, dynamic>,
                        )),
                    child: const Text('Save'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        _run(() => widget.api.guestStart(widget.profileName)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                    child: const Text('Start'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        _run(() => widget.api.guestStop(widget.profileName)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
                    child: const Text('Stop'),
                  ),
                ],
              ),
              if (_note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_note, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
        const ResponsiveCard(
          child: Text(
            'admin = full access (Start clears all blocks). '
            'guest = 30 min medium block. kid = 60 min strict block.',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

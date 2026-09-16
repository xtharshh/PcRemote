import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/ui.dart';

/// Power tab: shutdown / restart / sleep / lock — now or in N minutes.
/// Pending timers are listed with live countdowns and can be cancelled.
class PowerScreen extends StatefulWidget {
  final PcApi api;
  const PowerScreen({super.key, required this.api});

  @override
  State<PowerScreen> createState() => _PowerScreenState();
}

class _PowerScreenState extends State<PowerScreen> {
  List<Map<String, dynamic>> _pending = [];
  bool _busy = false;

  static const _actions = [
    ('shutdown', 'Shut down', Icons.power_settings_new, Colors.red),
    ('restart', 'Restart', Icons.restart_alt, Colors.orange),
    ('sleep', 'Sleep', Icons.bedtime, Colors.indigo),
    ('lock', 'Lock', Icons.lock, Colors.blueGrey),
  ];

  static const _delays = [0, 5, 10, 30, 60];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final s = await widget.api.status();
      if (!mounted) return;
      setState(() {
        _pending =
            ((s['power'] as List?)?.cast<Map<String, dynamic>>() ?? []);
      });
    } catch (e) {
      _msg(PcApi.friendlyError(e));
    }
  }

  String _label(String action, int mins) =>
      mins == 0 ? action : '$action in $mins min';

  Future<void> _run(String action, String title, int mins) async {
    final destructive = action == 'shutdown' || action == 'restart';
    if (mins == 0 && destructive && mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('$title now?'),
          content: Text(
              'This will $action the PC immediately. Unsaved work may be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white),
              child: Text(title),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      final r = await widget.api.power(action, inMinutes: mins);
      if (r['ok'] == false) {
        _msg((r['err'] ?? '$title failed').toString());
      } else if (mins == 0) {
        _msg('$title sent');
      } else {
        _msg('${_label(title, mins)} scheduled'
            '${r['replaced'] == true ? ' (replaces old timer)' : ''}');
      }
      await _refresh();
    } catch (e) {
      _msg(PcApi.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel([String? action]) async {
    setState(() => _busy = true);
    try {
      final r = await widget.api.powerCancel(action);
      final c = (r['cancelled'] as List? ?? []);
      _msg(c.isEmpty ? 'Nothing scheduled' : 'Cancelled: ${c.join(', ')}');
      await _refresh();
    } catch (e) {
      _msg(PcApi.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _msg(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  String _countdown(int secs) {
    if (secs <= 0) return 'due…';
    final h = secs ~/ 3600, m = (secs % 3600) ~/ 60, s = secs % 60;
    if (h > 0) return '${h}h ${m}m left';
    if (m > 0) return '${m}m ${s}s left';
    return '${s}s left';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          if (_pending.isNotEmpty)
            ResponsiveCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.amber),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Scheduled',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _cancel(),
                        child: const Text('Cancel all'),
                      ),
                    ],
                  ),
                  ..._pending.map((p) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule, size: 20),
                        title: Text(
                            '${(p['action'] as String?) ?? '?'} in ${p['in_minutes']} min'),
                        subtitle: Text(_countdown(
                            (p['remaining_s'] as num?)?.toInt() ?? 0)),
                        trailing: IconButton(
                          tooltip: 'Cancel',
                          icon: const Icon(Icons.cancel, size: 20),
                          onPressed: _busy
                              ? null
                              : () => _cancel(
                                  p['action'] as String?),
                        ),
                      )),
                ],
              ),
            ),
          for (final (action, title, icon, color) in _actions)
            ResponsiveCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            color.withValues(alpha: 0.15),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _delays
                        .map((m) => ChoiceChip(
                              label:
                                  Text(m == 0 ? 'Now' : '${m}m'),
                              selected: false,
                              onSelected: _busy
                                  ? null
                                  : (_) =>
                                      _run(action, title, m),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Timers run on the PC — e.g. lock in 10 min, or shut down in 30. '
              'Scheduling again replaces the old timer. Pull down to refresh countdowns.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

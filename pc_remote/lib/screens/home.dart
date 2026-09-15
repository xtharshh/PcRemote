import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/ui.dart';

/// Home dashboard: PC header, animated brightness ring,
/// lock/unlock actions, activity timeline. Pull to refresh.
class HomeScreen extends StatefulWidget {
  final PcApi api;
  const HomeScreen({super.key, required this.api});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _status;
  bool _online = false;

  Future<void> _refresh() async {
    try {
      final s = await widget.api.status();
      if (mounted) {
        setState(() {
          _status = s;
          _online = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _online = false);
    }
  }

  void _msg(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final bri = (_status?['brightness'] as num?)?.toInt() ?? 0;
    final suggest = (_status?['suggest'] as num?)?.toInt() ?? 0;
    final log = (_status?['log'] as List?)?.cast<String>() ?? const <String>[];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          ResponsiveCard(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _online ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_status?['pc']?.toString() ?? 'My PC',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        _online
                            ? '${_status?['lux'] ?? '…'} lux via ${_status?['src'] ?? '…'}'
                            : 'Offline — pull down to retry',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          ResponsiveCard(
            child: Column(
              children: [
                BrightnessRing(value: bri, suggest: suggest),
                const SizedBox(height: 12),
                BigActionButton(
                  label: 'Auto once',
                  icon: Icons.auto_awesome,
                  onTap: () async {
                    await widget.api.autoOnce();
                    await _refresh();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: BigActionButton(
                    label: 'LOCK',
                    icon: Icons.lock,
                    color: Colors.red,
                    onTap: () async {
                      await widget.api.lock();
                      _msg('PC locked');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BigActionButton(
                    label: 'UNLOCK',
                    icon: Icons.lock_open,
                    color: Colors.green,
                    onTap: () async {
                      await widget.api.unlockApprove();
                      _msg('Approved — press Space on PC + log in');
                    },
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Recent activity'),
          ...log.reversed.map((l) => ListTile(
                dense: true,
                leading: const Icon(Icons.history, size: 18),
                title:
                    Text(l, style: const TextStyle(fontSize: 13)),
              )),
        ],
      ),
    );
  }
}

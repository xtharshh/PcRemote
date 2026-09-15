import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/ui.dart';

/// Home dashboard: connected WiFi PC (by NAME, not IP), animated
/// brightness ring, lock/unlock actions, activity timeline.
/// Pull to refresh.
class HomeScreen extends StatefulWidget {
  final PcApi api;
  final VoidCallback? onChangePc;
  const HomeScreen({super.key, required this.api, this.onChangePc});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _status;
  bool _online = false;
  String _err = '';

  Future<void> _refresh() async {
    try {
      final s = await widget.api.status();
      if (mounted) {
        setState(() {
          _status = s;
          _online = true;
          _err = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _online = false;
          _err = PcApi.friendlyError(e);
        });
      }
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
    // Prefer the live hostname from /status, fall back to the
    // WiFi-discovered name saved at unlock, never show a bare IP first.
    final pcName = (_status?['pc']?.toString().isNotEmpty ?? false)
        ? _status!['pc'].toString()
        : widget.api.displayName;
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
                const AppLogo(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pcName.isEmpty ? 'My PC' : pcName,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        _online
                            ? 'Connected on WiFi · ${_status?['lux'] ?? '…'} lux via ${_status?['src'] ?? '…'}'
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
                if (widget.onChangePc != null)
                  IconButton(
                    tooltip: 'Change PC',
                    onPressed: widget.onChangePc,
                    icon: const Icon(Icons.wifi_find),
                  ),
              ],
            ),
          ),
          if (_err.isNotEmpty)
            ResponsiveCard(
              child: Text(_err, style: const TextStyle(fontSize: 13)),
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
                    try {
                      await widget.api.autoOnce();
                      await _refresh();
                    } catch (e) {
                      _msg(PcApi.friendlyError(e));
                    }
                  },
                ),
                SwitchListTile(
                  title: const Text('Auto-brightness'),
                  subtitle:
                      const Text('Keep adjusting with room light'),
                  value: (_status?['auto'] as bool?) ?? true,
                  onChanged: (v) async {
                    try {
                      await widget.api.setAuto(v);
                      await _refresh();
                    } catch (e) {
                      _msg(PcApi.friendlyError(e));
                    }
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
                      try {
                        await widget.api.lock();
                        _msg('PC locked');
                      } catch (e) {
                        _msg(PcApi.friendlyError(e));
                      }
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
                      try {
                        await widget.api.unlockApprove();
                        _msg('Approved — press Space on PC + log in');
                      } catch (e) {
                        _msg(PcApi.friendlyError(e));
                      }
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

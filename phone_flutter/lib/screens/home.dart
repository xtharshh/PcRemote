import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/ui.dart';

/// Home tab: status card (fades in on refresh) + Lock / Unlock + activity log.
class HomeScreen extends StatefulWidget {
  final PcApi api;
  const HomeScreen({super.key, required this.api});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _status;
  double _opacity = 1.0;

  Future<void> _refresh() async {
    setState(() => _opacity = 0.2);
    try {
      final s = await widget.api.status();
      if (mounted) {
        setState(() {
          _status = s;
          _opacity = 1.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _opacity = 1.0);
        _msg('ERR: $e');
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
    final log = (_status?['log'] as List?)?.cast<String>() ?? const <String>[];
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 250),
          child: ResponsiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Brightness: ${_status?['brightness'] ?? '…'}%',
                    style: Theme.of(context).textTheme.titleLarge),
                Text(
                    'Light: ${_status?['lux'] ?? '…'} lux (${_status?['src'] ?? '…'}) → suggest ${_status?['suggest'] ?? '…'}%'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh status'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        BigActionButton(
          label: 'LOCK NOW',
          icon: Icons.lock,
          color: Colors.red,
          onTap: () async {
            await widget.api.lock();
            _msg('Locked');
          },
        ),
        const SizedBox(height: 4),
        BigActionButton(
          label: 'UNLOCK (approve)',
          icon: Icons.lock_open,
          color: Colors.green,
          onTap: () async {
            await widget.api.unlockApprove();
            _msg('Approved — press Space on PC + log in');
          },
        ),
        const SizedBox(height: 8),
        const ResponsiveCard(
          child: Text('Recent activity',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...log.reversed.map((l) => ListTile(
              dense: true,
              leading: const Icon(Icons.history, size: 18),
              title: Text(l, style: const TextStyle(fontSize: 13)),
            )),
      ],
    );
  }
}

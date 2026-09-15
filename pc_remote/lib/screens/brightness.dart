import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/ui.dart';

/// Brightness tab: live readout, apply-on-release slider, auto once,
/// auto-brightness toggle, light sensor — every action reports what the
/// PC actually did (no silent failures).
class BrightnessScreen extends StatefulWidget {
  final PcApi api;
  const BrightnessScreen({super.key, required this.api});

  @override
  State<BrightnessScreen> createState() => _BrightnessScreenState();
}

class _BrightnessScreenState extends State<BrightnessScreen> {
  double _level = 50;
  bool _loaded = false;
  bool _supported = true;
  bool _auto = true;
  bool _busy = false;
  String _note = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final s = await widget.api.status();
      if (!mounted) return;
      final bri = (s['brightness'] as num?)?.toDouble();
      setState(() {
        _supported = (s['supported'] as bool?) ?? bri != null;
        _auto = (s['auto'] as bool?) ?? true;
        if (!_loaded) {
          _level = (bri ??
                  (s['suggest'] as num?)?.toDouble() ??
                  50)
              .clamp(0, 100);
          _loaded = true;
        }
        if (bri != null) _level = bri.clamp(0, 100);
      });
    } catch (e) {
      _msg(PcApi.friendlyError(e));
    }
  }

  void _msg(String s) => setState(() => _note = s);

  Future<void> _apply(double v) async {
    setState(() => _busy = true);
    try {
      final r = await widget.api.setBrightness(v.round());
      if (r['ok'] == false) {
        _msg((r['err'] ?? 'Brightness not applied').toString());
      } else {
        _msg('Brightness → ${v.round()}%');
      }
      await _refresh();
    } catch (e) {
      _msg(PcApi.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _autoOnce() async {
    setState(() => _busy = true);
    try {
      final r = await widget.api.autoOnce();
      if (r['ok'] == false) {
        _msg((r['err'] ?? 'Auto-brightness failed').toString());
      } else {
        _msg('Auto → ${r['level']}% (${r['lux']} lux)');
      }
      await _refresh();
    } catch (e) {
      _msg(PcApi.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          if (!_supported)
            const ResponsiveCard(
              child: ListTile(
                leading: Icon(Icons.monitor, color: Colors.amber),
                title: Text('External display detected'),
                subtitle: Text(
                    'This PC reports no controllable brightness (laptop internal '
                    'display only — external monitors need DDC/CI). '
                    'Suggestions below still work.'),
              ),
            ),
          ResponsiveCard(
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '${_level.round()}%',
                    key: ValueKey(_level.round()),
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Slider(
                  value: _level.clamp(0, 100),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${_level.round()}%',
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _level = v),
                  onChangeEnd: _busy ? null : _apply,
                ),
                const SizedBox(height: 4),
                Text(
                  _busy
                      ? 'Applying…'
                      : 'Drag and release — applies automatically',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                BigActionButton(
                  label: 'Set ${_level.round()}%',
                  icon: Icons.brightness_6,
                  onTap: () => _apply(_level),
                ),
                const SizedBox(height: 8),
                BigActionButton(
                  label: 'Auto once',
                  icon: Icons.auto_awesome,
                  onTap: _autoOnce,
                ),
                SwitchListTile(
                  title: const Text('Auto-brightness'),
                  subtitle: const Text(
                      'Keep adjusting with room light'),
                  value: _auto,
                  onChanged: _busy
                      ? null
                      : (v) async {
                          setState(() => _busy = true);
                          try {
                            await widget.api.setAuto(v);
                            await _refresh();
                            _msg(v
                                ? 'Auto-brightness on'
                                : 'Auto-brightness off');
                          } catch (e) {
                            _msg(PcApi.friendlyError(e));
                          } finally {
                            if (mounted) {
                              setState(() => _busy = false);
                            }
                          }
                        },
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          try {
                            final r = await widget.api.sense();
                            _msg(
                                'Sensor: ${r['lux']} lux via ${r['src']}');
                          } catch (e) {
                            _msg(PcApi.friendlyError(e));
                          }
                        },
                  icon: const Icon(Icons.light_mode),
                  label: const Text('Sense light'),
                ),
                if (_note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 250),
                    child: Text(_note,
                        textAlign: TextAlign.center),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

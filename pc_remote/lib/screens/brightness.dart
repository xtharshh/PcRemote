import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/ui.dart';

/// Brightness tab: big live readout, slider, set, auto, light sensor.
class BrightnessScreen extends StatefulWidget {
  final PcApi api;
  const BrightnessScreen({super.key, required this.api});

  @override
  State<BrightnessScreen> createState() => _BrightnessScreenState();
}

class _BrightnessScreenState extends State<BrightnessScreen> {
  double _level = 50;
  String _note = '';

  void _msg(String s) => setState(() => _note = s);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
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
                value: _level,
                min: 0,
                max: 100,
                divisions: 20,
                label: '${_level.round()}%',
                onChanged: (v) => setState(() => _level = v),
              ),
              BigActionButton(
                label: 'Set brightness',
                icon: Icons.brightness_6,
                onTap: () async {
                  await widget.api.setBrightness(_level.round());
                  _msg('Set to ${_level.round()}%');
                },
              ),
              const SizedBox(height: 8),
              BigActionButton(
                label: 'Auto once',
                icon: Icons.auto_awesome,
                onTap: () async {
                  final r = await widget.api.autoOnce();
                  _msg('Auto → ${r['level']}% (${r['lux']} lux)');
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final r = await widget.api.sense();
                    _msg('Sensor: ${r['lux']} lux via ${r['src']}');
                  } catch (e) {
                    _msg('ERR: $e');
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
                  child: Text(_note),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

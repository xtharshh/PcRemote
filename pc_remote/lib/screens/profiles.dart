import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets/ui.dart';

const _settingsPages = [
  'accounts',
  'bluetooth',
  'windowsupdate',
  'recovery',
  'apps',
];
const _appPresets = [
  'regedit.exe',
  'powershell.exe',
  'cmd.exe',
  'steam.exe',
];

/// Profiles tab: one visual card per profile, tap to expand a
/// no-JSON editor (chips + slider + folder list). Start/Stop per card.
class ProfilesScreen extends StatefulWidget {
  final PcApi api;
  const ProfilesScreen({super.key, required this.api});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _ProfileCard(
            name: 'admin',
            icon: Icons.admin_panel_settings,
            api: widget.api),
        _ProfileCard(
            name: 'guest', icon: Icons.person_outline, api: widget.api),
        _ProfileCard(
            name: 'kid', icon: Icons.child_care, api: widget.api),
      ],
    );
  }
}

class _ProfileCard extends StatefulWidget {
  final String name;
  final IconData icon;
  final PcApi api;
  const _ProfileCard(
      {required this.name, required this.icon, required this.api});

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _open = false;
  bool _loaded = false;
  bool _busy = false;
  Map<String, dynamic> _orig = {};
  List<String> _folders = [];
  Set<String> _settings = {};
  Set<String> _apps = {};
  final _customApp = TextEditingController();
  double _minutes = 0;

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final r = await widget.api.profileGet(widget.name);
      final data = Map<String, dynamic>.from(r['data'] as Map);
      if (mounted) {
        setState(() {
          _orig = data;
          _folders =
              ((data['folders_deny'] as List?)?.cast<String>() ?? []);
          final vis = (data['settings_hide'] ?? '').toString();
          _settings = vis.isEmpty ? {} : vis.split(';').toSet();
          _apps =
              ((data['apps_deny'] as List?)?.cast<String>() ?? []).toSet();
          _minutes = ((data['time_minutes'] as num?) ?? 0).toDouble();
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) _msg('ERR: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final data = Map<String, dynamic>.from(_orig);
      data['folders_deny'] = _folders;
      data['settings_hide'] = _settings.join(';');
      data['apps_deny'] = _apps.toList();
      data['time_minutes'] = _minutes.round();
      await widget.api.profileSave(widget.name, data);
      if (mounted) _msg('Saved ${widget.name}');
    } catch (e) {
      if (mounted) _msg('ERR: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startStop(bool start) async {
    setState(() => _busy = true);
    try {
      await (start
          ? widget.api.guestStart(widget.name)
          : widget.api.guestStop(widget.name));
      if (mounted) {
        _msg(start ? '${widget.name} started' : '${widget.name} stopped');
      }
    } catch (e) {
      if (mounted) _msg('ERR: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _msg(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.profileAccent(widget.name);
    return ResponsiveCard(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.2),
              child: Icon(widget.icon, color: accent),
            ),
            title: Text(widget.name.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              widget.name == 'admin'
                  ? 'Owner · full access'
                  : '${_folders.length} folders · ${_minutes.round()} min',
            ),
            trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
            onTap: () {
              setState(() => _open = !_open);
              if (_open && !_loaded) _load();
            },
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            height: _open ? null : 0,
            child: _open
                ? (_busy && !_loaded
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle('Blocked Settings pages'),
                          Wrap(
                            spacing: 8,
                            children: _settingsPages
                                .map((p) => FilterChip(
                                      label: Text(p),
                                      selected: _settings.contains(p),
                                      onSelected: (on) => setState(() =>
                                          on
                                              ? _settings.add(p)
                                              : _settings.remove(p)),
                                    ))
                                .toList(),
                          ),
                          const SectionTitle('Blocked apps'),
                          Wrap(
                            spacing: 8,
                            children: _appPresets
                                .map((a) => FilterChip(
                                      label: Text(a),
                                      selected: _apps.contains(a),
                                      onSelected: (on) => setState(() =>
                                          on
                                              ? _apps.add(a)
                                              : _apps.remove(a)),
                                    ))
                                .toList(),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customApp,
                                  decoration: const InputDecoration(
                                    labelText: 'Custom app .exe',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Add app',
                                onPressed: () {
                                  final v =
                                      _customApp.text.trim().toLowerCase();
                                  if (v.isNotEmpty) {
                                    setState(() {
                                      _apps.add(v);
                                      _customApp.clear();
                                    });
                                  }
                                },
                                icon: const Icon(Icons.add_circle),
                              ),
                            ],
                          ),
                          ..._apps
                              .where((a) => !_appPresets.contains(a))
                              .map((a) => Chip(
                                    label: Text(a),
                                    onDeleted: () =>
                                        setState(() => _apps.remove(a)),
                                  )),
                          const SectionTitle('Blocked folders'),
                          if (_folders.isEmpty)
                            const Text('None — pick some in the Folders tab'),
                          ..._folders.map((f) => ListTile(
                                dense: true,
                                leading:
                                    const Icon(Icons.folder, size: 20),
                                title: Text(f,
                                    style:
                                        const TextStyle(fontSize: 13)),
                                trailing: IconButton(
                                  tooltip: 'Remove',
                                  icon: const Icon(Icons.delete, size: 20),
                                  onPressed: () =>
                                      setState(() => _folders.remove(f)),
                                ),
                              )),
                          const SectionTitle(
                              'Time limit (0 = no limit)'),
                          Slider(
                            value: _minutes.clamp(0, 180),
                            min: 0,
                            max: 180,
                            divisions: 12,
                            label: '${_minutes.round()} min',
                            onChanged: (v) =>
                                setState(() => _minutes = v),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _busy ? null : _save,
                                icon: const Icon(Icons.save, size: 18),
                                label: const Text('Save'),
                              ),
                              ElevatedButton.icon(
                                onPressed:
                                    _busy ? null : () => _startStop(true),
                                icon: const Icon(Icons.play_arrow, size: 18),
                                label: const Text('Start'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white),
                              ),
                              ElevatedButton.icon(
                                onPressed:
                                    _busy ? null : () => _startStop(false),
                                icon: const Icon(Icons.stop, size: 18),
                                label: const Text('Stop'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ))
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

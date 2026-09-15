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

const _allProfiles = ['admin', 'guest', 'kid'];

/// Profiles tab: one clean card per profile. Only ONE profile runs at a
/// time — the server auto-stops the previous one when a new one starts.
/// The active card wears an ACTIVE badge; the rest offer Start / Switch.
class ProfilesScreen extends StatefulWidget {
  final PcApi api;
  const ProfilesScreen({super.key, required this.api});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  String? _active;

  @override
  void initState() {
    super.initState();
    _refreshActive();
  }

  Future<void> _refreshActive() async {
    try {
      final s = await widget.api.status();
      if (mounted) setState(() => _active = s['active'] as String?);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshActive,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          if (_active != null)
            ResponsiveCard(
              child: Row(
                children: [
                  const Icon(Icons.verified_user,
                      color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_active!.toUpperCase()} is active — others are stopped',
                      style:
                          const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          for (final name in _allProfiles)
            _ProfileCard(
              key: ValueKey(name),
              name: name,
              icon: name == 'admin'
                  ? Icons.admin_panel_settings
                  : name == 'kid'
                      ? Icons.child_care
                      : Icons.person_outline,
              api: widget.api,
              isActive: _active == name,
              otherActive: _active != null && _active != name,
              onChanged: _refreshActive,
            ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatefulWidget {
  final String name;
  final IconData icon;
  final PcApi api;
  final bool isActive;
  final bool otherActive;
  final Future<void> Function() onChanged;
  const _ProfileCard(
      {super.key,
      required this.name,
      required this.icon,
      required this.api,
      required this.isActive,
      required this.otherActive,
      required this.onChanged});

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

  bool get _isAdmin => widget.name == 'admin';

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
      if (mounted) _msg(PcApi.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (!_open) _loaded = false; // always show fresh data next time
    });
    if (_open) _load();
  }

  Future<void> _save() async {
    if (_isAdmin) {
      _msg('Admin always has full access — nothing to save.');
      return;
    }
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
      if (mounted) _msg(PcApi.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final r = await widget.api.guestStart(widget.name);
      final stopped = r['stopped'];
      if (mounted) {
        _msg(stopped == null
            ? '${widget.name} is now active'
            : '${widget.name} is now active ($stopped stopped)');
      }
      await widget.onChanged();
    } catch (e) {
      if (mounted) _msg(PcApi.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    try {
      await widget.api.guestStop(widget.name);
      if (mounted) _msg('${widget.name} stopped — no profile active');
      await widget.onChanged();
    } catch (e) {
      if (mounted) _msg(PcApi.friendlyError(e));
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- header (identical layout for every card) ----
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: accent.withValues(alpha: 0.15),
                    child: Icon(widget.icon, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(widget.name.toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            if (widget.isActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('ACTIVE',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isAdmin
                              ? 'Owner · everything allowed'
                              : '${_folders.length} folders · ${_minutes.round()} min limit',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          // ---- actions (always visible, same order) ----
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _start,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(widget.isActive
                      ? 'Restart'
                      : widget.otherActive
                          ? 'Switch'
                          : 'Start'),
                  style: widget.isActive
                      ? null
                      : ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      (_busy || !widget.isActive) ? null : _stop,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Stop'),
                ),
              ),
            ],
          ),
          // ---- editor (expands below, same rhythm) ----
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _open
                ? (_busy && !_loaded
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                            child: CircularProgressIndicator()),
                      )
                    : _isAdmin
                        ? const _AdminPanel()
                        : _editor(context))
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _editor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Blocked settings pages'),
        Wrap(
          spacing: 8,
          children: _settingsPages
              .map((p) => FilterChip(
                    label: Text(p),
                    selected: _settings.contains(p),
                    onSelected: (on) => setState(() =>
                        on ? _settings.add(p) : _settings.remove(p)),
                  ))
              .toList(),
        ),
        const _Label('Blocked apps'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _appPresets
              .map((a) => FilterChip(
                    label: Text(a),
                    selected: _apps.contains(a),
                    onSelected: (on) => setState(
                        () => on ? _apps.add(a) : _apps.remove(a)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
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
                final v = _customApp.text.trim().toLowerCase();
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
        Wrap(
          spacing: 8,
          children: _apps
              .where((a) => !_appPresets.contains(a))
              .map((a) => Chip(
                    label: Text(a),
                    onDeleted: () =>
                        setState(() => _apps.remove(a)),
                  ))
              .toList(),
        ),
        _Label('Blocked folders (${_folders.length})'),
        if (_folders.isEmpty)
          const Text('None — add some from the Folders tab'),
        ..._folders.map((f) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder, size: 20),
              title: Text(f, style: const TextStyle(fontSize: 13)),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete, size: 20),
                onPressed: () =>
                    setState(() => _folders.remove(f)),
              ),
            )),
        _Label('Time limit (${_minutes.round()} min · 0 = none)'),
        Slider(
          value: _minutes.clamp(0, 180),
          min: 0,
          max: 180,
          divisions: 12,
          label: '${_minutes.round()} min',
          onChanged: (v) => setState(() => _minutes = v),
        ),
        const SizedBox(height: 4),
        ElevatedButton.icon(
          onPressed: _busy ? null : _save,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save changes'),
        ),
      ],
    );
  }
}

/// Small uppercase section label — same everywhere.
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold, letterSpacing: 0.8)),
    );
  }
}

/// Admin has no block lists — starting it restores full access.
class _AdminPanel extends StatelessWidget {
  const _AdminPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.verified_user,
            color: Colors.indigoAccent, size: 32),
        title: Text('Full access — everything allowed'),
        subtitle: Text(
            'No blocked folders, settings or apps, no time limit. '
            'Starting Admin stops any active Guest/Kid profile and '
            'removes all blocks.'),
      ),
    );
  }
}

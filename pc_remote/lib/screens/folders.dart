import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/ui.dart';

/// Folders tab: target-profile chips, disk picker, search,
/// checkbox list, sticky add bar. Saves straight into the profile.
class FoldersScreen extends StatefulWidget {
  final PcApi api;
  const FoldersScreen({super.key, required this.api});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  String _target = 'guest';
  List<Map<String, dynamic>> _drives = [];
  String? _drive;
  String _path = '';
  String _query = '';
  final _search = TextEditingController();
  List<Map<String, dynamic>> _folders = [];
  final Set<String> _sel = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    try {
      final r = await widget.api.pick();
      if (!mounted) return;
      setState(() {
        _drives = (r['drives'] as List).cast<Map<String, dynamic>>();
        _drive = _drives.isNotEmpty ? _drives[0]['root'] as String : null;
      });
      if (_drive != null) _browse(_drive!);
    } catch (e) {
      _msg('ERR: $e');
    }
  }

  Future<void> _browse(String path) async {
    try {
      final r = await widget.api.folders(path);
      if (!mounted) return;
      setState(() {
        _path = path;
        _folders = (r['folders'] as List).cast<Map<String, dynamic>>();
        _sel.clear();
      });
    } catch (e) {
      _msg('ERR: $e');
    }
  }

  void _up() {
    final p = _path.replaceAll(RegExp(r'\\$'), '');
    final i = p.lastIndexOf('\\');
    if (i > 1) _browse(p.substring(0, i + 1));
  }

  Future<void> _add() async {
    if (_sel.isEmpty) return;
    setState(() => _busy = true);
    try {
      final cur = await widget.api.profileGet(_target);
      final data = Map<String, dynamic>.from(cur['data'] as Map);
      final list =
          ((data['folders_deny'] as List?)?.cast<String>() ?? []);
      data['folders_deny'] = {...list, ..._sel}.toList();
      await widget.api.profileSave(_target, data);
      if (mounted) {
        setState(() => _sel.clear());
        _msg('Added to $_target — Start it in Profiles');
      }
    } catch (e) {
      _msg('ERR: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _msg(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final shown = _query.isEmpty
        ? _folders
        : _folders
            .where((f) => (f['name'] as String)
                .toLowerCase()
                .contains(_query.toLowerCase()))
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: ['guest', 'kid'].map((p) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p),
                    selected: _target == p,
                    onSelected: (_) => setState(() => _target = p),
                  ),
                )).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_drive),
                  initialValue: _drive,
                  decoration: const InputDecoration(
                    labelText: 'Disk',
                    border: OutlineInputBorder(),
                  ),
                  items: _drives
                      .map((d) => DropdownMenuItem<String>(
                            value: d['root'] as String,
                            child: Text(
                                '${d['root']} ${d['label']} (${d['free_gb']}/${d['total_gb']} GB)'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _drive = v);
                      _browse(v);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Up one folder',
                onPressed: _up,
                icon: const Icon(Icons.arrow_upward),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Search folders',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(_path,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: shown.length,
            itemBuilder: (context, i) {
              final f = shown[i];
              final full = f['full'] as String;
              final on = _sel.contains(full);
              return CheckboxListTile(
                dense: true,
                title: Text(f['name'] as String),
                subtitle:
                    Text(full, style: const TextStyle(fontSize: 11)),
                value: on,
                onChanged: (_) => setState(
                    () => on ? _sel.remove(full) : _sel.add(full)),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: BigActionButton(
            label: _busy ? 'Saving…' : 'Add ${_sel.length} to $_target',
            icon: Icons.block,
            onTap: _add,
          ),
        ),
      ],
    );
  }
}

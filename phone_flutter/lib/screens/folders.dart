import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/ui.dart';

/// Folders tab: drive picker + folder list (checkboxes) + add to the
/// active profile's block list. Long lists use ListView.builder (60fps).
class FoldersScreen extends StatefulWidget {
  final PcApi api;
  final void Function(List<String> paths) onAddToBlock;

  const FoldersScreen({super.key, required this.api, required this.onAddToBlock});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  List<Map<String, dynamic>> _drives = [];
  String? _drive;
  String _path = '';
  List<Map<String, dynamic>> _folders = [];
  final Set<String> _sel = {};

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
    var p = _path.replaceAll(RegExp(r'\\$'), '');
    final i = p.lastIndexOf('\\');
    if (i > 1) _browse(p.substring(0, i + 1));
  }

  void _msg(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
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
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(_path,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _folders.length,
            itemBuilder: (context, i) {
              final f = _folders[i];
              final full = f['full'] as String;
              final on = _sel.contains(full);
              return CheckboxListTile(
                dense: true,
                title: Text(f['name'] as String),
                subtitle: Text(full,
                    style: const TextStyle(fontSize: 11)),
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
            label: 'Add ${_sel.length} to block list',
            icon: Icons.block,
            onTap: () async {
              widget.onAddToBlock(_sel.toList());
              if (mounted) {
                setState(() => _sel.clear());
                _msg('Added — open Profiles tab and press Save');
              }
            },
          ),
        ),
      ],
    );
  }
}

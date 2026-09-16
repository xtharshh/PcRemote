import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import '../api.dart';
import '../links.dart';
import '../widgets/ui.dart';
import '../widgets/windows_module.dart';

/// Phone-local gate: PIN + fingerprint + WiFi auto-find.
/// Nothing secret leaves the phone.
/// App name: Lumen Desk (same mark + name on Windows + Android).
class GateScreen extends StatefulWidget {
  final void Function(PcApi api) onUnlock;
  const GateScreen({super.key, required this.onUnlock});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  final _store = const FlutterSecureStorage();
  final _ip = TextEditingController(text: '192.168.1.4');
  final _pin = TextEditingController(text: '1234');
  String _pcName = '';
  bool _busy = false;
  String _note = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ip = await _store.read(key: 'pc_ip');
    final pin = await _store.read(key: 'pc_pin');
    final name = await _store.read(key: 'pc_name');
    if (ip != null && ip.isNotEmpty) _ip.text = ip;
    if (pin != null) _pin.text = pin;
    if (name != null) _pcName = name;
    if (mounted) setState(() {});
  }

  Future<void> _open({String? pcName}) async {
    if (_pin.text.trim().length < 4) {
      _msg('PIN too short');
      return;
    }
    final host = _ip.text.trim();
    final name = (pcName ?? _pcName).trim();
    setState(() => _busy = true);
    try {
      // Validate before entering: catches wrong IP / stopped daemon /
      // missing INTERNET permission with a friendly hint.
      final probe = await http
          .get(Uri.http('$host:5000', '/status'))
          .timeout(const Duration(seconds: 3));
      if (probe.statusCode != 200) throw Exception('HTTP ${probe.statusCode}');
      try {
        final m = jsonDecode(probe.body);
        if (m is Map && (m['pc'] ?? '').toString().isNotEmpty) {
          _pcName = (m['pc'] ?? name).toString();
        } else if (name.isNotEmpty) {
          _pcName = name;
        }
      } catch (_) {
        if (name.isNotEmpty) _pcName = name;
      }
      await _store.write(key: 'pc_ip', value: host);
      await _store.write(key: 'pc_pin', value: _pin.text.trim());
      await _store.write(key: 'pc_name', value: _pcName);
      widget.onUnlock(PcApi(host: host, pin: _pin.text.trim(), pcName: _pcName));
    } catch (e) {
      _msg(PcApi.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _biometric() async {
    final auth = LocalAuthentication();
    try {
      final ok = await auth.authenticate(
        localizedReason: 'Unlock Lumen Desk',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (ok) _open();
    } catch (_) {
      _msg('Biometric unavailable');
    }
  }

  /// Step 1: listen 2s for the PC's UDP beacon (no typing needed).
  /// Step 2 (fallback): sweep the /24 of the typed IP with GET /status.
  /// This fixes "WiFi scan blocked" on phones where UDP bind fails:
  /// the sweep uses plain HTTP which only needs INTERNET permission.
  Future<void> _find() async {
    setState(() {
      _busy = true;
      _note = 'Listening for your PC on WiFi…';
    });
    final found = <String, String>{};
    String failHint = '';
    try {
      final sock = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4, 59871,
          reuseAddress: true);
      sock.broadcastEnabled = true;
      final sub = sock.listen((e) {
        if (e == RawSocketEvent.read) {
          var dg = sock.receive();
          while (dg != null) {
            try {
              final m = jsonDecode(utf8.decode(dg.data));
              if (m is Map && m['app'] == 'PCRemote') {
                found[dg.address.address] =
                    (m['name'] ?? 'PC').toString();
              }
            } catch (_) {}
            dg = sock.receive();
          }
        }
      });
      await Future.delayed(const Duration(seconds: 2));
      await sub.cancel();
      sock.close();
    } on SocketException catch (e) {
      failHint = PcApi.friendlyError(e);
    } catch (e) {
      failHint = PcApi.friendlyError(e);
    }
    if (found.isEmpty && mounted) {
      setState(() => _note = 'No beacon — sweeping this WiFi network…');
      final sweep = await _sweepSubnet();
      for (final e in sweep.entries) {
        found[e.key] = e.value;
      }
      if (failHint.isNotEmpty && found.isEmpty) failHint = '$failHint (sweep found nothing either)';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = '';
    });
    if (found.isEmpty) {
      _msg(failHint.isEmpty
          ? 'No PC found — same WiFi? daemon running? (scripts/status_daemon.ps1)'
          : failHint);
      return;
    }
    final pick = await showDialog<MapEntry<String, String>>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Found on WiFi'),
        children: found.entries
            .map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(c, e),
                  child: Text('${e.value} · ${e.key}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ))
            .toList(),
      ),
    );
    if (pick != null) {
      setState(() {
        _ip.text = pick.key;
        _pcName = pick.value;
      });
      _msg('Picked ${pick.value} — tap Unlock app');
    }
  }

  /// Probe 192.168.X.1..254 (from the typed IP) for GET /status.
  /// 16 at a time, 800ms timeout each — ~12s worst case, usually <4s.
  Future<Map<String, String>> _sweepSubnet() async {
    final base = _subnetBase(_ip.text.trim());
    if (base == null) return {};
    final out = <String, String>{};
    final addrs =
        List.generate(254, (i) => '$base${i + 1}').where((a) => a != _ip.text.trim());
    // Probe in small batches with short timeout.
    for (var i = 0; i < addrs.length; i += 16) {
      if (!mounted) break;
      final batch = addrs.skip(i).take(16);
      final results = await Future.wait(batch.map((a) async {
        try {
          final r = await http
              .get(Uri.http('$a:5000', '/status'))
              .timeout(const Duration(milliseconds: 800));
          if (r.statusCode == 200) {
            final m = jsonDecode(r.body);
            final name = (m is Map ? (m['pc'] ?? 'PC') : 'PC').toString();
            return MapEntry(a, name);
          }
        } catch (_) {}
        return null;
      }));
      for (final e in results) {
        if (e != null) out[e.key] = e.value;
      }
      if (out.isNotEmpty) break; // stop at first hit
    }
    // Always include the typed IP if it answers.
    try {
      final r = await http
          .get(Uri.http('${_ip.text.trim()}:5000', '/status'))
          .timeout(const Duration(milliseconds: 1000));
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body);
        out[_ip.text.trim()] =
            (m is Map ? (m['pc'] ?? _pcName) : _pcName).toString();
      }
    } catch (_) {}
    return out;
  }

  String? _subnetBase(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    if (parts.any((p) => int.tryParse(p) == null)) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}.';
  }

  void _msg(String s) {
    setState(() => _note = s);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lumen Desk')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              shrinkWrap: true,
              children: [
                const Center(child: AppLogo(size: 88)),
                const SizedBox(height: 8),
                Center(
                  child: Text('Lumen Desk',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Center(
                  child: Text('Your PC, from your pocket',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                const SizedBox(height: 16),
                if (_pcName.isNotEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.computer),
                      title: Text(_pcName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Last PC · ${_ip.text.trim()}'),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ip,
                  decoration: const InputDecoration(
                    labelText: 'PC IP (same WiFi — or auto-find below)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pin,
                  decoration: const InputDecoration(
                    labelText: 'Phone PIN (stays on phone)',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _open,
                    child: Text(_busy ? 'Checking…' : 'Unlock app'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _biometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use fingerprint'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _find,
                    icon: const Icon(Icons.wifi_find),
                    label: Text(_busy ? 'Scanning WiFi…' : 'Find my PC on WiFi'),
                  ),
                ),
                if (_note.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_note, style: const TextStyle(fontSize: 13)),
                ],
                const SizedBox(height: 12),
                // First-time setup: the phone app needs the Windows
                // module running on the PC — downloadable from GitHub.
                const WindowsModuleCard(compact: true),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => AppLinks.openRepo(context),
                    child: const Text('View source on GitHub'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

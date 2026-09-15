import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../api.dart';

/// Phone-local gate: PIN + fingerprint + WiFi auto-find.
/// Nothing secret leaves the phone.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ip = await _store.read(key: 'pc_ip');
    final pin = await _store.read(key: 'pc_pin');
    if (ip != null) _ip.text = ip;
    if (pin != null) _pin.text = pin;
    if (mounted) setState(() {});
  }

  Future<void> _open() async {
    if (_pin.text.trim().length < 4) {
      _msg('PIN too short');
      return;
    }
    await _store.write(key: 'pc_ip', value: _ip.text.trim());
    await _store.write(key: 'pc_pin', value: _pin.text.trim());
    widget.onUnlock(PcApi(host: _ip.text.trim(), pin: _pin.text.trim()));
  }

  Future<void> _biometric() async {
    final auth = LocalAuthentication();
    try {
      final ok = await auth.authenticate(
        localizedReason: 'Unlock PC Remote',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (ok) _open();
    } catch (_) {
      _msg('Biometric unavailable');
    }
  }

  /// Listen 5s for the PC's UDP beacon — no typing needed.
  Future<void> _find() async {
    final found = <String, String>{};
    try {
      final sock = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4, 59871,
          reuseAddress: true);
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
      await Future.delayed(const Duration(seconds: 5));
      await sub.cancel();
      sock.close();
    } catch (_) {
      _msg('WiFi scan blocked — type IP by hand');
      return;
    }
    if (!mounted) return;
    if (found.isEmpty) {
      _msg('No PC found — same WiFi? daemon running?');
      return;
    }
    final pick = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Found on WiFi'),
        children: found.entries
            .map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(c, e.key),
                  child: Text('${e.value} (${e.key})'),
                ))
            .toList(),
      ),
    );
    if (pick != null) setState(() => _ip.text = pick);
  }

  void _msg(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PC Remote')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (context, v, _) =>
                      Transform.scale(scale: v, child: const Icon(Icons.computer, size: 64)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ip,
                  decoration: const InputDecoration(
                    labelText: 'PC IP (same WiFi)',
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
                    onPressed: _open,
                    child: const Text('Unlock app'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _biometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use fingerprint'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _find,
                    icon: const Icon(Icons.wifi_find),
                    label: const Text('Find my PC on WiFi'),
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

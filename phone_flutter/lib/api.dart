import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thin client for the PC daemon (src/pc_service/server.py).
/// Phone PIN/biometric never leaves the phone: only the X-PIN
/// approval header travels over your own LAN.
class PcApi {
  final String host;
  final int port;
  final String pin;

  const PcApi({required this.host, required this.pin, this.port = 5000});

  Uri _u(String path, [Map<String, String>? query]) =>
      Uri.http('$host:$port', path, query);

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? query]) async {
    final r = await http.get(_u(path, query)).timeout(
          const Duration(seconds: 10),
        );
    return _decode(r);
  }

  Future<Map<String, dynamic>> _post(String path,
      [Map<String, dynamic>? body]) async {
    final r = await http
        .post(
          _u(path),
          headers: {'X-PIN': pin, 'Content-Type': 'application/json'},
          body: jsonEncode(body ?? {}),
        )
        .timeout(const Duration(seconds: 15));
    return _decode(r);
  }

  Map<String, dynamic> _decode(http.Response r) {
    final j = jsonDecode(r.body.isEmpty ? '{}' : r.body);
    if (r.statusCode != 200) {
      throw Exception((j is Map ? j['err'] : null) ?? 'HTTP ${r.statusCode}');
    }
    return (j as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> status() => _get('/status');
  Future<Map<String, dynamic>> sense() => _get('/sense');
  Future<Map<String, dynamic>> profiles() => _get('/profiles');
  Future<Map<String, dynamic>> drives() => _get('/drives');
  Future<Map<String, dynamic>> folders(String path) =>
      _get('/folders', {'path': path});
  Future<Map<String, dynamic>> pick() => _get('/pick');

  Future<Map<String, dynamic>> lock() => _post('/lock');
  Future<Map<String, dynamic>> unlockApprove() => _post('/unlock-approve');
  Future<Map<String, dynamic>> setBrightness(int level) =>
      _post('/brightness', {'level': level});
  Future<Map<String, dynamic>> autoOnce() => _post('/auto-once');
  Future<Map<String, dynamic>> guestStart(String name) =>
      _post('/guest-start', {'name': name});
  Future<Map<String, dynamic>> guestStop(String name) =>
      _post('/guest-stop', {'name': name});
  Future<Map<String, dynamic>> profileGet(String name) =>
      _post('/profile-get', {'name': name});
  Future<Map<String, dynamic>> profileSave(String name, Map<String, dynamic> data) =>
      _post('/profile-save', {'name': name, 'data': data});
}

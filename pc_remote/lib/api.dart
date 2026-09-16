import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thin client for the PC daemon (src/pc_service/server.py).
/// Phone PIN/biometric never leaves the phone: only the X-PIN
/// approval header travels over your own LAN.
///
/// [pcName] is the WiFi-discovered PC hostname (e.g. "DESKTOP-A1B2").
/// The Home screen shows this name — never a raw IP.
class PcApi {
  final String host;
  final int port;
  final String pin;
  final String pcName;

  const PcApi(
      {required this.host,
      required this.pin,
      this.port = 5000,
      this.pcName = ''});

  /// What the UI should call the PC: discovered name, else host.
  String get displayName => pcName.isNotEmpty ? pcName : host;

  PcApi copyWith({String? host, int? port, String? pin, String? pcName}) =>
      PcApi(
        host: host ?? this.host,
        port: port ?? this.port,
        pin: pin ?? this.pin,
        pcName: pcName ?? this.pcName,
      );

  Uri _u(String path, [Map<String, String>? query]) =>
      Uri.http('$host:$port', path, query);

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? query]) async {
    final r = await http
        .get(_u(path, query))
        .timeout(const Duration(seconds: 10));
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
    final dynamic j = jsonDecode(r.body.isEmpty ? '{}' : r.body);
    if (r.statusCode != 200) {
      throw Exception(
          (j is Map ? j['err'] : null) ?? 'HTTP ${r.statusCode}');
    }
    return (j as Map).cast<String, dynamic>();
  }

  /// Human-readable network error for a SnackBar / note line.
  /// Maps the raw SocketException from the screenshot
  /// ("Operation not permitted, errno = 1") to an actionable hint.
  static String friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('TimeoutException') ||
        s.contains('Future not completed')) {
      return 'PC didn\u2019t answer in time \u2014 wrong IP? daemon stopped? different WiFi? firewall blocking TCP 5000?';
    }
    if (s.contains('Operation not permitted') || s.contains('errno = 1')) {
      return 'Blocked by Android: reinstall the latest APK, allow WiFi/location, and join the same WiFi as your PC.';
    }
    if (s.contains('Connection refused')) {
      return 'PC refused — is the daemon running? (scripts/status_daemon.ps1)';
    }
    if (s.contains('Connection timed out') || s.contains('No route to host')) {
      return 'No route — same WiFi? Firewall rule for TCP 5000? ($s)';
    }
    if (s.contains('Failed host lookup') || s.contains('No address')) {
      return 'Bad IP/hostname — tap “Find my PC on WiFi” again.';
    }
    if (s.contains('401') || s.contains('wrong phone PIN')) {
      return 'Wrong PIN — re-run install with your PIN.';
    }
    return s.replaceFirst('Exception: ', '');
  }

  Future<Map<String, dynamic>> status() => _get('/status');
  Future<Map<String, dynamic>> sense() => _get('/sense');
  Future<Map<String, dynamic>> drives() => _get('/drives');
  Future<Map<String, dynamic>> folders(String path) =>
      _get('/folders', {'path': path});
  Future<Map<String, dynamic>> pick() => _get('/pick');

  Future<Map<String, dynamic>> lock() => _post('/lock');
  Future<Map<String, dynamic>> unlockApprove() => _post('/unlock-approve');
  Future<Map<String, dynamic>> power(String action,
          {int inMinutes = 0}) =>
      _post('/power', {'action': action, 'in_minutes': inMinutes});
  Future<Map<String, dynamic>> powerCancel([String? action]) =>
      _post('/power-cancel', action == null ? {} : {'action': action});
  Future<Map<String, dynamic>> setBrightness(int level) =>
      _post('/brightness', {'level': level});
  Future<Map<String, dynamic>> autoOnce() => _post('/auto-once');
  Future<Map<String, dynamic>> setAuto(bool on) =>
      _post('/auto', {'on': on});
  Future<Map<String, dynamic>> guestStart(String name) =>
      _post('/guest-start', {'name': name});
  Future<Map<String, dynamic>> guestStop(String name) =>
      _post('/guest-stop', {'name': name});
  Future<Map<String, dynamic>> profileGet(String name) =>
      _post('/profile-get', {'name': name});
  Future<Map<String, dynamic>> profileSave(
          String name, Map<String, dynamic> data) =>
      _post('/profile-save', {'name': name, 'data': data});
}

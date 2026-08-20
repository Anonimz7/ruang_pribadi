import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

/// Thrown when the server returns 401 (token expired / invalid).
class SessionExpiredException implements Exception {
  final String message;
  const SessionExpiredException([this.message = 'Sesi login telah berakhir']);
  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _i = ApiClient._();
  factory ApiClient() => _i;
  ApiClient._();

  /// Called when a 401 is received. Set from the app layer to trigger
  /// a popup + automatic logout.
  VoidCallback? onSessionExpired;

  final _storage = const FlutterSecureStorage();
  String? _token;
  List<String> _permissions = [];
  List<String> _hiddenMenus = [];
  String _username = '';
  String _tier = '';

  bool get isLoggedIn => _token != null;
  String get username => _username;
  String get tier => _tier;
  List<String> get permissions => _permissions;
  List<String> get hiddenMenus => _hiddenMenus;

  Future<String?> get token async {
    _token ??= await _storage.read(key: 'jwt_token');
    return _token;
  }

  bool canAccess(String appKey) {
    if (_tier == 'admin') return true;
    return _permissions.contains(appKey);
  }

  bool isMenuHidden(String appKey) {
    return _hiddenMenus.contains(appKey);
  }

  Future<Map<String, String>> get _headers async {
    final t = await token;
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t'
    };
  }

  Future<void> saveSession(String t, Map<String, dynamic> user) async {
    _token = t;
    _username = user['username'] ?? '';
    _tier = user['tier'] ?? 'guest';
    _permissions = List<String>.from(user['permissions'] ?? []);
    _hiddenMenus = List<String>.from(user['hidden_menus'] ?? []);
    await _storage.write(key: 'jwt_token', value: t);
    await _storage.write(key: 'user_data', value: jsonEncode(user));
  }

  Future<void> loadSession() async {
    _token = await _storage.read(key: 'jwt_token');
    final data = await _storage.read(key: 'user_data');
    if (data != null) {
      final u = jsonDecode(data);
      _username = u['username'] ?? '';
      _tier = u['tier'] ?? 'guest';
      _permissions = List<String>.from(u['permissions'] ?? []);
      _hiddenMenus = List<String>.from(u['hidden_menus'] ?? []);
    }
  }

  Future<void> clearSession() async {
    _token = null;
    _username = '';
    _tier = '';
    _permissions = [];
    _hiddenMenus = [];
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_data');
  }

  Future<dynamic> get(String path, [Map<String, String>? params]) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.prefix}$path')
        .replace(queryParameters: params);
    try {
      final r = await http
          .get(uri, headers: await _headers)
          .timeout(const Duration(seconds: 30));
      return _handle(r);
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Cek koneksi internet.');
    } on TimeoutException {
      throw Exception('Tidak dapat terhubung ke server. Silakan coba lagi.');
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.prefix}$path');
    try {
      final r = await http
          .post(uri, headers: await _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      return _handle(r);
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Cek koneksi internet.');
    } on TimeoutException {
      throw Exception('Tidak dapat terhubung ke server. Silakan coba lagi.');
    }
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.prefix}$path');
    try {
      final r = await http
          .put(uri, headers: await _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      return _handle(r);
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Cek koneksi internet.');
    } on TimeoutException {
      throw Exception('Tidak dapat terhubung ke server. Silakan coba lagi.');
    }
  }

  Future<dynamic> delete(String path) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.prefix}$path');
    try {
      final r = await http
          .delete(uri, headers: await _headers)
          .timeout(const Duration(seconds: 30));
      return _handle(r);
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Cek koneksi internet.');
    } on TimeoutException {
      throw Exception('Tidak dapat terhubung ke server. Silakan coba lagi.');
    }
  }

  Future<dynamic> multipartPost(String path, String filePath,
      {String fieldName = 'file', Map<String, String>? extraFields}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.prefix}$path');
    try {
      final t = await token;
      final request = http.MultipartRequest('POST', uri);
      if (t != null) request.headers['Authorization'] = 'Bearer $t';
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
      if (extraFields != null) request.fields.addAll(extraFields);
      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      return _handle(response);
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Cek koneksi internet.');
    } on TimeoutException {
      throw Exception('Tidak dapat terhubung ke server. Silakan coba lagi.');
    }
  }

  dynamic _handle(http.Response r) {
    final body = jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    // ── 401 Unauthorized ──
    if (r.statusCode == 401) {
      // Only trigger session-expired flow when the user already has a token
      // (i.e. an existing session expired). For login/register attempts
      // (no token yet), just throw a regular error so the dialog can
      // display the message (e.g. "Invalid credentials").
      if (_token != null && onSessionExpired != null) {
        Future.microtask(() => onSessionExpired!());
        throw const SessionExpiredException();
      }
      throw Exception(body['detail'] ?? 'Username atau password salah');
    }
    throw Exception(body['detail'] ?? 'Error ${r.statusCode}');
  }
}

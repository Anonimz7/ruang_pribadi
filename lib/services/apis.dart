import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';
import 'api_config.dart';
import '../news_intel/models/stock_models.dart';

// ─── Auth ────────────────────────────────────────────────────────────────────

class AuthApi {
  final _c = ApiClient();

  Future<bool> login(String user, String pass) async {
    final r =
        await _c.post('/auth/login', {'username': user, 'password': pass});
    if (r['access_token'] != null) {
      await _c.saveSession(r['access_token'], r['user'] ?? {});
      return true;
    }
    return false;
  }

  Future<bool> register(String user, String pass) async {
    await _c.post('/auth/register', {'username': user, 'password': pass});
    return true;
  }

  Future<void> logout() => _c.clearSession();

  Future<Map<String, dynamic>> me() async {
    final r = await _c.get('/auth/me');
    await _c.saveSession(await _c.token ?? '', r);
    return r;
  }

  /// [POST /auth/change-password] — Ganti password
  Future<Map<String, dynamic>> changePassword(
          String oldPassword, String newPassword) async =>
      (await _c.post('/auth/change-password', {
        'old_password': oldPassword,
        'new_password': newPassword
      })) as Map<String, dynamic>;
}

// ─── News ────────────────────────────────────────────────────────────────────

class NewsApi {
  final _c = ApiClient();

  Future<Map<String, dynamic>> articles({
    int hours = 24,
    String? domain,
    String? search,
    int page = 1,
  }) async =>
      (await _c.get('/news/articles', {
        'since_hours': '$hours',
        'page': '$page',
        'per_page': '50',
        if (domain != null) 'domain': domain,
        if (search != null && search.isNotEmpty) 'search': search,
      })) as Map<String, dynamic>;

  Future<List<dynamic>> domains() async {
    final r = await _c.get('/news/domains');
    return r is List ? r : [];
  }

  /// [GET /news/articles/grouped] — Artikel grouped per domain
  Future<Map<String, dynamic>> groupedArticles({int hours = 24}) async =>
      (await _c.get('/news/articles/grouped', {'since_hours': '$hours'}))
          as Map<String, dynamic>;
}

// ─── Stocks / IDX ────────────────────────────────────────────────────────────

class StockApi {
  final _c = ApiClient();

  // ── Raw (dynamic) methods — kept for backward compatibility ──

  Future<List<dynamic>> search(String q) async {
    final r = await _c.get('/idx/stocks', {'q': q});
    return r is List ? r : [];
  }

  Future<Map<String, dynamic>> analysis(String ticker, {int days = 90}) async =>
      (await _c.get('/idx/stocks/$ticker/analysis', {'days': '$days'}))
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> summary({int days = 90}) async =>
      (await _c.get('/idx/market/summary', {'days': '$days'}))
          as Map<String, dynamic>;

  /// [GET /idx/stocks/{ticker}] — Detail / profile satu saham
  Future<Map<String, dynamic>> stockDetail(String ticker) async =>
      (await _c.get('/idx/stocks/$ticker')) as Map<String, dynamic>;

  // ── Typed methods (recommended) ──────────────────────────────────────────

  /// Search saham by ticker atau nama — returns typed [StockListItem] list.
  Future<List<StockListItem>> searchTyped(String q) async {
    final r = await _c.get('/idx/stocks', {'q': q});
    // Endpoint returns {total, stocks}; extract the list.
    final list = r is List ? r : (r as Map<String, dynamic>)['stocks'];
    if (list is! List) return [];
    return list
        .map((e) => StockListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// List semua saham dengan paginasi — returns [StockListResponse].
  ///
  /// ```dart
  /// final res = await api.stockList(limit: 100, offset: 0);
  /// print('${res.total} saham total, showing ${res.stocks.length}');
  /// ```
  ///
  /// [q] filters by ticker/name (server-side), [sector], [primarySector] and
  /// [subSector] cascade as a 3-level sector filter (server-side) — all
  /// combined with pagination so the total is accurate.
  Future<StockListResponse> stockList({
    int limit = 100,
    int offset = 0,
    String q = '',
    String sector = '',
    String primarySector = '',
    String subSector = '',
  }) async {
    final r = await _c.get('/idx/stocks', {
      'limit': '$limit',
      'offset': '$offset',
      if (q.isNotEmpty) 'q': q,
      if (sector.isNotEmpty) 'sector': sector,
      if (primarySector.isNotEmpty) 'primary_sector': primarySector,
      if (subSector.isNotEmpty) 'sub_sector': subSector,
    });
    return StockListResponse.fromJson(r as Map<String, dynamic>);
  }

  /// [GET /idx/sectors] — cascading sector filter options.
  ///
  /// No params → all sectors. `sector:` → primary sub-sectors under it.
  /// `sector:` + `primarySector:` → sub-sectors under that pair.
  Future<List<String>> sectorOptions({
    String sector = '',
    String primarySector = '',
  }) async {
    final r = await _c.get('/idx/sectors', {
      if (sector.isNotEmpty) 'sector': sector,
      if (primarySector.isNotEmpty) 'primary_sector': primarySector,
    });
    return (r as List?)?.map((e) => '$e').toList() ?? [];
  }

  /// Detail profile satu saham — returns typed [StockProfile].
  Future<StockProfile> stockProfile(String ticker) async {
    final r = await _c.get('/idx/stocks/$ticker');
    return StockProfile.fromJson(r as Map<String, dynamic>);
  }

  /// Analisis lengkap satu saham — returns typed [StockAnalysis].
  Future<StockAnalysis> stockAnalysis(String ticker, {int days = 90}) async {
    final r = await _c.get('/idx/stocks/$ticker/analysis', {'days': '$days'});
    return StockAnalysis.fromJson(r as Map<String, dynamic>);
  }

  /// [GET /idx/market/radar] — Market radar
  Future<List<dynamic>> radar({int days = 30}) async {
    final r = await _c.get('/idx/market/radar', {'days': '$days'});
    return r is List ? r : [];
  }

  /// [GET /idx/market/top-foreign-flow] — Top foreign flow
  Future<List<dynamic>> topForeignFlow({int days = 30}) async {
    final r = await _c.get('/idx/market/top-foreign-flow', {'days': '$days'});
    return r is List ? r : [];
  }

  /// [GET /idx/market/top-domination] — Top domination
  Future<List<dynamic>> topDomination({int days = 30}) async {
    final r = await _c.get('/idx/market/top-domination', {'days': '$days'});
    return r is List ? r : [];
  }

  /// [GET /idx/status] — Status IDX scraper
  Future<Map<String, dynamic>> status() async =>
      (await _c.get('/idx/status')) as Map<String, dynamic>;

  /// [POST /idx/upload] — Upload file XLSX (admin only)
  Future<Map<String, dynamic>> upload(String filePath) async =>
      (await _c.multipartPost('/idx/upload', filePath, fieldName: 'file'))
          as Map<String, dynamic>;
}

// ─── Sitemaps ────────────────────────────────────────────────────────────────

class SitemapApi {
  final _c = ApiClient();

  /// [GET /sitemaps/] — List semua sitemaps
  Future<List<dynamic>> list() async {
    final r = await _c.get('/sitemaps/');
    return r is List ? r : [];
  }

  /// [POST /sitemaps/] — Tambah sitemap baru
  Future<Map<String, dynamic>> add(String url, String language) async =>
      (await _c.post('/sitemaps/', {'url': url, 'language': language}))
          as Map<String, dynamic>;

  /// [DELETE /sitemaps/{index}] — Hapus sitemap by index
  Future<Map<String, dynamic>> delete(int index) async =>
      (await _c.delete('/sitemaps/$index')) as Map<String, dynamic>;

  /// [GET /sitemaps/languages] — Get language mapping
  Future<Map<String, dynamic>> languages() async =>
      (await _c.get('/sitemaps/languages')) as Map<String, dynamic>;

  /// [PUT /sitemaps/languages] — Update language mapping
  Future<Map<String, dynamic>> updateLanguages(
          Map<String, dynamic> mapping) async =>
      (await _c.put('/sitemaps/languages', mapping)) as Map<String, dynamic>;
}

// ─── Reports ─────────────────────────────────────────────────────────────────

class ReportApi {
  final _c = ApiClient();

  /// [GET /reports/last] — Info laporan terakhir + auto_send pref
  Future<Map<String, dynamic>> last() async =>
      (await _c.get('/reports/last')) as Map<String, dynamic>;

  /// [POST /reports/generate] — Generate laporan (4 kategori, 7 file)
  Future<Map<String, dynamic>> generate({int sinceHours = 24}) async =>
      (await _c.post('/reports/generate', {'since_hours': sinceHours}))
          as Map<String, dynamic>;

  /// [GET /reports/files] — List all generated CSV report files
  Future<Map<String, dynamic>> listFiles() async =>
      (await _c.get('/reports/files')) as Map<String, dynamic>;

  /// Download a CSV report file to local storage.
  /// Returns the saved file path.
  Future<String> downloadFile(String remotePath, String localFilename) async {
    final t = await _c.token;
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.prefix}/reports/download/$remotePath');
    final response = await http.get(uri, headers: {
      if (t != null) 'Authorization': 'Bearer $t',
    }).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    // Save to app's temp directory
    final savePath = '${Directory.systemTemp.path}/$localFilename';
    final file = File(savePath);
    await file.writeAsBytes(response.bodyBytes);
    return savePath;
  }

  /// [PUT /reports/preferences] — Update auto_send preference
  Future<Map<String, dynamic>> updatePreferences(
          {required bool autoSend}) async =>
      (await _c.put('/reports/preferences', {'auto_send': autoSend}))
          as Map<String, dynamic>;
}

// ─── Admin ───────────────────────────────────────────────────────────────────

class AdminApi {
  final _c = ApiClient();

  /// [GET /admin/stats] — Statistik server & DB
  Future<Map<String, dynamic>> stats() async =>
      (await _c.get('/admin/stats')) as Map<String, dynamic>;

  /// [GET /admin/system-status] — Status maintenance/registration/scraper
  Future<Map<String, dynamic>> systemStatus() async =>
      (await _c.get('/admin/system-status')) as Map<String, dynamic>;

  Future<List<dynamic>> getUsers() async {
    final r = await _c.get('/admin/users');
    return r is List ? r : [];
  }

  /// [GET /admin/users?q=...] — Search users by username
  Future<List<dynamic>> searchUsers(String query) async {
    final r = await _c.get('/admin/users', {'q': query});
    return r is List ? r : [];
  }

  /// [POST /admin/users] — Create a new user (admin only)
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String password,
    String tier = 'guest',
    List<String>? permissions,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'password': password,
      'tier': tier,
    };
    if (permissions != null) body['permissions'] = permissions;
    return (await _c.post('/admin/users', body)) as Map<String, dynamic>;
  }

  /// [GET /admin/users/{id}] — Get full user detail
  Future<Map<String, dynamic>> getUserDetail(int userId) async =>
      (await _c.get('/admin/users/$userId')) as Map<String, dynamic>;

  Future<List<String>> getAllApps() async {
    final r = await _c.get('/admin/apps');
    return List<String>.from(r['apps'] ?? []);
  }

  /// [GET /admin/my/permissions] — Ambil permission sendiri
  Future<Map<String, dynamic>> myPermissions() async =>
      (await _c.get('/admin/my/permissions')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> getUserPermissions(int userId) async =>
      (await _c.get('/admin/users/$userId/permissions'))
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> setPermissions(
          int userId, List<String> perms) async =>
      (await _c.put('/admin/users/$userId/permissions', {'permissions': perms}))
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> grantPermission(
          int userId, String appKey) async =>
      (await _c.post(
              '/admin/users/$userId/permissions/grant', {'app_key': appKey}))
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> revokePermission(
          int userId, String appKey) async =>
      (await _c.post(
              '/admin/users/$userId/permissions/revoke', {'app_key': appKey}))
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> getDefaultPermissions() async =>
      (await _c.get('/admin/default-permissions')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> setDefaultPermissions(
          List<String> perms) async =>
      (await _c.put('/admin/default-permissions', {'permissions': perms}))
          as Map<String, dynamic>;

  /// [PUT /admin/users/{user_id}/tier] — Update tier user
  Future<Map<String, dynamic>> updateTier(int userId, String tier) async =>
      (await _c.put('/admin/users/$userId/tier', {'tier': tier}))
          as Map<String, dynamic>;

  /// [DELETE /admin/users/{user_id}] — Hapus user
  Future<Map<String, dynamic>> deleteUser(int userId) async =>
      (await _c.delete('/admin/users/$userId')) as Map<String, dynamic>;

  // ─── Visibility (Hide/Show Menus) ──────────────

  /// [GET /admin/users/{id}/visibility] — Get hidden menus
  Future<Map<String, dynamic>> getVisibility(int userId) async =>
      (await _c.get('/admin/users/$userId/visibility')) as Map<String, dynamic>;

  /// [PUT /admin/users/{id}/visibility] — Set hidden menus (replace)
  Future<Map<String, dynamic>> setVisibility(
          int userId, List<String> hiddenMenus) async =>
      (await _c.put(
              '/admin/users/$userId/visibility', {'hidden_menus': hiddenMenus}))
          as Map<String, dynamic>;

  /// [POST /admin/users/{id}/visibility/hide] — Hide one menu
  Future<Map<String, dynamic>> hideMenu(int userId, String appKey) async =>
      (await _c.post(
              '/admin/users/$userId/visibility/hide', {'app_key': appKey}))
          as Map<String, dynamic>;

  /// [POST /admin/users/{id}/visibility/show] — Show one menu
  Future<Map<String, dynamic>> showMenu(int userId, String appKey) async =>
      (await _c.post(
              '/admin/users/$userId/visibility/show', {'app_key': appKey}))
          as Map<String, dynamic>;

  /// [POST /admin/maintenance] — Toggle mode maintenance
  Future<Map<String, dynamic>> toggleMaintenance(
          {required bool enabled}) async =>
      (await _c.post('/admin/maintenance', {'enabled': enabled}))
          as Map<String, dynamic>;

  /// [POST /admin/registration] — Toggle mode registrasi
  Future<Map<String, dynamic>> toggleRegistration(
          {required bool enabled}) async =>
      (await _c.post('/admin/registration', {'enabled': enabled}))
          as Map<String, dynamic>;

  /// [POST /admin/scraper/run] — Jalankan scraper manual
  Future<Map<String, dynamic>> runScraper() async =>
      (await _c.post('/admin/scraper/run', {})) as Map<String, dynamic>;

  /// [GET /admin/proxies] — Ambil daftar proxy dan status Webshare key
  Future<Map<String, dynamic>> proxySettings() async =>
      (await _c.get('/admin/proxies')) as Map<String, dynamic>;

  /// [PUT /admin/proxies] — Simpan daftar proxy dan Webshare API key baru
  Future<Map<String, dynamic>> saveProxySettings({
    required String proxies,
    String? webshareApiKey,
  }) async {
    final body = <String, dynamic>{'proxies': proxies};
    if (webshareApiKey != null) body['webshare_api_key'] = webshareApiKey;
    return (await _c.put('/admin/proxies', body)) as Map<String, dynamic>;
  }

  /// [POST /admin/proxies/test] — Uji koneksi semua proxy tersimpan
  Future<Map<String, dynamic>> testProxies() async =>
      (await _c.post('/admin/proxies/test', {})) as Map<String, dynamic>;

  /// [POST /admin/proxies/webshare/sync] — Ambil proxy dari Webshare
  Future<Map<String, dynamic>> syncWebshareProxies() async =>
      (await _c.post('/admin/proxies/webshare/sync', {}))
          as Map<String, dynamic>;

  /// [GET /admin/proxies/logs] — Lihat log pengujian proxy
  Future<Map<String, dynamic>> proxyLogs({int lines = 80}) async =>
      (await _c.get('/admin/proxies/logs', {'lines': '$lines'}))
          as Map<String, dynamic>;

  /// [POST /admin/proxies/webshare/test] — Uji koneksi API key Webshare
  Future<Map<String, dynamic>> testWebshareKey() async =>
      (await _c.post('/admin/proxies/webshare/test', {}))
          as Map<String, dynamic>;

  /// [GET /admin/logs/{log_type}] — Lihat log scraper
  Future<Map<String, dynamic>> logs(String logType, {int lines = 50}) async =>
      (await _c.get('/admin/logs/$logType', {'lines': '$lines'}))
          as Map<String, dynamic>;
}

// ─── Backup ─────────────────────────────────────────────────────────────────

class BackupApi {
  final _c = ApiClient();

  /// [POST /admin/backup/run] — Jalankan backup (async)
  Future<Map<String, dynamic>> runBackup() async =>
      (await _c.post('/admin/backup/run', {})) as Map<String, dynamic>;

  /// [GET /admin/backup/status] — Status backup saat ini
  Future<Map<String, dynamic>> backupStatus() async =>
      (await _c.get('/admin/backup/status')) as Map<String, dynamic>;

  /// [GET /admin/backup/history] — Riwayat backup
  Future<Map<String, dynamic>> backupHistory() async =>
      (await _c.get('/admin/backup/history')) as Map<String, dynamic>;

  /// [DELETE /admin/backup/{filename}] — Hapus file backup
  Future<Map<String, dynamic>> deleteBackup(String filename) async =>
      (await _c.delete('/admin/backup/$filename')) as Map<String, dynamic>;

  /// Build full download URL with auth token for browser-based download
  Future<String> getDownloadUrl(String filename) async {
    final t = await _c.token;
    return '${ApiConfig.baseUrl}${ApiConfig.prefix}/admin/backup/download/$filename?token=$t';
  }

  /// Download backup file to local storage.
  Future<String> downloadBackup(String remotePath, String localFilename) async {
    final t = await _c.token;
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.prefix}/admin/backup/download/$remotePath');
    final response = await http.get(uri, headers: {
      if (t != null) 'Authorization': 'Bearer $t',
    }).timeout(const Duration(seconds: 120));
    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }
    final savePath = '${Directory.systemTemp.path}/$localFilename';
    final file = File(savePath);
    await file.writeAsBytes(response.bodyBytes);
    return savePath;
  }

  // ── Google Drive ──

  Future<Map<String, dynamic>> gdriveInfo() async =>
      (await _c.get('/admin/backup/gdrive/info')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> gdriveAuth() async =>
      (await _c.post('/admin/backup/gdrive/auth', {})) as Map<String, dynamic>;

  Future<Map<String, dynamic>> gdriveExchangeCode(String code) async =>
      (await _c.post('/admin/backup/gdrive/code', {'code': code}))
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> gdriveDisconnect() async =>
      (await _c.post('/admin/backup/gdrive/disconnect', {}))
          as Map<String, dynamic>;
}

// ─── Update (APK Management) ────────────────────────────────────────────────

class UpdateApi {
  final _c = ApiClient();

  /// [POST /admin/update/upload] — Upload APK with progress callback
  Future<Map<String, dynamic>> uploadApk({
    required String filePath,
    required String versionName,
    required int versionCode,
    String changelog = '',
    Function(double progress)? onProgress,
  }) async {
    final t = await _c.token;
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.prefix}/admin/update/upload');

    final file = File(filePath);
    final fileBytes = await file.readAsBytes();
    final totalBytes = fileBytes.length;

    // Wrap bytes in a stream that reports progress
    late Stream<List<int>> byteStream;
    if (onProgress != null && totalBytes > 0) {
      byteStream = _progressStream(fileBytes, totalBytes, onProgress);
    } else {
      byteStream = Stream.value(fileBytes);
    }

    final multipartFile = http.MultipartFile(
      'file',
      byteStream,
      totalBytes,
      filename: filePath.split(Platform.pathSeparator).last,
    );

    final request = http.MultipartRequest('POST', uri);
    if (t != null) request.headers['Authorization'] = 'Bearer $t';
    request.files.add(multipartFile);
    request.fields['version_name'] = versionName;
    request.fields['version_code'] = '$versionCode';
    request.fields['changelog'] = changelog;

    final streamed = await request.send().timeout(const Duration(seconds: 300));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Upload failed');
  }

  /// Yields file bytes in chunks while reporting progress
  Stream<List<int>> _progressStream(
    List<int> bytes,
    int total,
    Function(double) onProgress,
  ) async* {
    const chunkSize = 256 * 1024; // 256 KB chunks
    int offset = 0;
    while (offset < bytes.length) {
      final end = (offset + chunkSize).clamp(0, bytes.length);
      yield bytes.sublist(offset, end);
      offset = end;
      onProgress(offset / total);
    }
  }

  /// [GET /admin/update/versions] — List all versions
  Future<List<dynamic>> getVersions() async {
    final r = await _c.get('/admin/update/versions');
    return (r is Map ? r['versions'] : r) as List<dynamic>? ?? [];
  }

  /// [PUT /admin/update/{id}/active] — Set version as active
  Future<Map<String, dynamic>> setActive(int versionId) async =>
      (await _c.put('/admin/update/$versionId/active', {}))
          as Map<String, dynamic>;

  /// [DELETE /admin/update/{id}] — Delete version
  Future<Map<String, dynamic>> deleteVersion(int versionId) async =>
      (await _c.delete('/admin/update/$versionId')) as Map<String, dynamic>;

  /// [PUT /admin/update/{id}] — Update changelog
  Future<Map<String, dynamic>> updateChangelog(
          int versionId, String changelog) async =>
      (await _c.put('/admin/update/$versionId', {'changelog': changelog}))
          as Map<String, dynamic>;
}

// ─── Video Downloader ────────────────────────────────────────────────────────

class VideoApi {
  final _c = ApiClient();

  /// [POST /video/extract] — Extract video info from URL
  Future<Map<String, dynamic>> extract(String url) async {
    return (await _c.post('/video/extract', {'url': url}))
        as Map<String, dynamic>;
  }

  /// [POST /video/download] — Start download in background
  Future<Map<String, dynamic>> download(String url, String formatId,
      {bool audioOnly = false, String? title}) async {
    return (await _c.post('/video/download', {
      'url': url,
      'format_id': formatId,
      'audio_only': audioOnly,
      if (title != null) 'title': title,
    })) as Map<String, dynamic>;
  }

  /// [GET /video/status/{download_id}] — Get download status by filename/id
  Future<Map<String, dynamic>> downloadStatus(String downloadId) async {
    final r = await _c.get('/video/status/$downloadId');
    if (r is Map && r['data'] is Map)
      return Map<String, dynamic>.from(r['data']);
    return r is Map ? Map<String, dynamic>.from(r) : {};
  }

  /// [GET /video/history] — Get download history
  Future<List<dynamic>> history() async {
    final r = await _c.get('/video/history');
    if (r is Map && r['data'] is List) return r['data'] as List;
    return r is List ? r : [];
  }

  /// [GET /video/active] — Get currently active downloads
  Future<List<dynamic>> activeDownloads() async {
    final r = await _c.get('/video/active');
    if (r is Map && r['data'] is List) return r['data'] as List;
    return r is List ? r : [];
  }

  /// [DELETE /video/{file_name}] — Delete a downloaded video
  Future<Map<String, dynamic>> deleteVideo(String fileName) async {
    final encodedName = Uri.encodeComponent(fileName);
    return (await _c.delete('/video/$encodedName')) as Map<String, dynamic>;
  }

  /// [POST /video/cancel/{download_id}] — Cancel an active download
  Future<Map<String, dynamic>> cancelDownload(String downloadId) async {
    final encodedId = Uri.encodeComponent(downloadId);
    return (await _c.post('/video/cancel/$encodedId', {}))
        as Map<String, dynamic>;
  }

  /// Get stream URL for playing a downloaded video
  String streamUrl(String fileName) {
    final userId = ApiClient().username;
    final encodedName = Uri.encodeComponent(fileName);
    return '${ApiConfig.baseUrl}${ApiConfig.prefix}/video/download-file/$userId/$encodedName';
  }

  // ── Admin: Cookies Management ──

  /// [POST /admin/update/cookies] — Upload cookies.txt (admin only)
  Future<Map<String, dynamic>> uploadCookies(String filePath) async {
    final t = await _c.token;
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.prefix}/admin/update/cookies');
    final request = http.MultipartRequest('POST', uri);
    if (t != null) request.headers['Authorization'] = 'Bearer $t';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Upload failed');
  }
}

// ─── Bahasa (Kamus Pasangan Kata) ───────────────────────────────────────────

class BahasaApi {
  final _c = ApiClient();

  /// [GET /bahasa/pairs] — Pasangan bahasa unik + jumlah dokumen
  Future<List<dynamic>> pairs() async {
    final r = await _c.get('/bahasa/pairs');
    return r is List ? r : [];
  }

  /// [GET /bahasa?lang=...] — Daftar dokumen (kosong = semua bahasa)
  Future<List<dynamic>> list({String lang = '', int limit = 200}) async {
    final r = await _c.get('/bahasa', {
      if (lang.isNotEmpty) 'lang': lang,
      'limit': '$limit',
    });
    return r is List ? r : [];
  }

  /// [GET /bahasa/{id}] — Detail dokumen + list entri {a, b}
  Future<Map<String, dynamic>> get(int id) async =>
      (await _c.get('/bahasa/$id')) as Map<String, dynamic>;

  /// [POST /bahasa] — Buat dokumen (admin)
  Future<Map<String, dynamic>> create({
    required String stringLang,
    required String judul,
    required String langSource,
  }) async =>
      (await _c.post('/bahasa', {
        'string_lang': stringLang,
        'judul': judul,
        'lang_source': langSource,
      })) as Map<String, dynamic>;

  /// [PUT /bahasa/{id}] — Update dokumen (admin)
  Future<Map<String, dynamic>> update({
    required int id,
    required String stringLang,
    required String judul,
    required String langSource,
  }) async =>
      (await _c.put('/bahasa/$id', {
        'string_lang': stringLang,
        'judul': judul,
        'lang_source': langSource,
      })) as Map<String, dynamic>;

  /// [DELETE /bahasa/{id}] — Hapus dokumen (admin)
  Future<Map<String, dynamic>> delete(int id) async =>
      (await _c.delete('/bahasa/$id')) as Map<String, dynamic>;
}

// ─── WebSocket ───────────────────────────────────────────────────────────────

class WebSocketService {
  WebSocketChannel? _scraperChannel;
  WebSocketChannel? _notificationChannel;
  WebSocketChannel? _backupChannel;

  final _scraperController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _backupController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get scraperStatus => _scraperController.stream;
  Stream<Map<String, dynamic>> get notifications =>
      _notificationController.stream;
  Stream<Map<String, dynamic>> get backupProgress => _backupController.stream;

  bool get isConnected =>
      _scraperChannel != null || _notificationChannel != null;

  /// Hubungkan ke [WS /ws/scraper-status] — real-time status scraper
  Future<void> connectScraperStatus() async {
    final t = await ApiClient().token;
    final wsUrl =
        '${ApiConfig.baseUrl.replaceFirst('http', 'ws')}/ws/scraper-status'
        '${t != null ? '?token=$t' : ''}';
    _scraperChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _scraperChannel!.stream.listen(
      (data) {
        try {
          _scraperController.add(jsonDecode(data));
        } catch (_) {}
      },
      onDone: () => disconnectScraperStatus(),
      onError: (_) => disconnectScraperStatus(),
    );
  }

  void disconnectScraperStatus() {
    _scraperChannel?.sink.close();
    _scraperChannel = null;
  }

  /// Hubungkan ke [WS /ws/notifications] — channel notifikasi
  Future<void> connectNotifications() async {
    final t = await ApiClient().token;
    final wsUrl =
        '${ApiConfig.baseUrl.replaceFirst('http', 'ws')}/ws/notifications'
        '${t != null ? '?token=$t' : ''}';
    _notificationChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _notificationChannel!.stream.listen(
      (data) {
        try {
          _notificationController.add(jsonDecode(data));
        } catch (_) {}
      },
      onDone: () => disconnectNotifications(),
      onError: (_) => disconnectNotifications(),
    );
  }

  void disconnectNotifications() {
    _notificationChannel?.sink.close();
    _notificationChannel = null;
  }

  /// Hubungkan ke [WS /ws/backup-progress] — real-time backup progress
  Future<void> connectBackupProgress() async {
    final t = await ApiClient().token;
    final wsUrl =
        '${ApiConfig.baseUrl.replaceFirst('http', 'ws')}/ws/backup-progress'
        '${t != null ? '?token=$t' : ''}';
    _backupChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _backupChannel!.stream.listen(
      (data) {
        try {
          _backupController.add(jsonDecode(data));
        } catch (_) {}
      },
      onDone: () => disconnectBackupProgress(),
      onError: (_) => disconnectBackupProgress(),
    );
  }

  void disconnectBackupProgress() {
    _backupChannel?.sink.close();
    _backupChannel = null;
  }

  // ── Video Download Progress ────────────────────────────────
  WebSocketChannel? _videoChannel;
  final _videoController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get videoProgress => _videoController.stream;

  Future<void> connectVideoProgress() async {
    final t = await ApiClient().token;
    final wsUrl =
        '${ApiConfig.baseUrl.replaceFirst('http', 'ws')}/ws/video-progress'
        '${t != null ? '?token=$t' : ''}';
    _videoChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _videoChannel!.stream.listen(
      (data) {
        try {
          _videoController.add(jsonDecode(data));
        } catch (_) {}
      },
      onDone: () => disconnectVideoProgress(),
      onError: (_) => disconnectVideoProgress(),
    );
  }

  void disconnectVideoProgress() {
    _videoChannel?.sink.close();
    _videoChannel = null;
  }

  /// Putuskan semua koneksi WebSocket
  void disconnectAll() {
    disconnectScraperStatus();
    disconnectNotifications();
    disconnectBackupProgress();
    disconnectVideoProgress();
  }

  void dispose() {
    disconnectAll();
    _scraperController.close();
    _notificationController.close();
    _backupController.close();
    _videoController.close();
  }
}

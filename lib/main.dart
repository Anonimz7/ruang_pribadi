import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'math_speed/math.dart';
import 'services/api_client.dart';
import 'services/apis.dart';
import 'services/app_config.dart';
import 'services/app_registry.dart';
import 'services/dark_mode_service.dart';
import 'services/update_service.dart';
import 'bahasa_jepun/bahasa_jepun.dart';
import 'bahasa/screens/bahasa_home_screen.dart';
import 'news_intel/screens/news_screen.dart';
import 'news_intel/screens/stocks_screen.dart';
import 'news_intel/screens/stock_list_screen.dart';
import 'news_intel/screens/market_screen.dart';
import 'news_intel/screens/idx_upload_screen.dart';
import 'settings/admin_perm_screen.dart';
import 'settings/admin_dashboard_screen.dart';
import 'settings/reports_screen.dart';
import 'settings/sitemaps_screen.dart';
import 'settings/proxy_settings_screen.dart';
import 'settings/profile_screen.dart';
import 'settings/backup_screen.dart';
import 'settings/admin_stock_status_screen.dart';
import 'video_downloader/screens/video_downloader_screen.dart';
import 'gacha_luck/gacha_screen.dart';
import 'rolling/rolling_screen.dart';
import 'code_diagram/screens/code_diagram_screen.dart';
import 'passwrod_generator/pasgen.dart';
import 'widgets/app_drawer.dart';
import 'widgets/login_dialog.dart';
import 'widgets/update_dialog.dart';

VoidCallback? onDownloadStarted;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<bool> _darkFuture;

  @override
  void initState() {
    super.initState();
    _darkFuture = loadDarkMode();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _darkFuture,
      builder: (ctx, snap) {
        darkModeNotifier.value = snap.data ?? false;
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => QuizProvider()),
            ChangeNotifierProvider(create: (_) => RecordProvider()),
          ],
          child: ValueListenableBuilder<bool>(
            valueListenable: darkModeNotifier,
            builder: (ctx, isDark, _) => MaterialApp(
              title: 'Ruang VIP',
              theme:
                  ThemeData(fontFamily: 'Roboto', brightness: Brightness.light),
              darkTheme: ThemeData(brightness: Brightness.dark),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: const MainPage(),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════
// MAIN PAGE
// ═══════════════════════════════════════════════════

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 1;
  final _client = ApiClient();
  bool _loading = true;

  // ── Persistent download status banner ──
  int _activeDownloadCount = 0;
  double _activeDownloadProgress = 0;
  String _activeDownloadFilename = '';
  Timer? _downloadPollTimer;

  @override
  void initState() {
    super.initState();
    // Register the session-expired callback so every 401 triggers
    // an automatic popup + logout.
    _client.onSessionExpired = _onSessionExpired;
    onDownloadStarted = _startDownloadPolling;
    _init();
  }

  @override
  void dispose() {
    // Clean up callback when the widget is disposed
    _client.onSessionExpired = null;
    onDownloadStarted = null;
    _downloadPollTimer?.cancel();
    super.dispose();
  }

  // ── Poll active downloads every 15s ──
  void _startDownloadPolling() {
    _downloadPollTimer?.cancel();
    _downloadPollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkActiveDownloads(),
    );
    // Also check immediately
    _checkActiveDownloads();
  }

  Future<void> _checkActiveDownloads() async {
    if (!_client.isLoggedIn) return;
    try {
      final data = await VideoApi().activeDownloads();
      if (!mounted) return;
      final items =
          data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _activeDownloadCount = items.length;
        if (items.isNotEmpty) {
          // Show the first (most recent) active download's progress
          final first = items.first;
          _activeDownloadProgress = (first['progress'] ?? 0).toDouble();
          _activeDownloadFilename = first['filename'] ?? '';
        } else {
          _activeDownloadProgress = 0;
          _activeDownloadFilename = '';
          // No active downloads — stop polling to save bandwidth
          _downloadPollTimer?.cancel();
          _downloadPollTimer = null;
        }
      });
    } catch (_) {}
  }

  Future<void> _init() async {
    await _client.loadSession();
    if (_client.isLoggedIn) {
      try {
        await AuthApi().me();
      } catch (_) {}
    }
    setState(() => _loading = false);

    // ── Auto-check persisted download on startup (only after session loaded) ──
    await _checkPersistedDownload();

    // If no active download found, do one initial check then keep polling
    // so newly-started downloads (e.g. from another device) still appear.
    if (_downloadPollTimer == null) {
      _startDownloadPolling();
    }

    // ── Auto-check update on startup (non-blocking) ──
    _autoCheckUpdate();
  }

  /// Check if there's a persisted download from a previous session and
  /// start polling immediately if it's still active on the server.
  Future<void> _checkPersistedDownload() async {
    if (!_client.isLoggedIn) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('video_downloader_active');
      if (raw == null) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final downloadId = data['download_id'] as String?;
      if (downloadId == null) return;

      // Verify with server if still active
      final status = await VideoApi().downloadStatus(downloadId);
      final st = status['status'] as String? ?? 'not_found';

      if (!mounted) return;

      if (st == 'downloading' || st == 'interrupted') {
        // Still active — start badge polling immediately
        setState(() {
          _activeDownloadCount = 1;
          _activeDownloadProgress = (status['progress'] ?? 0).toDouble();
          _activeDownloadFilename = status['file_name'] ?? '';
        });
        _startDownloadPolling();
      } else {
        // Finished/failed while app was closed — clean up
        await prefs.remove('video_downloader_active');
      }
    } catch (_) {}
  }

  void _autoCheckUpdate() async {
    try {
      final info = await UpdateService().checkUpdate();
      if (!mounted) return;
      if (info != null && info.updateAvailable) {
        showUpdateDialogIfNeeded(context, info);
      }
    } catch (_) {}
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  // ── Session expired handler ──────────────────────
  void _onSessionExpired() async {
    await _client.clearSession();
    if (!mounted) return;
    setState(() => _selectedIndex = 1);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon:
            const Icon(Icons.timer_off_rounded, color: Colors.orange, size: 48),
        title: const Text('Sesi Berakhir'),
        content: const Text(
          'Sesi login Anda telah berakhir.\nSilakan login kembali untuk melanjutkan.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showLoginDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C87A),
              foregroundColor: Colors.black,
            ),
            child: const Text('LOGIN'),
          ),
        ],
      ),
    );
  }

  // ── Login dialog (popup) ────────────────────────
  void _showLoginDialog() {
    showLoginDialog(context, onSuccess: () async {
      await _client.loadSession();
      if (mounted) setState(() {});
    });
  }

  Widget _buildPage(int index) {
    final app = AppConfig.apps[index];
    if (app == null) return const Center(child: Text('Page not found'));

    if (app.section == 'system') return _buildApp(app.key);
    if (app.section == 'admin') {
      if (_client.tier == 'admin') return _buildApp(app.key);
      return _noAccess(app);
    }

    if (!_client.isLoggedIn) {
      Future.microtask(() => _showLoginDialog());
      return _noAccess(app);
    }

    if (_client.canAccess(app.key)) return _buildApp(app.key);
    return _noAccess(app);
  }

  Widget _buildApp(String key) {
    return switch (key) {
      'settings' => const PengaturanPage(),
      'profile' => const ProfileScreen(),
      'japanese_alphabet' => const BahasaJepun(),
      'math_speed' => const MathApp(),
      'password_generator' => const PasswordGeneratorPage(),
      'gacha_luck' => const GachaLuckScreen(),
      'rolling' => const RollingScreen(),
      'code_diagram' => const CodeDiagramScreen(),
      'language' => const BahasaHomeScreen(),
      'video_downloader' => const VideoDownloaderScreen(),
      'news' => const NewsScreen(),
      'stocks' => const StocksScreen(),
      'stock_list' => const StockListScreen(),
      'ihsg_radar' => const MarketScreen(),
      'reports' => const ReportsScreen(),
      'user_permissions' => const AdminPermScreen(),
      'server_dashboard' => const AdminDashboardScreen(),
      'sitemaps' => const SitemapsScreen(),
      'proxies' => const ProxySettingsScreen(),
      'backup' => const BackupScreen(),
      'stock_status' => const AdminStockStatusScreen(),
      'idx_upload' => const IdxUploadScreen(),
      _ => const PlaceholderWidget(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Ruang Pribadi')),
      drawer: AppDrawer(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        client: _client,
        onLogout: () async {
          await _client.clearSession();
          setState(() => _selectedIndex = 1);
        },
        onLoginTap: _showLoginDialog,
      ),
      body: Column(
        children: [
          // ── Persistent download status banner ──
          if (_activeDownloadCount > 0)
            Material(
              color: Colors.blue.shade50,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const VideoDownloaderScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_activeDownloadCount download sedang berjalan',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            if (_activeDownloadFilename.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _activeDownloadFilename,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_activeDownloadProgress > 0)
                        Text(
                          '${_activeDownloadProgress.toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ),
          // ── Page content ──
          Expanded(child: _buildPage(_selectedIndex)),
        ],
      ),
    );
  }

  Widget _noAccess(MenuConfig app) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Access Restricted',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'You do not have access to "${app.label}".\nContact admin for permissions.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}



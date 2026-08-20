import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/apis.dart';
import 'admin_update_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  final _api = AdminApi();
  final _ws = WebSocketService();
  final _logScrollController = ScrollController();

  late TabController _mainTabController;
  late TabController _logTabController;

  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _systemStatus;
  bool _loading = true;
  bool _scraperRunning = false;
  StreamSubscription? _scraperSub;

  // Logs state
  List<String> _logLines = [];
  String _logFile = '';
  bool _logsLoading = false;
  String _logType = 'scraping';
  String? _lastScrapeTime;
  String? _lastScrapeSource;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _logTabController = TabController(length: 4, vsync: this);
    _logTabController.addListener(() {
      if (!_logTabController.indexIsChanging) {
        final types = ['scraping', 'bot', 'proxy', 'server'];
        setState(() => _logType = types[_logTabController.index]);
        _loadLogs();
      }
    });
    _load();
    _connectWs();
  }

  @override
  void dispose() {
    _scraperSub?.cancel();
    _ws.disconnectScraperStatus();
    _mainTabController.dispose();
    _logTabController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        _api.stats(),
        _api.systemStatus(),
      ]);
      setState(() {
        _stats = r[0] as Map<String, dynamic>;
        _systemStatus = r[1] as Map<String, dynamic>;
        _scraperRunning = _systemStatus!['scraper_active'] ?? false;
        _lastScrapeTime = _systemStatus!['last_scrape_time'];
        _lastScrapeSource = _systemStatus!['last_scrape_source'];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _connectWs() {
    _ws.connectScraperStatus();
    _scraperSub = _ws.scraperStatus.listen((data) {
      if (!mounted) return;
      final status = data['status'];
      setState(() {
        _scraperRunning = status == 'running';
      });
      if (data['type'] == 'scraper-complete') {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Scraper selesai!'),
            backgroundColor: Color(0xFF00C87A),
          ),
        );
      }
    });
  }

  Future<void> _toggleMaintenance() async {
    try {
      await _api.toggleMaintenance(enabled: true);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _toggleRegistration() async {
    try {
      await _api.toggleRegistration(enabled: true);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _runScraper() async {
    try {
      final r = await _api.runScraper();
      if (r['success'] == true) {
        setState(() => _scraperRunning = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚀 Scraper dimulai!'),
              backgroundColor: Color(0xFF00C87A),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(r['message'] ?? 'Scraper sedang jalan')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _logsLoading = true);
    try {
      final r = await _api.logs(_logType, lines: 120);
      if (mounted) {
        setState(() {
          _logLines = List<String>.from(r['lines'] ?? []);
          _logFile = r['file'] ?? '';
        });
      }
      await Future.delayed(const Duration(milliseconds: 100));
      if (_logScrollController.hasClients) {
        _logScrollController.jumpTo(
          _logScrollController.position.maxScrollExtent,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _logsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Server'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminUpdateScreen()),
              );
            },
            icon: const Icon(Icons.system_update),
            tooltip: 'Kelola Versi APK',
          ),
        ],
        bottom: TabBar(
          controller: _mainTabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.article), text: 'Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _mainTabController,
        children: [
          _buildDashboardTab(),
          _buildLogsTab(),
        ],
      ),
    );
  }

  // ─── Dashboard Tab ──────────────────────────────────────────────────────

  Widget _buildDashboardTab() {
    final server = _stats?['server'] ?? {};
    final dbNews = _stats?['database']?['news'] ?? {};
    final dbIdx = _stats?['database']?['idx'] ?? {};
    final maintenance = _systemStatus?['status'] == 'maintenance';
    final regEnabled = _systemStatus?['registration_enabled'] ?? false;
    final dbSize = _systemStatus?['db_size_mb'] ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Scraper Status Banner ──────────
            _scraperBanner(),
            const SizedBox(height: 16),

            // ─── System Status ─────────────────
            _sectionTitle('SISTEM'),
            const SizedBox(height: 8),
            Row(children: [
              _statusTile('Status', maintenance ? 'MAINTENANCE' : 'ACTIVE',
                  maintenance ? Colors.red : const Color(0xFF00C87A)),
              const SizedBox(width: 8),
              _statusTile('Registrasi', regEnabled ? 'ON' : 'OFF',
                  regEnabled ? const Color(0xFF00C87A) : Colors.orange),
              const SizedBox(width: 8),
              _statusTile(
                  'DB Size', '${dbSize.toStringAsFixed(1)} MB', Colors.blue),
            ]),
            const SizedBox(height: 12),

            // ─── Toggle Buttons ────────────────
            Row(children: [
              _toggleBtn(
                maintenance ? 'Nonaktif Maintenance' : 'Aktifkan Maintenance',
                Icons.build_circle_outlined,
                maintenance ? const Color(0xFF00C87A) : Colors.red,
                _toggleMaintenance,
              ),
              const SizedBox(width: 8),
              _toggleBtn(
                regEnabled ? 'Matikan Registrasi' : 'Hidupkan Registrasi',
                Icons.person_add_outlined,
                regEnabled ? Colors.orange : const Color(0xFF00C87A),
                _toggleRegistration,
              ),
            ]),
            const SizedBox(height: 20),

            // ─── Server Stats ──────────────────
            _sectionTitle('SERVER'),
            const SizedBox(height: 8),
            Row(children: [
              _statTile('CPU', '${server['cpu_percent'] ?? 0}%', Colors.cyan,
                  Icons.memory),
              const SizedBox(width: 8),
              _statTile(
                  'RAM',
                  '${server['ram_used_gb'] ?? 0}/${server['ram_total_gb'] ?? 0} GB',
                  Colors.purple,
                  Icons.sd_storage),
              const SizedBox(width: 8),
              _statTile(
                  'Disk',
                  '${server['disk_used_gb'] ?? 0}/${server['disk_total_gb'] ?? 0} GB',
                  Colors.orange,
                  Icons.disc_full),
            ]),
            const SizedBox(height: 20),

            // ─── Database Stats ─────────────────
            _sectionTitle('DATABASE'),
            const SizedBox(height: 8),
            Row(children: [
              _statTile('Berita', '${dbNews['article_count'] ?? 0}',
                  Colors.blue, Icons.article),
              const SizedBox(width: 8),
              _statTile('Saham', '${dbIdx['stock_count'] ?? 0}',
                  const Color(0xFF00C87A), Icons.candlestick_chart),
              const SizedBox(width: 8),
              _statTile('Trade Days', '${dbIdx['trade_days'] ?? 0}',
                  Colors.amber, Icons.calendar_today),
            ]),
            const SizedBox(height: 20),

            // ─── Scraper Control ────────────────
            _sectionTitle('SCRAPER'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _scraperRunning ? null : _runScraper,
                icon: _scraperRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow, color: Colors.white),
                label: Text(
                    _scraperRunning ? 'Sedang Berjalan...' : 'Jalankan Scraper',
                    style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _scraperRunning ? Colors.grey : const Color(0xFF00C87A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Logs Tab ──────────────────────────────────────────────────────────

  Widget _buildLogsTab() {
    return Column(
      children: [
        // ── Log type tabs ──
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _logTabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Scraping'),
              Tab(text: 'Bot'),
              Tab(text: 'Proxy'),
              Tab(text: 'Server'),
            ],
          ),
        ),

        // ── Log file header ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.description, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _logFile.isNotEmpty ? _logFile : 'Belum ada log',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${_logLines.length} baris',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              if (_logsLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: _loadLogs,
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Muat ulang log',
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Log content ──
        Expanded(
          child: _logLines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.article_outlined,
                          size: 48, color: Colors.grey.shade700),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum ada log.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tekan refresh untuk memuat log $_logType.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _logScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _logLines.length,
                  itemBuilder: (context, index) {
                    final line = _logLines[index];
                    // Color logic
                    Color textColor;
                    if (line.contains('] OK ') || line.contains('OK')) {
                      textColor = const Color(0xFF00C87A);
                    } else if (line.contains('] FAIL ') ||
                        line.contains('FAIL') ||
                        line.contains('ERROR') ||
                        line.contains('error')) {
                      textColor = Colors.redAccent[300] ?? Colors.red;
                    } else if (line.contains('WARN') || line.contains('warn')) {
                      textColor = Colors.orange[300] ?? Colors.orange;
                    } else if (line.startsWith('[') || line.contains('─')) {
                      textColor = Colors.grey[500] ?? Colors.grey;
                    } else {
                      textColor = const Color(0xFF00C87A);
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: textColor,
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _scraperBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _scraperRunning
            ? Colors.orange.withValues(alpha: 0.15)
            : const Color(0xFF00C87A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _scraperRunning
              ? Colors.orange.withValues(alpha: 0.3)
              : const Color(0xFF00C87A).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _scraperRunning ? Icons.sync : Icons.check_circle_outline,
            color: _scraperRunning ? Colors.orange : const Color(0xFF00C87A),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _scraperRunning ? 'Scraper Sedang Berjalan' : 'Scraper Idle',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _scraperRunning
                        ? Colors.orange
                        : const Color(0xFF00C87A),
                  ),
                ),
                Text(
                  _scraperRunning ? 'Menunggu selesai...' : 'Siap dijalankan',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (!_scraperRunning && _lastScrapeTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 11, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Terakhir: $_lastScrapeTime${_lastScrapeSource != null ? ' (${_lastScrapeSource!})' : ''}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_scraperRunning)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _statusTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 14, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _toggleBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label,
            style: TextStyle(fontSize: 11, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 1,
      ),
    );
  }
}

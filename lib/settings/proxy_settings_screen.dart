import 'dart:async';
import 'package:flutter/material.dart';
import '../services/apis.dart';

class ProxySettingsScreen extends StatefulWidget {
  const ProxySettingsScreen({super.key});

  @override
  State<ProxySettingsScreen> createState() => _ProxySettingsScreenState();
}

class _ProxySettingsScreenState extends State<ProxySettingsScreen>
    with SingleTickerProviderStateMixin {
  final _api = AdminApi();
  final _proxiesController = TextEditingController();
  final _webshareKeyController = TextEditingController();
  final _logScrollController = ScrollController();
  bool _loading = true;
  bool _saving = false;
  bool _keyConfigured = false;
  String _keyMasked = '';
  Map<String, dynamic>? _keyTestResult;
  Map<String, dynamic>? _testResult;
  List<String> _logLines = [];
  String? _logFile;
  bool _logsLoading = false;
  bool _showLogs = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _proxiesController.dispose();
    _webshareKeyController.dispose();
    _logScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ─── Data Loading ────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings = await _api.proxySettings();
      _proxiesController.text = settings['proxies'] ?? '';
      if (mounted) {
        setState(() {
          _keyConfigured = settings['webshare_key_configured'] == true;
          _keyMasked = settings['webshare_key_masked'] ?? '';
          _testResult = null;
          _keyTestResult = null;
        });
      }
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _logsLoading = true);
    try {
      final r = await _api.proxyLogs(lines: 120);
      if (mounted) {
        setState(() {
          _logLines = List<String>.from(r['lines'] ?? []);
          _logFile = r['current_file'];
        });
      }
      // Scroll to bottom
      await Future.delayed(const Duration(milliseconds: 100));
      if (_logScrollController.hasClients) {
        _logScrollController.jumpTo(
          _logScrollController.position.maxScrollExtent,
        );
      }
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _logsLoading = false);
    }
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _testKey() async {
    setState(() => _saving = true);
    try {
      final result = await _api.testWebshareKey();
      if (mounted) setState(() => _keyTestResult = result);
      _showMessage(
        result['message'] ?? 'Selesai',
        success: result['success'] == true,
      );
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final result = await _api.saveProxySettings(
        proxies: _proxiesController.text,
        webshareApiKey: _webshareKeyController.text.trim().isEmpty
            ? null
            : _webshareKeyController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _keyConfigured = result['webshare_key_configured'] == true;
        _webshareKeyController.clear();
      });
      _showMessage('${result['proxy_count'] ?? 0} proxy disimpan',
          success: true);
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _syncWebshare() async {
    setState(() => _saving = true);
    try {
      final result = await _api.syncWebshareProxies();
      if (!mounted) return;
      _showMessage(result['message'] ?? 'Proxy Webshare disinkronkan',
          success: true);
      await _load();
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() => _saving = true);
    try {
      final result = await _api.testProxies();
      if (mounted) setState(() => _testResult = result);
      // Auto-refresh logs after test
      await _loadLogs();
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF00C87A) : Colors.redAccent,
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proxy Scraper'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.cloud), text: 'Webshare'),
            Tab(icon: Icon(Icons.list), text: 'Proxy'),
            Tab(icon: Icon(Icons.article), text: 'Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWebshareTab(),
          _buildProxyTab(),
          _buildLogTab(),
        ],
      ),
    );
  }

  // ─── Tab: Webshare ───────────────────────────────────────────────────────

  Widget _buildWebshareTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _keyConfigured ? Icons.cloud_done : Icons.cloud_off,
                    color: _keyConfigured ? const Color(0xFF00C87A) : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _keyConfigured ? 'API Key Terkonfigurasi' : 'Belum Ada API Key',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _keyConfigured ? const Color(0xFF00C87A) : Colors.orange,
                    ),
                  ),
                ],
              ),

              // ── Show masked key ──
              if (_keyConfigured && _keyMasked.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.vpn_key, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _keyMasked,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              TextField(
                controller: _webshareKeyController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText:
                      _keyConfigured ? 'Ganti API key' : 'Webshare API key',
                  hintText: _keyConfigured
                      ? 'Ketik key baru untuk mengganti'
                      : 'Tempel API key Webshare',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(_keyConfigured ? Icons.key : Icons.key_off),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _keyConfigured
                    ? 'Key tersimpan di backend. Ketik key baru untuk mengganti, atau langsung sinkronkan.'
                    : 'Simpan API key terlebih dahulu sebelum sinkronisasi.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),

              // ── Action buttons ──
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _testKey,
                      icon: _saving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.wifi_find),
                      label: const Text('Uji Koneksi'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving || !_keyConfigured ? null : _syncWebshare,
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Sinkronkan'),
                    ),
                  ),
                ],
              ),

              // ── Key test result ──
              if (_keyTestResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (_keyTestResult!['success'] == true
                        ? const Color(0xFF00C87A) : Colors.redAccent)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_keyTestResult!['success'] == true
                          ? const Color(0xFF00C87A) : Colors.redAccent)
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _keyTestResult!['success'] == true
                            ? Icons.check_circle : Icons.error,
                        size: 18,
                        color: _keyTestResult!['success'] == true
                            ? const Color(0xFF00C87A) : Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _keyTestResult!['message'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: _keyTestResult!['success'] == true
                                ? const Color(0xFF00C87A) : Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── Tab: Proxy List + Test ──────────────────────────────────────────────

  Widget _buildProxyTab() {
    final entries =
        List<Map<String, dynamic>>.from(_testResult?['results'] ?? []);
    final total = _testResult?['total'] ?? 0;
    final working = _testResult?['working'] ?? 0;
    final failed = total - working;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          child: TextField(
            controller: _proxiesController,
            minLines: 8,
            maxLines: 14,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              labelText: 'Satu proxy per baris',
              hintText: 'IP:PORT\nIP:PORT:USERNAME:PASSWORD',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('Simpan'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _test,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.network_check),
                label: const Text('Tes Semua'),
              ),
            ),
          ],
        ),
        if (_saving) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],

        // ── Test Result Summary ──
        if (_testResult != null) ...[
          const SizedBox(height: 20),
          _sectionTitle('HASIL PENGUJIAN'),
          const SizedBox(height: 8),
          Row(
            children: [
              _resultChip('$total Total', Colors.blue, Icons.hub),
              const SizedBox(width: 8),
              _resultChip('$working Aktif', const Color(0xFF00C87A), Icons.check_circle),
              const SizedBox(width: 8),
              _resultChip('$failed Gagal', Colors.redAccent, Icons.cancel),
            ],
          ),

          // ── Detail per proxy ──
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...entries.map((entry) {
              final ok = entry['working'] == true;
              final latency = entry['latency_ms'];
              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: Icon(
                    ok ? Icons.check_circle : Icons.cancel,
                    color: ok ? const Color(0xFF00C87A) : Colors.redAccent,
                    size: 20,
                  ),
                  title: Text(
                    entry['proxy'] ?? '',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 13),
                  ),
                  trailing: Text(
                    ok
                        ? (latency != null ? '${latency}ms' : 'Aktif')
                        : 'Gagal',
                    style: TextStyle(
                      fontSize: 12,
                      color: ok ? const Color(0xFF00C87A) : Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ],
    );
  }

  // ─── Tab: Logs ───────────────────────────────────────────────────────────

  Widget _buildLogTab() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.article, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                _logFile ?? 'Belum ada log',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
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

        // Log content
        Expanded(
          child: _logLines.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada log pengujian proxy.\nJalankan "Tes Semua" untuk melihat hasilnya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  controller: _logScrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _logLines.length,
                  itemBuilder: (context, index) {
                    final line = _logLines[index];
                    final isOk = line.contains('] OK ');
                    final isFail = line.contains('] FAIL ');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: isOk
                              ? const Color(0xFF00C87A)
                              : isFail
                                  ? Colors.redAccent[300]
                                  : Colors.grey[400],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade800),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _resultChip(String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
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

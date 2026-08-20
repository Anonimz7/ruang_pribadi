import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/apis.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _api = BackupApi();
  final _ws = WebSocketService();

  // GDrive state
  bool _gdriveConnected = false;
  double? _gdriveLimitGb;
  double? _gdriveUsageGb;
  double? _gdriveRemainingMb;

  // Backup state
  String _phase = "idle";
  int _percent = 0;
  String _statusMessage = "";
  String? _backupFilename;
  bool _running = false;

  // History
  List<dynamic> _history = [];
  bool _loading = true;

  StreamSubscription? _backupSub;

  @override
  void initState() {
    super.initState();
    _load();
    _connectWs();
  }

  @override
  void dispose() {
    _backupSub?.cancel();
    _ws.disconnectBackupProgress();
    super.dispose();
  }

  // ── Load Data ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.gdriveInfo(),
        _api.backupHistory(),
        _api.backupStatus(),
      ]);

      final gdrive = results[0] as Map<String, dynamic>;
      final historyData = results[1] as Map<String, dynamic>;
      final status = results[2] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _gdriveConnected = gdrive['connected'] ?? false;
          final storage = gdrive['storage'];
          if (storage != null) {
            _gdriveLimitGb = (storage['limit_gb'] as num?)?.toDouble();
            _gdriveUsageGb = (storage['usage_gb'] as num?)?.toDouble();
            _gdriveRemainingMb = (storage['remaining_mb'] as num?)?.toDouble();
          }

          _history = List<dynamic>.from(historyData['history'] ?? []);

          _phase = status['phase'] ?? 'idle';
          _percent = status['percent'] ?? 0;
          _statusMessage = status['message'] ?? '';
          _backupFilename = status['filename'];
          _running = _phase == 'dumping' || _phase == 'zipping' || _phase == 'uploading';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── WebSocket ──────────────────────────────────────────────────────────

  void _connectWs() {
    _ws.connectBackupProgress();
    _backupSub = _ws.backupProgress.listen((data) {
      if (!mounted) return;
      final phase = data['phase'] ?? 'idle';
      setState(() {
        _phase = phase;
        _percent = data['percent'] ?? 0;
        _statusMessage = data['message'] ?? '';
        _backupFilename = data['filename'];
        _running = phase == 'dumping' || phase == 'zipping' || phase == 'uploading';
      });

      if (phase == 'done') {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Backup selesai!'),
            backgroundColor: Color(0xFF00C87A),
          ),
        );
      } else if (phase == 'failed') {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Backup gagal: ${data['error'] ?? "Unknown error"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _startBackup() async {
    if (_running) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mulai Backup?'),
        content: const Text(
          'Ini akan melakukan dump database MySQL, membuat ZIP archive, dan mengupload ke Google Drive (jika terhubung).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mulai', style: TextStyle(color: Color(0xFF00C87A))),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.runBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚀 Backup dimulai!'),
            backgroundColor: Color(0xFF00C87A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulai backup: $e')),
        );
      }
    }
  }

  Future<void> _downloadBackup(String filename) async {
    try {
      final url = await _api.getDownloadUrl(filename);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak bisa membuka browser')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh: $e')),
        );
      }
    }
  }

  Future<void> _deleteBackup(String filename) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Backup?'),
        content: Text('Hapus "$filename" secara permanen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.deleteBackup(filename);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🗑️ $filename dihapus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e')),
        );
      }
    }
  }

  Future<void> _connectGDrive() async {
    try {
      final result = await _api.gdriveAuth();
      final authUrl = result['auth_url'];
      if (authUrl != null) {
        if (!mounted) return;
        final code = await showDialog<String>(
          context: context,
          builder: (ctx) {
            final controller = TextEditingController();
            return AlertDialog(
              title: const Text('🔐 Google Drive Auth'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '1. Buka link di bawah & login Google\n'
                    '2. Setelah grant, browser redirect ke localhost\n'
                    '3. Copy kode dari URL (bagian ?code=XXX)\n'
                    '4. Paste kode di bawah ini',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(authUrl)),
                    child: Text(
                      authUrl,
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Authorization Code',
                      hintText: 'Paste code dari URL...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, controller.text),
                  child: const Text('Hubungkan'),
                ),
              ],
            );
          },
        );

        if (code != null && code.isNotEmpty) {
          await _api.gdriveExchangeCode(code);
          _load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Google Drive terhubung!'),
                backgroundColor: Color(0xFF00C87A),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghubungkan GDrive: $e')),
        );
      }
    }
  }

  Future<void> _disconnectGDrive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Putuskan GDrive?'),
        content: const Text('Backup tidak akan bisa di-upload ke Google Drive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Putuskan', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.gdriveDisconnect();
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Drive diputuskan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Backup Management'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGDriveCard(),
              const SizedBox(height: 16),
              _buildBackupButton(),
              const SizedBox(height: 16),
              _buildProgressCard(),
              const SizedBox(height: 20),
              _buildHistorySection(),
            ],
          ),
        ),
      ),
    );
  }

  // ── GDrive Card ────────────────────────────────────────────────────────

  Widget _buildGDriveCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _gdriveConnected
            ? const Color(0xFF00C87A).withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _gdriveConnected
              ? const Color(0xFF00C87A).withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _gdriveConnected ? Icons.cloud_done : Icons.cloud_off,
                color: _gdriveConnected ? const Color(0xFF00C87A) : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _gdriveConnected ? 'Google Drive Connected' : 'Google Drive Disconnected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _gdriveConnected ? const Color(0xFF00C87A) : Colors.orange,
                      ),
                    ),
                    Text(
                      _gdriveConnected ? 'Backup otomatis ter-upload' : 'Klik untuk menghubungkan',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_gdriveConnected && _gdriveLimitGb != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _gdriveUsageGb! / _gdriveLimitGb!,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              color: const Color(0xFF00C87A),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_gdriveUsageGb!.toStringAsFixed(1)} / ${_gdriveLimitGb!.toStringAsFixed(1)} GB',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  '${_gdriveRemainingMb!.toStringAsFixed(0)} MB tersisa',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _gdriveConnected ? null : _connectGDrive,
                  icon: Icon(
                    _gdriveConnected ? Icons.check : Icons.link,
                    size: 16,
                    color: _gdriveConnected ? Colors.grey : const Color(0xFF00C87A),
                  ),
                  label: Text(
                    _gdriveConnected ? 'Terhubung' : 'Hubungkan',
                    style: TextStyle(
                      fontSize: 12,
                      color: _gdriveConnected ? Colors.grey : const Color(0xFF00C87A),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              if (_gdriveConnected) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _disconnectGDrive,
                    icon: const Icon(Icons.link_off, size: 16, color: Colors.red),
                    label: const Text(
                      'Putuskan',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Backup Button ──────────────────────────────────────────────────────

  Widget _buildBackupButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _running ? null : _startBackup,
        icon: _running
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.backup, color: Colors.white),
        label: Text(
          _running ? 'Sedang Berjalan...' : '🗄️ Mulai Backup Sekarang',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _running ? Colors.grey : const Color(0xFF00C87A),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ── Progress Card ──────────────────────────────────────────────────────

  Widget _buildProgressCard() {
    if (_phase == "idle") return const SizedBox.shrink();

    final phaseLabel = {
      "dumping": "📦 MySQL Dump",
      "zipping": "🗜️ Membuat ZIP",
      "uploading": "☁️ Upload ke GDrive",
      "done": "✅ Selesai",
      "failed": "❌ Gagal",
    }[_phase] ?? _phase;

    final color = _phase == "done"
        ? const Color(0xFF00C87A)
        : _phase == "failed"
            ? Colors.red
            : Colors.blue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                phaseLabel,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              const Spacer(),
              Text(
                '$_percent%',
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _percent / 100.0,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              color: color,
              minHeight: 8,
            ),
          ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  // ── History Section ────────────────────────────────────────────────────

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '📦 Riwayat Backup',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${_history.length} item',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Belum ada backup',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._history.map((entry) => _buildHistoryItem(entry)),
      ],
    );
  }

  Widget _buildHistoryItem(dynamic entry) {
    final filename = entry['filename'] ?? 'Unknown';
    final dateStr = entry['date_str'] ?? '';
    final sizeMb = (entry['size_mb'] as num?)?.toDouble() ?? 0;
    final gdriveOk = entry['gdrive_uploaded'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF00C87A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.backup, color: Color(0xFF00C87A), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${sizeMb.toStringAsFixed(1)} MB',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      gdriveOk ? Icons.cloud_done : Icons.cloud_off,
                      size: 12,
                      color: gdriveOk ? const Color(0xFF00C87A) : Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _downloadBackup(filename),
            icon: const Icon(Icons.download, size: 20),
            tooltip: 'Download',
          ),
          IconButton(
            onPressed: () => _deleteBackup(filename),
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            tooltip: 'Hapus',
          ),
        ],
      ),
    );
  }
}

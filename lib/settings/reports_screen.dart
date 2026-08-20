import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/apis.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _api = ReportApi();

  Map<String, dynamic>? _lastReport;
  Map<String, dynamic>? _generatedReport;
  List<dynamic> _reports = [];
  List<dynamic> _fileHistory = []; // ← report history from listFiles()
  bool _loading = true;
  bool _generating = false;
  int _sinceHours = 24;
  bool _autoSend = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.last();
      setState(() {
        _lastReport = r;
        _autoSend = r['auto_send'] ?? false;
      });
      // Fetch previously generated report files
      try {
        final f = await _api.listFiles();
        setState(() => _fileHistory = List<dynamic>.from(f['files'] ?? []));
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final r = await _api.generate(sinceHours: _sinceHours);
      setState(() {
        _generatedReport = r;
        _reports = List<dynamic>.from(r['reports'] ?? []);
      });
      if (mounted) {
        final fileCount = _reports.fold<int>(
            0, (sum, cat) => sum + ((cat['files'] as List?)?.length ?? 0));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Laporan di-generate: ${r['total'] ?? 0} artikel, ${_reports.length} kategori, $fileCount file'),
            backgroundColor: const Color(0xFF00C87A),
          ),
        );
      }
      // Refresh last report info + file history
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _generating = false);
    }
  }

  Future<void> _toggleAutoSend(bool value) async {
    try {
      await _api.updatePreferences(autoSend: value);
      setState(() => _autoSend = value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(value ? 'Auto-send aktif' : 'Auto-send dinonaktifkan'),
            backgroundColor: const Color(0xFF00C87A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _downloadFile(Map<String, dynamic> file) async {
    try {
      final remotePath = file['path'] as String;
      final filename = file['filename'] as String;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⬇️ Mengunduh $filename...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Download via API
      final savedPath = await _api.downloadFile(remotePath, filename);

      // Move to Downloads directory
      Directory saveDir;
      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) {
          saveDir = Directory.systemTemp;
        }
      } else {
        saveDir = Directory.systemTemp;
      }

      final finalPath = '${saveDir.path}/$filename';
      final tempFile = File(savedPath);
      if (await tempFile.exists()) {
        await tempFile.copy(finalPath);
        await tempFile.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Tersimpan: $finalPath'),
            backgroundColor: const Color(0xFF00C87A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal download: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final lastSent = _lastReport?['last_report_at'];

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Last Report Info ───────────────
            const Text('LAPORAN TERAKHIR',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          color: lastSent != null
                              ? const Color(0xFF00C87A)
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lastSent != null
                                    ? 'Sudah pernah dikirim'
                                    : 'Belum ada laporan',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: lastSent != null
                                      ? const Color(0xFF00C87A)
                                      : Colors.grey,
                                ),
                              ),
                              if (lastSent != null)
                                Text(
                                  'Terakhir: $lastSent',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Auto-send toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-Send Laporan',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Kirim laporan otomatis setiap 24 jam',
                          style: TextStyle(fontSize: 12)),
                      value: _autoSend,
                      onChanged: _toggleAutoSend,
                      activeColor: const Color(0xFF00C87A),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─── Generate Report ────────────────
            const Text('GENERATE LAPORAN',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Periode Laporan',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [6, 12, 24, 48, 72].map((h) {
                        final selected = _sinceHours == h;
                        return ChoiceChip(
                          label: Text('${h}j',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: selected ? Colors.white : null)),
                          selected: selected,
                          selectedColor: const Color(0xFF00C87A),
                          onSelected: (_) => setState(() => _sinceHours = h),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _generating ? null : _generate,
                        icon: _generating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome,
                                color: Colors.white),
                        label: Text(
                          _generating
                              ? 'Sedang Generate...'
                              : 'Generate Laporan',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _generating
                              ? Colors.grey
                              : const Color(0xFF00C87A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Generated Report Result ───────
            if (_generatedReport != null) ...[
              const SizedBox(height: 20),
              const Text('HASIL',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.article, color: Color(0xFF00C87A)),
                          const SizedBox(width: 8),
                          Text(
                            '${_generatedReport!['total'] ?? 0} artikel dikumpulkan',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Report Categories ─────────────
              ..._reports.map((cat) => _buildReportCategory(cat)),
            ],

            // ─── Report History ──────────────────
            if (_fileHistory.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('LAPORAN SEBELUMNYA',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              ..._fileHistory.map((group) {
                final date = group['date'] ?? '';
                final files = List<dynamic>.from(group['files'] ?? []);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Color(0xFF00C87A)),
                          const SizedBox(width: 8),
                          Text(date,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          const Spacer(),
                          Text('${files.length} file',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ]),
                        const Divider(height: 16),
                        ...files.map((f) => _buildFileRow(f)),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportCategory(dynamic category) {
    final label = category['label'] ?? '';
    final description = category['description'] ?? '';
    final files = List<dynamic>.from(category['files'] ?? []);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category header
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              const SizedBox(height: 12),
              // Files
              ...files.map((file) => _buildFileRow(file)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileRow(dynamic file) {
    final filename = file['filename'] ?? '';
    final sizeKb = file['size_kb'] ?? 0;
    final isCsv = filename.endsWith('.csv');
    final icon = isCsv ? Icons.table_chart : Icons.description;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00C87A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: const Color(0xFF00C87A), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(filename,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('${sizeKb} KB',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF00C87A)),
            tooltip: 'Download',
            onPressed: () => _downloadFile(file),
          ),
        ],
      ),
    );
  }
}

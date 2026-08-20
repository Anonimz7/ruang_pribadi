import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/apis.dart';

class IdxUploadScreen extends StatefulWidget {
  const IdxUploadScreen({super.key});

  @override
  State<IdxUploadScreen> createState() => _IdxUploadScreenState();
}

class _IdxUploadScreenState extends State<IdxUploadScreen> {
  final _api = StockApi();
  String? _selectedFile;
  bool _uploading = false;
  String? _message;
  bool? _isSuccess;
  bool? _isNew;
  String? _tradeDate;

  // IDX status
  Map<String, dynamic>? _status;
  bool _statusLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _statusLoading = true);
    try {
      final s = await _api.status();
      setState(() => _status = s);
    } catch (_) {}
    setState(() => _statusLoading = false);
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      dialogTitle: 'Pilih file Excel IDX',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = result.files.single.path;
        _message = null;
        _isSuccess = null;
      });
    }
  }

  Future<void> _upload() async {
    if (_selectedFile == null) return;

    setState(() => _uploading = true);

    try {
      final r = await _api.upload(_selectedFile!);
      setState(() {
        _isSuccess = r['success'] as bool?;
        _message = r['message'] as String?;
        _isNew = r['is_new'] as bool?;
        _tradeDate = r['trade_date'] as String?;
      });

      if (_isSuccess == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Upload berhasil!'),
            backgroundColor: Color(0xFF00C87A),
          ),
        );
        // Refresh status setelah upload
        _loadStatus();
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _message = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Back button + title (AppBar-less clean style)
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadStatus,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Status IDX ──
                      _buildStatusCard(),
                      const SizedBox(height: 16),

                      // ── Info card ──
                      Card(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📁 Format File',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('• File harus berformat .xlsx (Excel)',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer)),
                              Text(
                                  '• Nama file harus mengandung tanggal YYYYMMDD',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer)),
                              Text('• Contoh: 20240115_idx_data.xlsx',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── File picker button ──
                      ElevatedButton.icon(
                        onPressed: _uploading ? null : _pickFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Pilih File Excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C87A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Selected file display ──
                      if (_selectedFile != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Theme.of(context).colorScheme.outline),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.insert_drive_file,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedFile!.split('/').last,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: _uploading
                                    ? null
                                    : () =>
                                        setState(() => _selectedFile = null),
                                icon: const Icon(Icons.close, size: 20),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // ── Upload button ──
                      ElevatedButton.icon(
                        onPressed: _selectedFile == null || _uploading
                            ? null
                            : _upload,
                        icon: _uploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: Text(
                            _uploading ? 'Mengunggah...' : 'Upload ke Server'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Result display ──
                      if (_message != null) _buildResultCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_statusLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_status == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Gagal memuat status IDX'),
        ),
      );
    }

    final lastUpdate = _status!['last_update'] ?? 'N/A';
    final stockCount = _status!['stock_count'] ?? 0;
    final tradeDays = _status!['trade_days'] ?? 0;
    final dbSize = _status!['db_size_mb'] ?? 0;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 Status Database IDX',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statusItem(
                    Icons.calendar_today, 'Update Terakhir', lastUpdate),
                const SizedBox(width: 12),
                _statusItem(Icons.candlestick_chart, 'Saham', '$stockCount'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _statusItem(Icons.date_range, 'Hari Perdagangan', '$tradeDays'),
                const SizedBox(width: 12),
                _statusItem(Icons.storage, 'Ukuran DB', '${dbSize} MB'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusItem(IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  Text(value,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final cs = Theme.of(context).colorScheme;
    final successColor = _isSuccess == true ? Colors.green : Colors.red;
    return Card(
      color: _isSuccess == true
          ? Colors.green.withValues(alpha: 0.15)
          : Colors.red.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isSuccess == true ? Icons.check_circle : Icons.error,
                  color: successColor,
                ),
                const SizedBox(width: 8),
                Text(
                  _isSuccess == true ? 'Berhasil' : 'Gagal',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: successColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_message!),
            if (_tradeDate != null) ...[
              const SizedBox(height: 8),
              Text('📅 Tanggal: $_tradeDate'),
            ],
            if (_isNew != null) ...[
              const SizedBox(height: 4),
              Text(
                _isNew!
                    ? '✨ Data baru ditambahkan'
                    : 'ℹ️ Data sudah ada (konsisten)',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

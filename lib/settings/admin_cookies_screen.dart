import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/apis.dart';

/// Admin screen to upload cookies.txt for yt-dlp.
/// Accessible from admin dashboard or settings.
class AdminCookiesScreen extends StatefulWidget {
  const AdminCookiesScreen({super.key});

  @override
  State<AdminCookiesScreen> createState() => _AdminCookiesScreenState();
}

class _AdminCookiesScreenState extends State<AdminCookiesScreen> {
  final _videoApi = VideoApi();
  PlatformFile? _pickedFile;
  bool _uploading = false;
  String? _lastError;
  bool _uploadSuccess = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedFile = result.files.first;
        _uploadSuccess = false;
        _lastError = null;
      });
    }
  }

  Future<void> _upload() async {
    if (_pickedFile == null || _pickedFile!.path == null) return;

    setState(() {
      _uploading = true;
      _lastError = null;
      _uploadSuccess = false;
    });

    try {
      await _videoApi.uploadCookies(_pickedFile!.path!);
      setState(() {
        _uploading = false;
        _uploadSuccess = true;
      });
    } catch (e) {
      setState(() {
        _uploading = false;
        _lastError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Cookies yt-dlp')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Info Card ──
          Card(
            color: isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Tentang Cookies',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload file cookies.txt untuk mem-bypass deteksi bot YouTube. '
                    'File ini berisi sesi browser yang valid sehingga yt-dlp '
                    'dapat mengakses YouTube tanpa blokir.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cara mendapatkan cookies.txt:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  _buildStep('1.', 'Buka Chrome, login ke YouTube (akun cadangan/dummy)'),
                  _buildStep('2.', 'Pasang ekstensi https://cookie-editor.com/'),
                  _buildStep('3.', 'Buka YouTube, klik ikon ekstensi, lalu Export Netscape'),
                  _buildStep('4.', 'Simpan file sebagai cookies.txt'),
                  _buildStep('5.', 'Upload file tersebut di sini'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Pick File ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload Cookies',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickFile,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: Text(
                        _pickedFile != null
                            ? _pickedFile!.name
                            : 'Pilih File cookies.txt',
                      ),
                    ),
                  ),
                  if (_pickedFile != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Ukuran: ${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_pickedFile != null && !_uploading) ? _upload : null,
                      icon: _uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(_uploading ? 'Mengupload...' : 'Upload Cookies'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Success / Error ──
          if (_uploadSuccess)
            Card(
              color: isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: isDark ? Colors.green.shade300 : Colors.green.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Cookies berhasil diupload! yt-dlp akan menggunakan cookies ini untuk request berikutnya.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_lastError != null)
            Card(
              color: isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: isDark ? Colors.red.shade300 : Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastError!,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.red.shade300 : Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Warning ──
          const SizedBox(height: 16),
          Card(
            color: isDark ? Colors.orange.shade900.withValues(alpha: 0.3) : Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '⚠️ Gunakan akun cadangan/dummy untuk login YouTube. '
                      'Jangan gunakan akun Google utama untuk menghindari risiko pemblokiran.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

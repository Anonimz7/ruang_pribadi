import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/apis.dart';
import '../config/app_version.dart';

class AdminUpdateScreen extends StatefulWidget {
  const AdminUpdateScreen({super.key});

  @override
  State<AdminUpdateScreen> createState() => _AdminUpdateScreenState();
}

class _AdminUpdateScreenState extends State<AdminUpdateScreen> {
  final _api = UpdateApi();
  List<dynamic> _versions = [];
  bool _loading = true;
  bool _uploading = false;
  double _uploadProgress = 0;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _versions = await _api.getVersions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showUploadDialog() async {
    final versionCtrl = TextEditingController();
    final versionCodeCtrl = TextEditingController();
    final changelogCtrl = TextEditingController();
    PlatformFile? pickedFile;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Upload APK Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: versionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Versi (e.g. 4.1.0)',
                    hintText: '4.1.0',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: versionCodeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Version Code (e.g. 40100)',
                    hintText: '40100',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                // File picker
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['apk'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        setDialogState(() => pickedFile = result.files.first);
                      }
                    },
                    icon: const Icon(Icons.file_upload_outlined),
                    label: Text(
                      pickedFile != null
                          ? '${pickedFile!.name} (${(pickedFile!.size / 1024 / 1024).toStringAsFixed(1)} MB)'
                          : 'Pilih File APK',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: changelogCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Changelog',
                    hintText: '- Fix bug login\n- Tambah fitur baru',
                  ),
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            TextButton(
              onPressed: pickedFile != null ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && pickedFile != null) {
      final fileSizeMb = (pickedFile!.size / 1024 / 1024).toStringAsFixed(1);
      setState(() {
        _uploading = true;
        _uploadProgress = 0;
        _uploadStatus = 'Menyiapkan file...';
      });
      try {
        await _api.uploadApk(
          filePath: pickedFile!.path!,
          versionName: versionCtrl.text.trim(),
          versionCode: int.tryParse(versionCodeCtrl.text.trim()) ?? 0,
          changelog: changelogCtrl.text.trim(),
          onProgress: (p) {
            if (mounted) {
              setState(() {
                _uploadProgress = p;
                _uploadStatus = 'Mengupload... ${(p * 100).toStringAsFixed(0)}%  ($fileSizeMb MB)';
              });
            }
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('APK berhasil diupload')));
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    }
  }

  Future<void> _setActive(dynamic version) async {
    try {
      await _api.setActive(version['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('v${version['version_name']} diaktifkan')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _deleteVersion(dynamic version) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Versi?'),
        content: Text('Hapus v${version['version_name']}? APK akan dihapus dari server.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _api.deleteVersion(version['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Versi berhasil dihapus')));
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Versi APK'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _uploading ? null : _showUploadDialog,
            tooltip: 'Upload APK',
          ),
        ],
      ),
      body: Column(
        children: [
          // Upload progress bar
          if (_uploading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: const Color(0xFF00C87A).withValues(alpha: 0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _uploadStatus,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00C87A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _uploadProgress > 0 ? _uploadProgress : null,
                      minHeight: 6,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF00C87A)),
                    ),
                  ),
                ],
              ),
            ),
          // Main content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // Active version card
                  _buildActiveCard(),
                  const SizedBox(height: 16),

                  // All versions
                  const Text('SEMUA VERSI',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),

                  if (_versions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.cloud_upload_outlined,
                                size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text('Belum ada versi APK',
                                style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 4),
                            const Text('Upload APK pertama dari tombol di atas',
                                style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._versions.map(_buildVersionCard),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard() {
    final active = _versions.where((v) => v['is_active'] == 1).firstOrNull;
    return Card(
      color: const Color(0xFF00C87A).withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF00C87A), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Versi Aktif',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    active != null
                        ? 'v${active['version_name']} (code: ${active['version_code']})'
                        : 'Tidak ada versi aktif',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (active != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Diupload: ${active['uploaded_at'] ?? '-'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00C87A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('v${AppVersion.name}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF00C87A),
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionCard(dynamic version) {
    final isActive = version['is_active'] == 1;
    final sizeMb = ((version['file_size_bytes'] ?? 0) / 1024 / 1024).toStringAsFixed(1);
    final changelog = version['changelog'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('v${version['version_name']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 8),
                Text('${sizeMb} MB',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                Text(version['uploaded_at'] ?? '',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C87A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('AKTIF',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF00C87A),
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            if (changelog.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(changelog,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (!isActive)
                  TextButton.icon(
                    onPressed: () => _setActive(version),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Set Aktif', style: TextStyle(fontSize: 12)),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _deleteVersion(version),
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text('Hapus',
                      style: TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../services/api_config.dart';

/// Shows an update notification dialog if a newer version is available.
/// Returns true if user triggered download.
Future<bool> showUpdateDialogIfNeeded(BuildContext context, UpdateInfo info) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _UpdateDialog(info: info),
  );
  return result ?? false;
}

class _UpdateDialog extends StatelessWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  String get _fullDownloadUrl {
    final path = info.downloadUrl ?? '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}${ApiConfig.prefix}$path';
  }

  Future<void> _openInBrowser(BuildContext context) async {
    final uri = Uri.parse(_fullDownloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (context.mounted) Navigator.pop(context, true);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa membuka browser')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Text('🔄 ', style: TextStyle(fontSize: 24)),
          Text('Update Tersedia!'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versi baru: ${info.versionName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Ukuran: ${info.fileSizeMb} MB',
                style: const TextStyle(color: Colors.grey)),
            if (info.changelog != null && info.changelog!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Perubahan:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(info.changelog!,
                    style: const TextStyle(fontSize: 13, height: 1.5)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Nanti'),
        ),
        ElevatedButton.icon(
          onPressed: () => _openInBrowser(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C87A),
          ),
          icon: const Icon(Icons.open_in_browser, color: Colors.white, size: 18),
          label: const Text('Download', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

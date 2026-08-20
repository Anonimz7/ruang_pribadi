import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../config/app_version.dart';

class UpdateInfo {
  final bool updateAvailable;
  final String? versionName;
  final int? versionCode;
  final String? changelog;
  final double? fileSizeMb;
  final String? downloadUrl;

  UpdateInfo({
    required this.updateAvailable,
    this.versionName,
    this.versionCode,
    this.changelog,
    this.fileSizeMb,
    this.downloadUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      updateAvailable: json['update_available'] ?? false,
      versionName: json['version_name'],
      versionCode: json['version_code'],
      changelog: json['changelog'],
      fileSizeMb: (json['file_size_mb'] as num?)?.toDouble(),
      downloadUrl: json['download_url'],
    );
  }
}

class UpdateService {
  static final UpdateService _instance = UpdateService._();
  factory UpdateService() => _instance;
  UpdateService._();

  /// Check for update from server (public endpoint, no auth needed)
  Future<UpdateInfo?> checkUpdate() async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.prefix}/update/check?current_version_code=${AppVersion.code}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UpdateInfo.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
    return null;
  }

  /// Build the full download URL for a given relative path
  String getDownloadUrl(String downloadUrl) {
    if (downloadUrl.startsWith('http')) return downloadUrl;
    return '${ApiConfig.baseUrl}${ApiConfig.prefix}$downloadUrl';
  }

  /// Get update info from login response (admin only)
  UpdateInfo? parseUpdateFromLogin(Map<String, dynamic> userData) {
    final updateData = userData['update'];
    if (updateData == null) return null;
    return UpdateInfo.fromJson(Map<String, dynamic>.from(updateData));
  }
}

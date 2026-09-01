import 'package:flutter/material.dart';
import '../bahasa_jepun/bahasa_jepun.dart';
import '../math_speed/math.dart';
import '../passwrod_generator/pasgen.dart';
import '../news_intel/screens/news_screen.dart';
import '../news_intel/screens/stocks_screen.dart';
import '../news_intel/screens/stock_list_screen.dart';
import '../news_intel/screens/market_screen.dart';
import '../news_intel/screens/idx_upload_screen.dart';
import '../settings/admin_perm_screen.dart';
import '../settings/admin_dashboard_screen.dart';
import '../settings/reports_screen.dart';
import '../settings/sitemaps_screen.dart';
import '../settings/proxy_settings_screen.dart';
import '../settings/profile_screen.dart';
import '../settings/backup_screen.dart';
import '../settings/admin_stock_status_screen.dart';
import '../video_downloader/screens/video_downloader_screen.dart';
import '../gacha_luck/gacha_screen.dart';
import '../rolling/rolling_screen.dart';
import '../code_diagram/screens/code_diagram_screen.dart';
import '../bahasa/screens/bahasa_home_screen.dart';
import 'app_config.dart';
import 'dark_mode_service.dart';

class AppDef {
  final String key;
  final IconData icon;
  final String label;
  final Widget Function(BuildContext) builder;
  final String section;
  final bool defaultPermission;

  const AppDef({
    required this.key,
    required this.icon,
    required this.label,
    required this.builder,
    this.section = 'menu',
    this.defaultPermission = false,
  });
}

List<AppDef> get appRegistry {
  return AppConfig.apps.map((config) => AppDef(
    key: config.key,
    icon: config.icon,
    label: config.label,
    builder: _buildApp(config.key),
    section: config.section,
    defaultPermission: config.defaultPermission,
  )).toList();
}

Widget Function(BuildContext) _buildApp(String key) {
  return switch (key) {
    'settings' => (_) => const PengaturanPage(),
    'profile' => (_) => const ProfileScreen(),
    'japanese_alphabet' => (_) => const BahasaJepun(),
    'math_speed' => (_) => const MathApp(),
    'password_generator' => (_) => const PasswordGeneratorPage(),
    'gacha_luck' => (_) => const GachaLuckScreen(),
    'rolling' => (_) => const RollingScreen(),
    'code_diagram' => (_) => const CodeDiagramScreen(),
    'language' => (_) => const BahasaHomeScreen(),
    'video_downloader' => (_) => const VideoDownloaderScreen(),
    'news' => (_) => const NewsScreen(),
    'stocks' => (_) => const StocksScreen(),
    'stock_list' => (_) => const StockListScreen(),
    'ihsg_radar' => (_) => const MarketScreen(),
    'reports' => (_) => const ReportsScreen(),
    'user_permissions' => (_) => const AdminPermScreen(),
    'server_dashboard' => (_) => const AdminDashboardScreen(),
    'sitemaps' => (_) => const SitemapsScreen(),
    'proxies' => (_) => const ProxySettingsScreen(),
    'backup' => (_) => const BackupScreen(),
    'stock_status' => (_) => const AdminStockStatusScreen(),
    'idx_upload' => (_) => const IdxUploadScreen(),
    _ => (_) => const PlaceholderWidget(),
  };
}

List<String> getDefaultPermissions() {
  return AppConfig.getDefaultPermissions();
}

List<AppDef> getMenuApps() =>
    AppConfig.getMenuApps().map((config) => AppDef(
      key: config.key,
      icon: config.icon,
      label: config.label,
      builder: _buildApp(config.key),
      section: config.section,
      defaultPermission: config.defaultPermission,
    )).toList();

List<AppDef> getMarketApps() =>
    AppConfig.getMarketApps().map((config) => AppDef(
      key: config.key,
      icon: config.icon,
      label: config.label,
      builder: _buildApp(config.key),
      section: config.section,
      defaultPermission: config.defaultPermission,
    )).toList();

List<AppDef> getAdminApps() =>
    AppConfig.getAdminApps().map((config) => AppDef(
      key: config.key,
      icon: config.icon,
      label: config.label,
      builder: _buildApp(config.key),
      section: config.section,
      defaultPermission: config.defaultPermission,
    )).toList();

List<AppDef> getSystemApps() =>
    AppConfig.getSystemApps().map((config) => AppDef(
      key: config.key,
      icon: config.icon,
      label: config.label,
      builder: _buildApp(config.key),
      section: config.section,
      defaultPermission: config.defaultPermission,
    )).toList();

class PengaturanPage extends StatelessWidget {
  const PengaturanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder<bool>(
          valueListenable: darkModeNotifier,
          builder: (context, isDarkMode, child) {
            return SwitchListTile(
              title: const Text('Dark Mode'),
              value: isDarkMode,
              onChanged: (bool value) {
                darkModeNotifier.value = value;
                saveDarkMode(value);
              },
            );
          },
        ),
      ),
    );
  }
}

class PlaceholderWidget extends StatelessWidget {
  const PlaceholderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Ruang Pilihan'));
  }
}
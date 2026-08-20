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
import '../video_downloader/screens/video_downloader_screen.dart';
import '../gacha_luck/gacha_screen.dart';
import '../rolling/rolling_screen.dart';
import '../code_diagram/screens/code_diagram_screen.dart';
import '../bahasa/screens/bahasa_home_screen.dart';
import 'dark_mode_service.dart';

/// App definition
class AppDef {
  final String key;
  final IconData icon;
  final String label;
  final Widget Function(BuildContext) builder;
  final String section; // 'menu' | 'market' | 'admin'

  const AppDef({
    required this.key,
    required this.icon,
    required this.label,
    required this.builder,
    this.section = 'menu',
  });
}

/// ═══════════════════════════════════════════════════════════
/// APP REGISTRY — Semua fitur diatur di sini
/// ═══════════════════════════════════════════════════════════
///
/// SEMUA aplikasi butuh izin admin kecuali 'settings' & 'profile'.
/// User baru → tidak punya akses apa-apa (kecuali settings & profile).
/// Admin centang aplikasi yang boleh diakses per user.
///
/// Cara tambah fitur:
///   1. Buat screen
///   2. Tambah AppDef di bawah
///   3. Tambah key di backend: user_manager.ALL_APPS
///
/// Cara hapus fitur:
///   1. Hapus AppDef di bawah
///   2. Hapus key dari backend: user_manager.ALL_APPS
///
final List<AppDef> appRegistry = [
  // ─── Selalu bisa diakses (tidak butuh izin) ────
  AppDef(
    key: 'settings',
    icon: Icons.settings,
    label: 'Pengaturan',
    builder: (_) => const PengaturanPage(),
    section: 'system',
  ),
  AppDef(
    key: 'profile',
    icon: Icons.person,
    label: 'Profil',
    builder: (_) => const ProfileScreen(),
    section: 'system',
  ),

  // ─── Fitur Lokal (butuh izin admin) ───────────
  AppDef(
    key: 'bahasa_jepang',
    icon: Icons.book,
    label: 'Belajar Alfabet Jepang',
    builder: (_) => const BahasaJepun(),
    section: 'menu',
  ),
  AppDef(
    key: 'math_speed',
    icon: Icons.calculate,
    label: 'Math Speedup',
    builder: (_) => const MathApp(),
    section: 'menu',
  ),
  AppDef(
    key: 'password_generator',
    icon: Icons.password,
    label: 'Password Generator',
    builder: (_) => const PasswordGeneratorPage(),
    section: 'menu',
  ),
  AppDef(
    key: 'gacha_luck',
    icon: Icons.casino,
    label: 'Gacha Keberuntungan',
    builder: (_) => const GachaLuckScreen(),
    section: 'menu',
  ),
  AppDef(
    key: 'rolling',
    icon: Icons.change_circle,
    label: 'Rolling Yes / No',
    builder: (_) => const RollingScreen(),
    section: 'menu',
  ),
  AppDef(
    key: 'code_diagram',
    icon: Icons.account_tree,
    label: 'Render Diagram',
    builder: (_) => const CodeDiagramScreen(),
    section: 'menu',
  ),
  AppDef(
    key: 'bahasa',
    icon: Icons.translate,
    label: 'Bahasa',
    builder: (_) => const BahasaHomeScreen(),
    section: 'menu',
  ),

  // ─── Fitur Backend (butuh izin admin) ──────────
  AppDef(
    key: 'news',
    icon: Icons.article,
    label: 'Berita',
    builder: (_) => const NewsScreen(),
    section: 'market',
  ),
  AppDef(
    key: 'stocks',
    icon: Icons.candlestick_chart,
    label: 'Saham IDX',
    builder: (_) => const StocksScreen(),
    section: 'market',
  ),
  AppDef(
    key: 'stock_list',
    icon: Icons.list_alt,
    label: 'Daftar Saham',
    builder: (_) => const StockListScreen(),
    section: 'market',
  ),
  AppDef(
    key: 'idx_upload',
    icon: Icons.upload_file,
    label: 'Upload IDX',
    builder: (_) => const IdxUploadScreen(),
    section: 'admin',
  ),
  AppDef(
    key: 'ihsg_radar',
    icon: Icons.radar,
    label: 'IHSG Radar',
    builder: (_) => const MarketScreen(),
    section: 'market',
  ),
  AppDef(
    key: 'reports',
    icon: Icons.receipt_long,
    label: 'Laporan',
    builder: (_) => const ReportsScreen(),
    section: 'market',
  ),

  // ─── Admin (admin only) ───────────────────────
  AppDef(
    key: 'admin_perms',
    icon: Icons.admin_panel_settings,
    label: 'Kelola Akses User',
    builder: (_) => const AdminPermScreen(),
    section: 'admin',
  ),
  AppDef(
    key: 'admin_dashboard',
    icon: Icons.dashboard,
    label: 'Dashboard Server',
    builder: (_) => const AdminDashboardScreen(),
    section: 'admin',
  ),
  AppDef(
    key: 'sitemaps',
    icon: Icons.language,
    label: 'Kelola Sitemaps',
    builder: (_) => const SitemapsScreen(),
    section: 'admin',
  ),
  AppDef(
    key: 'proxies',
    icon: Icons.hub,
    label: 'Proxy Scraper',
    builder: (_) => const ProxySettingsScreen(),
    section: 'admin',
  ),
  AppDef(
    key: 'admin_backup',
    icon: Icons.backup,
    label: 'Backup System',
    builder: (_) => const BackupScreen(),
    section: 'admin',
  ),

  // ─── Video Downloader ─────────────────────────────────
  AppDef(
    key: 'video_downloader',
    icon: Icons.download,
    label: 'Video Downloader',
    builder: (_) => const VideoDownloaderScreen(),
    section: 'menu',
  ),
];

// ═══════════════════════════════════════════════════
// PAGES yang bukan bagian dari fitur terpisah
// ═══════════════════════════════════════════════════

class PengaturanPage extends StatelessWidget {
  const PengaturanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder<bool>(
          valueListenable: darkModeNotifier,
          builder: (context, isDarkMode, child) {
            return SwitchListTile(
              title: const Text('Mode Gelap'),
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

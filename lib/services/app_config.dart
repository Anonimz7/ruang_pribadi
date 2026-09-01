import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class MenuConfig {
  final String key;
  final IconData icon;
  final String label;
  final String section;
  final bool defaultPermission;

  MenuConfig({
    required this.key,
    required this.icon,
    required this.label,
    required this.section,
    required this.defaultPermission,
  });

  factory MenuConfig.fromJson(Map<String, dynamic> json) {
    return MenuConfig(
      key: json['key'] as String,
      icon: _parseIcon(json['icon'] as String? ?? 'Icons.help'),
      label: json['label'] as String? ?? json['key'] as String,
      section: json['section'] as String? ?? 'menu',
      defaultPermission: json['defaultPermission'] as bool? ?? false,
    );
  }

  static IconData _parseIcon(String iconName) {
    final iconMap = {
      'Icons.settings': Icons.settings,
      'Icons.person': Icons.person,
      'Icons.book': Icons.book,
      'Icons.calculate': Icons.calculate,
      'Icons.password': Icons.password,
      'Icons.casino': Icons.casino,
      'Icons.change_circle': Icons.change_circle,
      'Icons.account_tree': Icons.account_tree,
      'Icons.translate': Icons.translate,
      'Icons.download': Icons.download,
      'Icons.article': Icons.article,
      'Icons.candlestick_chart': Icons.candlestick_chart,
      'Icons.list_alt': Icons.list_alt,
      'Icons.radar': Icons.radar,
      'Icons.receipt_long': Icons.receipt_long,
      'Icons.admin_panel_settings': Icons.admin_panel_settings,
      'Icons.dashboard': Icons.dashboard,
      'Icons.language': Icons.language,
      'Icons.hub': Icons.hub,
      'Icons.backup': Icons.backup,
      'Icons.shield': Icons.shield,
      'Icons.upload_file': Icons.upload_file,
      'Icons.help': Icons.help,
    };
    return iconMap[iconName] ?? Icons.help;
  }
}

class AppConfig {
  static List<MenuConfig> _apps = [];
  static bool _isLoaded = false;

  static Future<void> load() async {
    if (_isLoaded) return;

    try {
      final jsonStr = await rootBundle.loadString('assets/config/menu_config.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final appsList = data['apps'] as List;
      _apps = appsList.map((e) => MenuConfig.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      // fallback to default config
      _apps = _getDefaultApps();
    }
    _isLoaded = true;
  }

  static List<MenuConfig> get apps => _apps;
  static bool get isLoaded => _isLoaded;

  static List<MenuConfig> _getDefaultApps() {
    return [
      MenuConfig(key: 'settings', icon: Icons.settings, label: 'Settings', section: 'system', defaultPermission: false),
      MenuConfig(key: 'profile', icon: Icons.person, label: 'Profile', section: 'system', defaultPermission: false),
      MenuConfig(key: 'japanese_alphabet', icon: Icons.book, label: 'Learn Japanese Alphabet', section: 'menu', defaultPermission: true),
      MenuConfig(key: 'math_speed', icon: Icons.calculate, label: 'Math Speed', section: 'menu', defaultPermission: true),
      MenuConfig(key: 'password_generator', icon: Icons.password, label: 'Password Generator', section: 'menu', defaultPermission: true),
      MenuConfig(key: 'gacha_luck', icon: Icons.casino, label: 'Gacha Luck', section: 'menu', defaultPermission: true),
      MenuConfig(key: 'rolling', icon: Icons.change_circle, label: 'Rolling Yes/No', section: 'menu', defaultPermission: true),
      MenuConfig(key: 'code_diagram', icon: Icons.account_tree, label: 'Render Diagram', section: 'menu', defaultPermission: true),
      MenuConfig(key: 'language', icon: Icons.translate, label: 'Language', section: 'menu', defaultPermission: true),
      MenuConfig(key: 'video_downloader', icon: Icons.download, label: 'Video Downloader', section: 'menu', defaultPermission: true),
      MenuConfig(key: 'news', icon: Icons.article, label: 'News', section: 'market', defaultPermission: true),
      MenuConfig(key: 'stocks', icon: Icons.candlestick_chart, label: 'IDX Stocks', section: 'market', defaultPermission: true),
      MenuConfig(key: 'stock_list', icon: Icons.list_alt, label: 'Stock List', section: 'market', defaultPermission: true),
      MenuConfig(key: 'ihsg_radar', icon: Icons.radar, label: 'IHSG Radar', section: 'market', defaultPermission: true),
      MenuConfig(key: 'reports', icon: Icons.receipt_long, label: 'Reports', section: 'market', defaultPermission: true),
      MenuConfig(key: 'user_permissions', icon: Icons.admin_panel_settings, label: 'User Permissions', section: 'admin', defaultPermission: false),
      MenuConfig(key: 'server_dashboard', icon: Icons.dashboard, label: 'Server Dashboard', section: 'admin', defaultPermission: false),
      MenuConfig(key: 'sitemaps', icon: Icons.language, label: 'Sitemaps', section: 'admin', defaultPermission: false),
      MenuConfig(key: 'proxies', icon: Icons.hub, label: 'Proxy Scraper', section: 'admin', defaultPermission: false),
      MenuConfig(key: 'backup', icon: Icons.backup, label: 'Backup System', section: 'admin', defaultPermission: false),
      MenuConfig(key: 'stock_status', icon: Icons.shield, label: 'Stock Status', section: 'admin', defaultPermission: false),
      MenuConfig(key: 'idx_upload', icon: Icons.upload_file, label: 'IDX Upload', section: 'admin', defaultPermission: false),
    ];
  }

  static List<String> getDefaultPermissions() {
    return _apps
        .where((app) => app.defaultPermission && app.section != 'admin')
        .map((app) => app.key)
        .toList();
  }

  static List<MenuConfig> getMenuApps() => _apps.where((a) => a.section == 'menu').toList();
  static List<MenuConfig> getMarketApps() => _apps.where((a) => a.section == 'market').toList();
  static List<MenuConfig> getAdminApps() => _apps.where((a) => a.section == 'admin').toList();
  static List<MenuConfig> getSystemApps() => _apps.where((a) => a.section == 'system').toList();
}
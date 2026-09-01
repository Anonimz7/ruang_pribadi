import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/app_config.dart';

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final ApiClient client;
  final VoidCallback onLogout;
  final VoidCallback? onLoginTap;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.client,
    required this.onLogout,
    this.onLoginTap,
  });

  bool _isAccessible(MenuConfig app) {
    if (app.section == 'system') return true;
    if (client.isMenuHidden(app.key)) return false;
    if (app.section == 'admin') return client.tier == 'admin';
    if (!client.isLoggedIn) return false;
    return client.canAccess(app.key);
  }

  bool _isHidden(MenuConfig app) {
    if (app.section == 'system') return false;
    return client.isMenuHidden(app.key);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final systemApps = AppConfig.getSystemApps();
    final menuApps = AppConfig.getMenuApps();
    final marketApps = AppConfig.getMarketApps();
    final adminApps = AppConfig.getAdminApps();

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(isDark, context),
          ...systemApps.map((app) => _tile(context, app, locked: false)),
          const Divider(),
          if (client.isLoggedIn) _buildMenuSection(menuApps, context, 'FEATURES'),
          if (client.isLoggedIn) const Divider(),
          if (client.isLoggedIn) _buildMenuSection(marketApps, context, 'AI RADAR'),
          if (client.tier == 'admin')
            Column(
              children: [
                const Divider(),
                const _SectionLabel('ADMIN'),
                ...adminApps.map((app) => _tile(context, app, locked: false)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(bool isDark, BuildContext context) {
    return DrawerHeader(
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B263B) : Colors.blue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('Menu Navigasi',
              style: TextStyle(color: Colors.white, fontSize: 24)),
          const SizedBox(height: 8),
          _buildHeaderUserInfo(context),
        ],
      ),
    );
  }

  Widget _buildHeaderUserInfo(BuildContext context) {
    return Row(
      children: [
        Icon(client.isLoggedIn ? Icons.check_circle : Icons.login,
            color: client.isLoggedIn
                ? const Color(0xFF00C87A)
                : Colors.white70,
            size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: client.isLoggedIn
              ? Text('${client.username} (${client.tier})',
                  style: const TextStyle(color: Color(0xFF00C87A), fontSize: 12))
              : GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onLoginTap?.call();
                  },
                  child: Text('Not logged in — tap to login',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white54)),
                ),
        ),
        if (client.isLoggedIn)
          GestureDetector(
              onTap: onLogout,
              child: const Text('Logout',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12))),
      ],
    );
  }

  Widget _buildMenuSection(List<MenuConfig> apps, BuildContext context, String title) {
    final visibleApps = apps.where((a) => _isAccessible(a) && !_isHidden(a)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title),
        const SizedBox(height: 8),
        ...visibleApps.map((app) => _tile(context, app)),
      ],
    );
  }

  Widget _tile(BuildContext context, MenuConfig app, {bool locked = false}) {
    final idx = AppConfig.apps.indexWhere((a) => a.key == app.key);
    final isSelected = selectedIndex == idx;

    return ListTile(
      leading: Icon(app.icon, color: locked ? Colors.grey : null),
      title: Row(
        children: [
          Flexible(
              child: Text(app.label,
                  style: TextStyle(
                      color: locked ? Colors.grey : null, fontSize: 14))),
          if (locked)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.lock_outline, size: 14, color: Colors.grey)),
        ],
      ),
      selected: isSelected,
      onTap: () => onItemTapped(idx),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.5)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.5)),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:ruang_pribadi/services/app_registry.dart';
import '../services/apis.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String tier;

  const AdminUserDetailScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.tier,
  });

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  final _api = AdminApi();
  List<String> _allApps = [];
  List<String> _permissions = [];
  List<String> _hiddenMenus = [];
  List<String> _defaultPerms = [];
  bool _loading = true;
  String? _created;
  String? _lastLogin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getUserDetail(widget.userId),
        _api.getAllApps(),
        _api.getDefaultPermissions(),
      ]);
      final detail = results[0] as Map<String, dynamic>;
      setState(() {
        _allApps = List<String>.from(results[1] as List<dynamic>);
        if (_allApps.isEmpty) {
          _allApps = appRegistry.map((a) => a.key).toList();
        }
        _permissions = List<String>.from(detail['permissions'] ?? []);
        _hiddenMenus = List<String>.from(detail['hidden_menus'] ?? []);
        final permsResult = results[2] as Map<String, dynamic>;
        _defaultPerms = List<String>.from(
            permsResult['default_permissions'] ?? []);
        if (_defaultPerms.isEmpty) {
          _defaultPerms = getDefaultPermissions();
        }
        _created = detail['created_at'];
        _lastLogin = detail['last_login'];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  bool get isAdmin => widget.tier == 'admin';

  Future<void> _togglePerm(String appKey, bool grant) async {
    try {
      grant
          ? await _api.grantPermission(widget.userId, appKey)
          : await _api.revokePermission(widget.userId, appKey);
      setState(() {
        grant ? _permissions.add(appKey) : _permissions.remove(appKey);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _setPerms(List<String> perms) async {
    try {
      await _api.setPermissions(widget.userId, perms);
      setState(() => _permissions = List.from(perms));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _toggleVisibility(String appKey, bool hide) async {
    try {
      hide
          ? await _api.hideMenu(widget.userId, appKey)
          : await _api.showMenu(widget.userId, appKey);
      setState(() {
        hide ? _hiddenMenus.add(appKey) : _hiddenMenus.remove(appKey);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _deleteUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text(
            'Are you sure you want to delete user "${widget.username}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _api.deleteUser(widget.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User deleted successfully')));
          Navigator.pop(context, true);
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
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.username)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
        actions: [
          if (!isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteUser,
              tooltip: 'Delete user',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildUserInfoCard(),
            const SizedBox(height: 16),

            if (!isAdmin) ...[
              _buildQuickActions(),
              const SizedBox(height: 20),
              ..._buildMenuSections(),
            ],

            if (isAdmin)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C87A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF00C87A).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF00C87A)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Admin has full access to all features. '
                        'Menus are always visible.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    final isAdmin = widget.tier == 'admin';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor:
                  isAdmin ? const Color(0xFF00C87A) : Colors.orange,
              child: Text(
                widget.username[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.username,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isAdmin
                          ? const Color(0xFF00C87A).withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isAdmin ? 'admin' : 'guest',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color:
                              isAdmin ? const Color(0xFF00C87A) : Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('QUICK ACTIONS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _setPerms(List.from(_allApps)),
                    icon: const Icon(Icons.check_circle_outline,
                        size: 16, color: Colors.green),
                    label: const Text('Grant All',
                        style: TextStyle(fontSize: 12, color: Colors.green)),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.green.withValues(alpha: 0.5))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _setPerms([]),
                    icon: const Icon(Icons.block, size: 16, color: Colors.red),
                    label: const Text('Revoke All',
                        style: TextStyle(fontSize: 12, color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.red.withValues(alpha: 0.5))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _setPerms(List.from(_defaultPerms)),
                    icon: const Icon(Icons.auto_awesome,
                        size: 16, color: Colors.amber),
                    label: const Text('Default',
                        style: TextStyle(fontSize: 12, color: Colors.amber)),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.amber.withValues(alpha: 0.5))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${_permissions.length} / ${_allApps.length} features allowed',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMenuSections() {
    return [
      _buildMenuSection('FEATURES', getMenuApps().map((a) => a.key).toList()),
      const SizedBox(height: 12),
      _buildMenuSection('VIDEO', ['video_downloader']),
      const SizedBox(height: 12),
      _buildMenuSection('AI RADAR', getMarketApps().map((a) => a.key).toList()),
      const SizedBox(height: 12),
      _buildMenuSection('ADMIN', getAdminApps().map((a) => a.key).toList()),
    ];
  }

  Widget _buildMenuSection(String title, List<String> apps) {
    final visibleApps = apps.where((a) => _allApps.contains(a)).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1)),
            const SizedBox(height: 12),
            ...visibleApps.map((appKey) => _buildMenuTile(appKey)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(String appKey) {
    final hasAccess = _permissions.contains(appKey);
    final isHidden = _hiddenMenus.contains(appKey);
    final label = _label(appKey);
    final color = _color(appKey);

    String statusText;
    Color statusColor;
    if (hasAccess && !isHidden) {
      statusText = 'Active';
      statusColor = const Color(0xFF00C87A);
    } else if (hasAccess && isHidden) {
      statusText = 'Hidden';
      statusColor = Colors.orange;
    } else {
      statusText = 'Inactive';
      statusColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Switch(
            value: hasAccess,
            onChanged: (v) => _togglePerm(appKey, v),
            activeColor: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                Text(statusText,
                    style: TextStyle(fontSize: 11, color: statusColor)),
              ],
            ),
          ),
          if (hasAccess)
            IconButton(
              icon: Icon(
                isHidden ? Icons.visibility_off : Icons.visibility,
                size: 20,
                color: isHidden ? Colors.orange : const Color(0xFF00C87A),
              ),
              onPressed: () => _toggleVisibility(appKey, !isHidden),
              tooltip: isHidden ? 'Show in drawer' : 'Hide from drawer',
            ),
        ],
      ),
    );
  }

  String _label(String key) {
    final app = appRegistry.firstWhere(
      (a) => a.key == key,
      orElse: () => AppDef(
        key: '',
        icon: Icons.help,
        label: '',
        builder: (_) => const PlaceholderWidget(),
      ),
    );
    if (app.label.isNotEmpty) return app.label;
    return key;
  }

  Color _color(String key) {
    final app = appRegistry.firstWhere(
      (a) => a.key == key,
      orElse: () => AppDef(
        key: '',
        icon: Icons.help,
        label: '',
        builder: (_) => const PlaceholderWidget(),
      ),
    );
    if (app.icon != Icons.help) {
      return _iconToColor(app.icon);
    }
    return Colors.grey;
  }

  Color _iconToColor(IconData icon) {
    switch (icon) {
      case Icons.book:
        return Colors.red;
      case Icons.calculate:
        return Colors.orange;
      case Icons.password:
        return Colors.teal;
      case Icons.casino:
        return Colors.amber;
      case Icons.change_circle:
        return Colors.lightGreen;
      case Icons.account_tree:
        return Colors.indigo;
      case Icons.translate:
        return Colors.lightBlue;
      case Icons.download:
        return Colors.pink;
      case Icons.article:
        return Colors.blue;
      case Icons.candlestick_chart:
        return Colors.green;
      case Icons.list_alt:
        return Colors.teal;
      case Icons.upload_file:
        return Colors.brown;
      case Icons.radar:
        return Colors.purple;
      case Icons.receipt_long:
        return Colors.indigo;
      case Icons.dashboard:
        return Colors.cyan;
      case Icons.language:
        return Colors.teal;
      case Icons.hub:
        return Colors.deepPurple;
      case Icons.backup:
        return Colors.blueGrey;
      case Icons.shield:
        return Colors.green;
      case Icons.settings:
        return Colors.blue;
      case Icons.person:
        return Colors.orange;
      case Icons.admin_panel_settings:
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }
}
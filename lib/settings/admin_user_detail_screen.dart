import 'package:flutter/material.dart';
import '../services/apis.dart';

/// Detail page for managing a single user's permissions and visibility.
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
        _permissions = List<String>.from(detail['permissions'] ?? []);
        _hiddenMenus = List<String>.from(detail['hidden_menus'] ?? []);
        _defaultPerms = List<String>.from(
            (results[2] as Map<String, dynamic>)['default_permissions'] ?? []);
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

  // ─── Permission toggles ───────────────────────────────

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

  // ─── Visibility toggles ───────────────────────────────

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
        title: const Text('Hapus User?'),
        content: Text(
            'Apakah kamu yakin ingin menghapus user "${widget.username}"?'),
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
        await _api.deleteUser(widget.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User berhasil dihapus')));
          Navigator.pop(context, true); // return true to signal refresh
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
              tooltip: 'Hapus user',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── User Info ─────────────────────────
            _buildUserInfoCard(),
            const SizedBox(height: 16),

            if (!isAdmin) ...[
              // ─── Quick Actions ─────────────────────
              _buildQuickActions(),
              const SizedBox(height: 20),

              // ─── Permissions & Visibility ─────────
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
                        'Admin memiliki akses penuh ke semua fitur. '
                        'Menu selalu tampil.',
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
                            isAdmin ? const Color(0xFF00C87A) : Colors.orange,
                      ),
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
            const Text('AKSI CEPAT',
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
                    label: const Text('Izinkan Semua',
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
                    label: const Text('Cabut Semua',
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
            Text('${_permissions.length} / ${_allApps.length} fitur diizinkan',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMenuSections() {
    return [
      _buildMenuSection('FITUR LOKAL', [
        'bahasa',
        'bahasa_jepang',
        'math_speed',
        'password_generator',
        'gacha_luck',
        'rolling',
        'code_diagram',
      ]),
      const SizedBox(height: 12),
      _buildMenuSection('VIDEO', [
        'video_downloader',
      ]),
      const SizedBox(height: 12),
      _buildMenuSection('IHSG RADAR', [
        'news',
        'stocks',
        'stock_list',
        'ihsg_radar',
        'reports',
      ]),
      const SizedBox(height: 12),
      _buildMenuSection('ADMIN', [
        'admin_dashboard',
        'sitemaps',
        'proxies',
        'admin_backup',
        'idx_upload',
      ]),
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

    // Permission + visibility label
    String statusText;
    Color statusColor;
    if (hasAccess && !isHidden) {
      statusText = 'Aktif';
      statusColor = const Color(0xFF00C87A);
    } else if (hasAccess && isHidden) {
      statusText = 'Tersembunyi';
      statusColor = Colors.orange;
    } else {
      statusText = 'Nonaktif';
      statusColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Permission toggle
          Switch(
            value: hasAccess,
            onChanged: (v) => _togglePerm(appKey, v),
            activeColor: color,
          ),
          const SizedBox(width: 8),
          // Label
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
          // Visibility toggle
          if (hasAccess)
            IconButton(
              icon: Icon(
                isHidden ? Icons.visibility_off : Icons.visibility,
                size: 20,
                color: isHidden ? Colors.orange : const Color(0xFF00C87A),
              ),
              onPressed: () => _toggleVisibility(appKey, !isHidden),
              tooltip:
                  isHidden ? 'Tampilkan di drawer' : 'Sembunyikan dari drawer',
            ),
        ],
      ),
    );
  }

  String _label(String key) {
    const map = {
      'bahasa': '🌐 Bahasa',
      'bahasa_jepang': '🇯🇵 Bahasa Jepang',
      'math_speed': '🧮 Math Speed',
      'password_generator': '🔑 Password Gen',
      'gacha_luck': '🎰 Gacha Keberuntungan',
      'rolling': '🎲 Rolling Yes/No',
      'code_diagram': '📐 Render Diagram',
      'video_downloader': '🎬 Video Downloader',
      'news': '📰 Berita',
      'stocks': '📈 Saham IDX',
      'stock_list': '📋 Daftar Saham',
      'ihsg_radar': '📡 IHSG Radar',
      'reports': '📋 Laporan',
      'admin_dashboard': '📊 Dashboard',
      'sitemaps': '🌐 Sitemaps',
      'proxies': '🔗 Proxy Scraper',
      'admin_backup': '💾 Backup',
      'idx_upload': '📤 Upload IDX',
    };
    return map[key] ?? key;
  }

  Color _color(String key) {
    const map = {
      'bahasa': Colors.lightBlue,
      'bahasa_jepang': Colors.red,
      'math_speed': Colors.orange,
      'password_generator': Colors.teal,
      'gacha_luck': Colors.amber,
      'rolling': Colors.lightGreen,
      'code_diagram': Colors.indigo,
      'video_downloader': Colors.pink,
      'news': Colors.blue,
      'stocks': Colors.green,
      'stock_list': Colors.teal,
      'ihsg_radar': Colors.purple,
      'reports': Colors.indigo,
      'admin_dashboard': Colors.cyan,
      'sitemaps': Colors.teal,
      'proxies': Colors.deepPurple,
      'admin_backup': Colors.blueGrey,
      'idx_upload': Colors.brown,
    };
    return map[key] ?? Colors.grey;
  }
}

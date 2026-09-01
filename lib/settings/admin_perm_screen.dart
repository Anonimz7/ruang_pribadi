import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ruang_pribadi/services/app_registry.dart';
import 'admin_user_detail_screen.dart';
import '../services/apis.dart';

class AdminPermScreen extends StatefulWidget {
  const AdminPermScreen({super.key});

  @override
  State<AdminPermScreen> createState() => _AdminPermScreenState();
}

class _AdminPermScreenState extends State<AdminPermScreen> {
  final _api = AdminApi();
  final _searchController = TextEditingController();
  List<dynamic> _users = [];
  List<String> _allApps = [];
  List<String> _defaultPerms = [];
  bool _loading = true;
  Timer? _debounce;
  bool _showDefaultSection = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        _api.getUsers(),
        _api.getAllApps(),
        _api.getDefaultPermissions(),
      ]);
      setState(() {
        _users = r[0] as List<dynamic>;
        _allApps = List<String>.from(r[1] as List<dynamic>);
        if (_allApps.isEmpty) {
          _allApps = appRegistry.map((a) => a.key).toList();
        }
        final permsResult = r[2] as Map<String, dynamic>;
        _defaultPerms = List<String>.from(
            permsResult['default_permissions'] ?? []);
        if (_defaultPerms.isEmpty) {
          _defaultPerms = getDefaultPermissions();
        }
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

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().isEmpty) {
        _load();
        return;
      }
      setState(() => _loading = true);
      try {
        final results = await _api.searchUsers(query.trim());
        setState(() => _users = results);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      } finally {
        setState(() => _loading = false);
      }
    });
  }

  Future<void> _showCreateUserDialog() async {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedTier = 'guest';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create New User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter username',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Minimum 4 characters',
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedTier,
                items: const [
                  DropdownMenuItem(value: 'guest', child: Text('Guest')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedTier = v);
                },
                decoration: const InputDecoration(labelText: 'Tier'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && usernameCtrl.text.trim().isNotEmpty) {
      try {
        await _api.createUser(
          username: usernameCtrl.text.trim(),
          password: passwordCtrl.text,
          tier: selectedTier,
          permissions: List.from(_defaultPerms),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User created successfully')));
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

  Future<void> _deleteUser(dynamic user) async {
    final username = user['username'] ?? '';
    final userId = user['id'];
    if (username == 'xoot') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot delete main admin')));
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User?'),
        content:
            Text('Are you sure you want to delete user "$username"?'),
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
        await _api.deleteUser(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User deleted successfully')));
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

  Future<void> _toggleDefault(String appKey, bool grant) async {
    try {
      final newPerms = List<String>.from(_defaultPerms);
      grant ? newPerms.add(appKey) : newPerms.remove(appKey);
      await _api.setDefaultPermissions(newPerms);
      setState(() => _defaultPerms = newPerms);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage User Access'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showCreateUserDialog,
            tooltip: 'Add User',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _users.isEmpty
                        ? ListView(
                            children: [
                              _buildDefaultSection(),
                              const SizedBox(height: 48),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.people_outline,
                                        size: 48,
                                        color:
                                            Colors.grey.withValues(alpha: 0.5)),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchController.text.isNotEmpty
                                          ? 'No users found'
                                          : 'No users yet',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            itemCount:
                                _users.length + 1,
                            itemBuilder: (ctx, i) {
                              if (i == 0) return _buildDefaultSection();
                              return _buildUserCard(_users[i - 1]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    final isAdmin = user['tier'] == 'admin';
    final perms = List<String>.from(user['permissions'] ?? []);
    final username = user['username'] ?? '';
    final userId = user['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor:
              isAdmin ? const Color(0xFF00C87A) : Colors.orange,
          child: Text(username[0].toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
        title: Row(
          children: [
            Text(username,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isAdmin
                    ? const Color(0xFF00C87A).withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isAdmin ? 'admin' : 'guest',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isAdmin
                        ? const Color(0xFF00C87A)
                        : Colors.orange),
              ),
            ),
          ],
        ),
        subtitle: Text(
          isAdmin
              ? 'Full access'
              : '${perms.length} / ${_allApps.length} features allowed',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isAdmin)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: Colors.red),
                onPressed: () => _deleteUser(user),
                tooltip: 'Hapus user',
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminUserDetailScreen(
                userId: userId,
                username: username,
                tier: user['tier'] ?? 'guest',
              ),
            ),
          );
          if (result == true) _load();
        },
      ),
    );
  }

  Widget _buildDefaultSection() {
    final menuApps = getMenuApps();
    final marketApps = getMarketApps();
    final adminApps = getAdminApps();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _showDefaultSection = !_showDefaultSection),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Color(0xFF00C87A), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Default for New Users',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 2),
                        Text('Features granted upon registration',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C87A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${_defaultPerms.length} aktif',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF00C87A),
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _showDefaultSection
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_showDefaultSection)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const Text('FEATURES',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        menuApps.map((app) => _defaultChip(app.key)).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('AI RADAR',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: marketApps
                        .map((app) => _defaultChip(app.key))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('VIDEO',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allApps
                        .where((a) => ['video_downloader'].contains(a))
                        .map((app) => _defaultChip(app))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('ADMIN',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        adminApps.map((app) => _defaultChip(app.key)).toList(),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: 16, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text(
                          'New users will automatically get the features checked here.',
                          style: TextStyle(fontSize: 11),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _defaultChip(String appKey) {
    final isActive = _defaultPerms.contains(appKey);
    return FilterChip(
      label: Text(_label(appKey),
          style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.white : null,
              fontWeight: isActive ? FontWeight.w600 : null)),
      selected: isActive,
      selectedColor: _color(appKey),
      backgroundColor: Colors.grey.withOpacity(0.15),
      checkmarkColor: Colors.white,
      onSelected: (v) => _toggleDefault(appKey, v),
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

    const emojiMap = {
      'language': '🌐 Language',
      'japanese_alphabet': '🇯🇵 Japanese Alphabet',
      'math_speed': '🧮 Math Speed',
      'password_generator': '🔑 Password Gen',
      'gacha_luck': '🎰 Gacha Luck',
      'rolling': '🎲 Rolling Yes/No',
      'code_diagram': '📐 Render Diagram',
      'video_downloader': '🎬 Video Downloader',
      'news': '📰 News',
      'stocks': '📈 IDX Stocks',
      'stock_list': '📋 Stock List',
      'ihsg_radar': '📡 IHSG Radar',
      'reports': '📋 Reports',
      'user_permissions': '🔐 User Permissions',
      'server_dashboard': '📊 Dashboard',
      'sitemaps': '🌐 Sitemaps',
      'proxies': '🔗 Proxy Scraper',
      'backup': '💾 Backup',
      'stock_status': '🛡️ Stock Status',
      'idx_upload': '📤 IDX Upload',
    };
    return emojiMap[key] ?? key;
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
    const colorMap = {
      'language': Colors.lightBlue,
      'japanese_alphabet': Colors.red,
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
      'user_permissions': Colors.blueGrey,
      'server_dashboard': Colors.cyan,
      'sitemaps': Colors.teal,
      'proxies': Colors.deepPurple,
      'backup': Colors.blueGrey,
      'stock_status': Colors.green,
      'idx_upload': Colors.brown,
    };
    return colorMap[key] ?? Colors.grey;
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
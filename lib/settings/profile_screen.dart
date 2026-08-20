import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/apis.dart';
import '../../services/update_service.dart';
import '../../widgets/update_dialog.dart';
import '../../widgets/login_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _client = ApiClient();
  final _api = AuthApi();

  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _changingPass = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final oldPass = _oldPassCtrl.text.trim();
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua field harus diisi')),
      );
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password baru tidak cocok')),
      );
      return;
    }

    if (newPass.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password minimal 4 karakter')),
      );
      return;
    }

    setState(() => _changingPass = true);
    try {
      await _api.changePassword(oldPass, newPass);
      _oldPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Password berhasil diubah'),
            backgroundColor: Color(0xFF00C87A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _changingPass = false);
    }
  }

  Future<void> _checkUpdate() async {
    try {
      final info = await UpdateService().checkUpdate();
      if (!mounted) return;
      if (info != null && info.updateAvailable) {
        showUpdateDialogIfNeeded(context, info);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sudah versi terbaru'),
            backgroundColor: Color(0xFF00C87A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal cek update: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _client.isLoggedIn;
    final username = _client.username;
    final tier = _client.tier;
    final isAdmin = tier == 'admin';
    final perms = _client.permissions;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: isLoggedIn
            ? _buildLoggedInView(username, isAdmin, perms)
            : _buildLoggedOutView(context),
      ),
    );
  }

  // ── Not logged in ────────────────────────────────────
  Widget _buildLoggedOutView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline,
                size: 80, color: Colors.grey.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('Belum Login',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Silakan login untuk melihat profil\ndan mengatur akun Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Show login popup — dialog closes itself on success,
                // then ProfileScreen rebuilds automatically to show logged-in view
                showLoginDialog(context, onSuccess: () {
                  if (mounted) setState(() {});
                });
              },
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('LOGIN',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C87A),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logged in ────────────────────────────────────────
  Widget _buildLoggedInView(
      String username, bool isAdmin, List<String> perms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── User Info Card ────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor:
                      isAdmin ? const Color(0xFF00C87A) : Colors.orange,
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(username,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAdmin
                        ? const Color(0xFF00C87A).withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isAdmin ? '👑 ADMIN' : '👤 GUEST',
                    style: TextStyle(
                      color:
                          isAdmin ? const Color(0xFF00C87A) : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ─── Permissions ───────────────────
        const Text('IZIN AKSES',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isAdmin
                ? const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF00C87A)),
                      SizedBox(width: 8),
                      Text('Akses penuh ke semua fitur',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  )
                : perms.isEmpty
                    ? const Text('Tidak ada izin akses',
                        style: TextStyle(color: Colors.grey))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: perms.map((p) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C87A)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFF00C87A)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(p,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF00C87A),
                                    fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                      ),
          ),
        ),
        const SizedBox(height: 24),

        // ─── Change Password ───────────────
        const Text('UBAH PASSWORD',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _oldPassCtrl,
                  obscureText: _obscureOld,
                  decoration: InputDecoration(
                    labelText: 'Password Lama',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureOld
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureOld = !_obscureOld),
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPassCtrl,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Password Baru',
                    prefixIcon: const Icon(Icons.lock_reset),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPassCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi Password Baru',
                    prefixIcon: const Icon(Icons.lock_reset),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _changingPass ? null : _changePassword,
                    icon: _changingPass
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save, color: Colors.white),
                    label: Text(
                      _changingPass
                          ? 'Menyimpan...'
                          : 'Simpan Password Baru',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _changingPass
                          ? Colors.grey
                          : const Color(0xFF00C87A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Cek Update ─────────────────────
        const SizedBox(height: 24),
        const Text('UPDATE',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading:
                const Icon(Icons.system_update, color: Color(0xFF00C87A)),
            title: const Text('Cek Update'),
            subtitle: const Text('Cek versi terbaru dari server'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _checkUpdate(),
          ),
        ),
      ],
    );
  }
}

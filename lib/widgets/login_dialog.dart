import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/apis.dart';

/// Reusable login/register dialog popup.
/// Call [showLoginDialog] from anywhere to display it.
Future<void> showLoginDialog(BuildContext context, {VoidCallback? onSuccess}) {
  final client = ApiClient();
  return showDialog(
    context: context,
    builder: (ctx) => LoginDialog(
      client: client,
      onSuccess: () {
        onSuccess?.call();
      },
    ),
  );
}

class LoginDialog extends StatefulWidget {
  final ApiClient client;
  final VoidCallback onSuccess;
  const LoginDialog({super.key, required this.client, required this.onSuccess});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _isLogin = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isLogin) {
        await AuthApi().login(_userCtrl.text.trim(), _passCtrl.text);
        widget.onSuccess();
        if (mounted) Navigator.pop(context);
      } else {
        await AuthApi().register(_userCtrl.text.trim(), _passCtrl.text);
        setState(() {
          _isLogin = true;
          _error = 'Registrasi berhasil! Silakan login.';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(_isLogin ? Icons.login : Icons.person_add, size: 24),
          const SizedBox(width: 8),
          Text(_isLogin ? 'Login' : 'Register'),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: TextStyle(
                    color: _error!.contains('berhasil')
                        ? Colors.green
                        : Colors.red,
                    fontSize: 12,
                  )),
            ],
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => setState(() {
                _isLogin = !_isLogin;
                _error = null;
              }),
              child: Text(
                _isLogin
                    ? 'Belum punya akun? Register'
                    : 'Sudah punya akun? Login',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C87A),
            foregroundColor: Colors.black,
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isLogin ? 'LOGIN' : 'REGISTER'),
        ),
      ],
    );
  }
}

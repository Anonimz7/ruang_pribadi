import 'package:flutter/material.dart';
import '../../services/apis.dart';
import '../../services/api_client.dart';
import 'bahasa_list_screen.dart';
import 'bahasa_form_screen.dart';

/// Menu BAHASA — pilihan pasangan bahasa (dari DISTINCT string_lang di DB).
class BahasaHomeScreen extends StatefulWidget {
  const BahasaHomeScreen({super.key});

  @override
  State<BahasaHomeScreen> createState() => _BahasaHomeScreenState();
}

class _BahasaHomeScreenState extends State<BahasaHomeScreen> {
  final _api = BahasaApi();

  List<dynamic> _pairs = [];
  bool _loading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _isAdmin = ApiClient().tier == 'admin';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pairs = await _api.pairs();
      setState(() => _pairs = pairs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPair(String stringLang) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BahasaListScreen(stringLang: stringLang),
      ),
    );
    _load(); // refresh kalau admin menambah/ubah dari screen itu
  }

  Future<void> _openBaru() async {
    final doc = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BahasaFormScreen()),
    );
    if (doc != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bahasa'), actions: [
        if (_isAdmin)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Dokumen Bahasa',
            onPressed: _openBaru,
          ),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pairs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.translate,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('Belum ada pasangan bahasa',
                          style: TextStyle(color: Colors.grey)),
                      if (_isAdmin) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tekan ikon + di kanan atas untuk tambah',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _pairs.length,
                    itemBuilder: (_, i) {
                      final p = _pairs[i];
                      final lang = p['string_lang'] ?? '?';
                      final jumlah = p['jumlah'] ?? 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF00C87A)
                                .withValues(alpha: 0.15),
                            child: Icon(Icons.translate,
                                color: const Color(0xFF00C87A), size: 20),
                          ),
                          title: Text(lang,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('$jumlah dokumen tersimpan',
                              style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openPair(lang),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
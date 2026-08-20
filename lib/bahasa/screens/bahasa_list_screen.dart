import 'package:flutter/material.dart';
import '../../services/apis.dart';
import '../../services/api_client.dart';
import 'bahasa_detail_screen.dart';
import 'bahasa_form_screen.dart';

/// Daftar dokumen kamus untuk satu pasangan bahasa.
class BahasaListScreen extends StatefulWidget {
  final String stringLang;

  const BahasaListScreen({super.key, required this.stringLang});

  @override
  State<BahasaListScreen> createState() => _BahasaListScreenState();
}

class _BahasaListScreenState extends State<BahasaListScreen> {
  final _api = BahasaApi();

  List<dynamic> _docs = [];
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
      final docs = await _api.list(lang: widget.stringLang);
      setState(() => _docs = docs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDokumen(Map<String, dynamic> d) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BahasaDetailScreen(id: d['id'] as int)),
    );
    _load();
  }

  Future<void> _tambah() async {
    final lang = widget.stringLang;
    final doc = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BahasaFormScreen(initialLang: lang),
      ),
    );
    if (doc != null) _load();
  }

  Future<void> _edit(Map<String, dynamic> d) async {
    Map<String, dynamic> dokumen;
    try {
      // item list tidak bawa `entries` → ambil detail penuh biar form tidak kosong
      dokumen = await _api.get(d['id'] as int);
    } catch (_) {
      dokumen = d;
    }
    if (!mounted) return;
    final doc = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BahasaFormScreen(dokumen: dokumen),
      ),
    );
    if (doc != null) _load();
  }

  Future<void> _hapus(Map<String, dynamic> d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Dokumen'),
        content: Text('Hapus "${d['judul']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _api.delete(d['id'] as int);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Dokumen dihapus'),
              backgroundColor: Colors.red,
            ),
          );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stringLang),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Tambah Dokumen',
              onPressed: _tambah,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _docs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Belum ada dokumen untuk pasangan ini',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _docs.length,
                    itemBuilder: (_, i) {
                      final d = _docs[i];
                      final judul = d['judul'] ?? 'Tanpa Judul';
                      final jumlah = d['jumlah_entri'] ?? 0;
                      final tgl = (d['updated_at'] ?? d['created_at'] ?? '')
                          .toString();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF00C87A)
                                .withValues(alpha: 0.15),
                            child: Text(
                              '$jumlah',
                              style: const TextStyle(
                                  color: Color(0xFF00C87A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                          title: Text(judul,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('$jumlah entri • $tgl',
                              style: const TextStyle(fontSize: 12)),
                          trailing: _isAdmin
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 20),
                                      tooltip: 'Ubah',
                                      onPressed: () => _edit(d),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red, size: 20),
                                      tooltip: 'Hapus',
                                      onPressed: () => _hapus(d),
                                    ),
                                  ],
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: () => _openDokumen(d),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../services/apis.dart';

class SitemapsScreen extends StatefulWidget {
  const SitemapsScreen({super.key});

  @override
  State<SitemapsScreen> createState() => _SitemapsScreenState();
}

class _SitemapsScreenState extends State<SitemapsScreen> {
  final _api = SitemapApi();

  List<dynamic> _sitemaps = [];
  Map<String, dynamic> _languages = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        _api.list(),
        _api.languages(),
      ]);
      setState(() {
        _sitemaps = r[0] as List<dynamic>;
        _languages = r[1] as Map<String, dynamic>;
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

  Future<void> _addSitemap() async {
    final urlCtrl = TextEditingController();
    String selectedLang = 'en';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tambah Sitemap'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  hintText: 'https://example.com/sitemap.xml',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedLang,
                decoration: const InputDecoration(
                  labelText: 'Bahasa',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'id', child: Text('🇮🇩 Indonesia')),
                  DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
                  DropdownMenuItem(value: 'ja', child: Text('🇯🇵 Japanese')),
                ],
                onChanged: (v) {
                  setDialogState(() => selectedLang = v!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {
                'url': urlCtrl.text.trim(),
                'language': selectedLang,
              }),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C87A)),
              child:
                  const Text('Tambah', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['url']!.isNotEmpty) {
      try {
        await _api.add(result['url']!, result['language']!);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Sitemap ditambahkan'),
              backgroundColor: Color(0xFF00C87A),
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

  Future<void> _deleteSitemap(int index, String domain) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Sitemap'),
        content: Text('Hapus sitemap dari "$domain"?'),
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
        await _api.delete(index);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Sitemap dihapus'),
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

  Future<void> _editLanguage(String domain, String currentLang) async {
    String newLang = currentLang;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Bahasa: $domain'),
          content: DropdownButtonFormField<String>(
            value: newLang,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'id', child: Text('🇮🇩 Indonesia')),
              DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
              DropdownMenuItem(value: 'ja', child: Text('🇯🇵 Japanese')),
            ],
            onChanged: (v) {
              setDialogState(() => newLang = v!);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, newLang),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C87A)),
              child:
                  const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != null && result != currentLang) {
      final newMapping = Map<String, dynamic>.from(_languages);
      newMapping[domain] = result;
      try {
        await _api.updateLanguages(newMapping);
        _load();
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
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // ─── Header ───────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.language,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                '${_sitemaps.length} Sitemaps',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addSitemap,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label:
                    const Text('Tambah', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C87A),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // ─── List ─────────────────────────────
        Expanded(
          child: _sitemaps.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rss_feed, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Belum ada sitemap',
                          style: TextStyle(color: Colors.grey)),
                      Text('Tekan + untuk menambahkan',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _sitemaps.length,
                    itemBuilder: (_, i) {
                      final s = _sitemaps[i];
                      final domain = s['domain'] ?? '';
                      final url = s['url'] ?? '';
                      final lang = s['language'] ?? 'en';
                      final langFlag = lang == 'id'
                          ? '🇮🇩'
                          : lang == 'ja'
                              ? '🇯🇵'
                              : '🇬🇧';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                const Color(0xFF00C87A).withValues(alpha: 0.15),
                            child: Text(
                              domain.isNotEmpty ? domain[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: Color(0xFF00C87A),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(domain,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(url,
                                  style: const TextStyle(fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => _editLanguage(domain, lang),
                                child: Text(
                                  '$langFlag $lang • Tap untuk ubah',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF00C87A)),
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                            onPressed: () => _deleteSitemap(i, domain),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

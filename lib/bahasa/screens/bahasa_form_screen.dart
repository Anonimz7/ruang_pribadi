import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/apis.dart';

/// Form admin: buat/ubah dokumen kamus bahasa.
/// `dokumen` != null → mode edit. `initialLang` → prefilled pasangan.
class BahasaFormScreen extends StatefulWidget {
  final Map<String, dynamic>? dokumen;
  final String? initialLang;

  const BahasaFormScreen({super.key, this.dokumen, this.initialLang});

  @override
  State<BahasaFormScreen> createState() => _BahasaFormScreenState();
}

/// Parse & validasi string JSON → list {a, b} atau null.
/// Dipakai untuk validasi client + panduan format.
List<Map<String, String>>? parseLangSource(String raw) {
  try {
    final data = jsonDecode(raw);
    if (data is! List || data.isEmpty) return null;
    final entries = <Map<String, String>>[];
    for (final item in data) {
      if (item is! Map) return null;
      final a = item['a'];
      final b = item['b'];
      if (a is! String || a.trim().isEmpty || b is! String || b.trim().isEmpty) {
        return null;
      }
      entries.add({'a': a.trim(), 'b': b.trim()});
    }
    return entries;
  } catch (_) {
    return null;
  }
}

class _BahasaFormScreenState extends State<BahasaFormScreen> {
  final _api = BahasaApi();
  final _langCtrl = TextEditingController();
  final _judulCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  List<dynamic> _pairs = [];
  String? _selectedLang;
  bool _langBaruMode = false;

  bool get _isEdit => widget.dokumen != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = widget.dokumen;
    if (d != null) {
      _selectedLang = d['string_lang'] as String?;
      _judulCtrl.text = d['judul'] ?? '';
      final entries = (d['entries'] as List?) ?? [];
      _sourceCtrl.text = const JsonEncoder.withIndent('  ')
          .convert(entries.isEmpty ? [] : entries);
    } else if (widget.initialLang != null) {
      _selectedLang = widget.initialLang;
    }
    try {
      final pairs = await _api.pairs();
      final langs = pairs.map((p) => p['string_lang'] as String).toList();
      setState(() {
        _pairs = pairs;
        _loading = false;
        // Pastikan lang terpilih (edit) selalu ada di dropdown.
        if (_selectedLang != null && !langs.contains(_selectedLang)) {
          _langBaruMode = true;
          _langCtrl.text = _selectedLang!;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
      setState(() => _loading = false);
    }
  }

  String get _finalLang {
    if (_langBaruMode) return _langCtrl.text.trim();
    return _selectedLang ?? '';
  }

  void _showPanduan() {
    const panduan = '''
Buatlah terjemahan teks Inggris ke Indonesia dalam format JSON array dengan objek {"a": "teks sumber", "b": "terjemahan"}.

Aturan wajib yang harus diikuti:

1. Format:
   - Contoh yang benar: {"a": "Higher energy prices", "b": "Kenaikan harga energi"}
   - "a" adalah teks sumber (Inggris).
   - "b" adalah terjemahan (Indonesia).

2. Aturan penggabungan kata/frasa:
   - Jika kata sifat (seperti "Higher") dan kata benda (seperti "energy prices") membentuk SATU konsep/frasa benda utuh yang menjadi subjek atau objek utama dalam kalimat, maka GABUNGKAN menjadi satu entri "a".
   - Contoh wajib:
     - "Higher energy prices" → SATU entri (bukan "Higher" dan "energy prices" terpisah)
     - "Higher interest rates" → SATU entri (bukan "Higher" dan "interest rates" terpisah)
   - Untuk frasa benda tetap lainnya seperti "central banks", "overall demand", "inflationary pressures" juga digabung menjadi satu entri karena merupakan satu kesatuan makna.

3. Aturan pemisahan:
   - Kata kerja, kata keterangan, kata sambung, dan kata depan dipisahkan per kata (misal: "directly", "cause", "on", "and", "by", "which").
   - Frasa "to rise", "to increase", "to control" → tetap digabung karena satu kesatuan makna (infinitif).

4. Kata kerja bantu (am, is, are):
   - Tidak diterjemahkan terpisah. Contoh: "I am" → {"a": "I am", "b": "saya"}.

5. Urutan array harus mengikuti urutan kemunculan kata/frasa dalam teks sumber secara persis.

6. Array tidak boleh kosong.

7. Tanda baca tidak dibuat entri JSON terpisah, melainkan menempel pada kata/frasa sebelumnya dalam satu entri yang sama. Contoh: "DeepSeek-V3," bukan "DeepSeek-V3" dan "," terpisah. Contoh lain: "stable." bukan "stable" dan "." terpisah
''';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Panduan Format'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: Scrollbar(
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  panduan,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Salin'),
                    onPressed: () {
                      Clipboard.setData(
                          const ClipboardData(text: panduan));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Panduan disalin')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final lang = _finalLang;
    final judul = _judulCtrl.text.trim();
    final src = _sourceCtrl.text.trim();

    if (lang.isEmpty) {
      _snack('Pasangan bahasa wajib diisi');
      return;
    }
    if (judul.isEmpty) {
      _snack('Judul wajib diisi');
      return;
    }
    final parsed = parseLangSource(src);
    if (parsed == null) {
      _snack('lang_source tidak valid — cek format JSON (lihat panduan ?)');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _api.update(
          id: widget.dokumen!['id'] as int,
          stringLang: lang,
          judul: judul,
          langSource: src,
        );
      } else {
        await _api.create(stringLang: lang, judul: judul, langSource: src);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah Dokumen' : 'Tambah Dokumen Bahasa'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Pasangan bahasa ──
                  if (!_langBaruMode)
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLang,
                      decoration: const InputDecoration(
                        labelText: 'Pasangan Bahasa',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final p in _pairs)
                          DropdownMenuItem(
                            value: p['string_lang'] as String,
                            child: Text(p['string_lang'] as String),
                          ),
                        const DropdownMenuItem(
                          value: '__baru__',
                          child: Text('➕ Ketik bahasa baru...'),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          if (v == '__baru__') {
                            _langBaruMode = true;
                          } else {
                            _selectedLang = v;
                          }
                        });
                      },
                    )
                  else
                    TextField(
                      controller: _langCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Pasangan Bahasa (baru)',
                        hintText: 'contoh: indonesia-jerman',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _judulCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Judul',
                      hintText: 'contoh: Artikel 1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Isi (lang_source)',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.help_outline, size: 20),
                        tooltip: 'Panduan format',
                        onPressed: _showPanduan,
                      ),
                    ],
                  ),
                  TextField(
                    controller: _sourceCtrl,
                    maxLines: 8,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      hintText:
                          '[{"a": "Higher", "b": "lebih tinggi"}, ...]',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save, color: Colors.white, size: 18),
                    label: Text(_saving ? 'Menyimpan...' : 'Simpan',
                        style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C87A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
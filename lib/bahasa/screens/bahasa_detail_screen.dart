import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/apis.dart';

/// Halaman fokus: isi dokumen dirender seperti paragraf mengalir (gaya
/// Vinculum). Kata-kata dipecah per baris terlebih dahulu, lalu tiap baris
/// dirender dalam 3 lapis agar garis pecahan selalu SEJAJAR & menerus:
///   baris 1 : semua kata sumber (a)
///   lapis 2 : satu garis penuh selebar baris ("tembus", tidak patah-patah)
///   baris 3 : semua terjemahan (b), masing-masing di bawah kata-nya
class BahasaDetailScreen extends StatefulWidget {
  final int id;

  const BahasaDetailScreen({super.key, required this.id});

  @override
  State<BahasaDetailScreen> createState() => _BahasaDetailScreenState();
}

class _BahasaDetailScreenState extends State<BahasaDetailScreen> {
  final _api = BahasaApi();

  Map<String, dynamic>? _doc;
  bool _loading = true;

  /// 0 = FULL (baris 3-lapis per kata), 1 = HOLD (tooltip),
  /// 2 = PARAGRAF (satu paragraf sumber / garis / satu paragraf terjemahan).
  int _mode = 0;

  static const _aStyle =
      TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2);
  static const _bStyle = TextStyle(
    fontSize: 11,
    color: Color(0xFF00C87A),
    fontStyle: FontStyle.italic,
    height: 1.2,
  );
  static const _gap = 10.0; // spasi antar kolom kata

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final doc = await _api.get(widget.id);
      setState(() => _doc = doc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _textWidth(String s, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  /// Lebar kolom satu pasangan = max(lebar a, lebar b) + spasi antar kata.
  double _termWidth(Map<String, dynamic> e) =>
      max(_textWidth('${e['a']}', _aStyle), _textWidth('${e['b']}', _bStyle)) +
      _gap;

  /// Pecah daftar entri jadi baris-baris paragraf (sampai maxWidth).
  List<List<Map<String, dynamic>>> _lines(
      List<dynamic> entries, double maxWidth) {
    final lines = <List<Map<String, dynamic>>>[];
    var cur = <Map<String, dynamic>>[];
    var w = 0.0;
    for (final e in entries) {
      final tw = _termWidth(e);
      if (cur.isNotEmpty && w + tw > maxWidth) {
        lines.add(cur);
        cur = [];
        w = 0;
      }
      cur.add(e);
      w += tw;
    }
    if (cur.isNotEmpty) lines.add(cur);
    return lines;
  }

  /// Warna teks kata sumber: 2 variasi selang-seling per entri
  /// (genap = warna teks biasa, ganjil = biru muda) supaya tiap entri beda.
  Color _entryColor(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (index.isEven) return isDark ? Colors.white : Colors.black87;
    return isDark ? Colors.lightBlue.shade200 : Colors.blue.shade600;
  }

  /// Satu baris paragraf: a's / garis menerus / b's.
  Widget _lineWidget(List<Map<String, dynamic>> terms, int startIndex) {    final widths = [for (final t in terms) _termWidth(t)];
    final lineColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white24
        : Colors.grey.shade400;

    Widget col(int i) => SizedBox(
          width: widths[i],
          child: Text(
            '${terms[i]['b']}',
            textAlign: TextAlign.center,
            maxLines: 1,
            style: _bStyle,
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < terms.length; i++)
              SizedBox(
                width: widths[i],
                child: Text(
                  '${terms[i]['a']}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: _aStyle.copyWith(color: _entryColor(startIndex + i)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        // ── Garis pecahan menerus selebar baris ("tembus") ──
        Container(height: 1, color: lineColor),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (var i = 0; i < terms.length; i++) col(i)],
        ),
      ],
    );
  }

  /// Mode HOLD: satu kata = hanya [a]. Tekan-tahan → popup kecil berisi [b]
  /// di sekitar kata (tanpa separator, tanpa gap cadangan).
  Widget _holdTerm(int index, Map<String, dynamic> e) {
    return Tooltip(
      message: '${e['b']}',
      triggerMode: TooltipTriggerMode.longPress,
      showDuration: const Duration(seconds: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00C87A),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child:
          Text('${e['a']}', style: _aStyle.copyWith(color: _entryColor(index))),
    );
  }

  /// Mode FULL: paragraf 3-lapis, semua baris lengkap dengan index kontinu
  /// supaya pewarnaan selang-seling tetap konsisten antar baris.
  Widget _fullContent(List<dynamic> entries, double maxWidth) {
    final lines = _lines(entries, maxWidth);
    final widgets = <Widget>[];
    var idx = 0;
    for (final line in lines) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _lineWidget(line, idx),
      ));
      idx += line.length;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Mode PARAGRAF: satu paragraf utuh bahasa asli / garis / satu paragraf
  /// utuh terjemahan. Kata sumber & terjemahan sama-sama diwarnai
  /// selang-seling per entri (putih–biru muda).
  Widget _paragraphContent(List<dynamic> entries) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = isDark ? Colors.white24 : Colors.grey.shade400;
    final sourceSpans = <TextSpan>[
      for (var i = 0; i < entries.length; i++)
        TextSpan(
          text: '${entries[i]['a']} ', // spasi antar kata
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.bold,
            color: _entryColor(i),
          ),
        ),
    ];
    final targetSpans = <TextSpan>[
      for (var i = 0; i < entries.length; i++)
        TextSpan(
          text: '${entries[i]['b']} ', // spasi antar kata
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            fontStyle: FontStyle.italic,
            color: _entryColor(i),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: sourceSpans),
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: lineColor),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(children: targetSpans),
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  Widget _modeSwitch() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(
          value: 0,
          label: Text('Full', style: TextStyle(fontSize: 11)),
          icon: Icon(Icons.view_agenda, size: 14),
        ),
        ButtonSegment(
          value: 1,
          label: Text('Hold', style: TextStyle(fontSize: 11)),
          icon: Icon(Icons.touch_app, size: 14),
        ),
        ButtonSegment(
          value: 2,
          label: Text('Paragraf', style: TextStyle(fontSize: 11)),
          icon: Icon(Icons.article_outlined, size: 14),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: (s) => setState(() => _mode = s.first),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final entries = ((doc?['entries']) as List?) ?? [];
    final maxWidth = MediaQuery.sizeOf(context).width - 32; // padding kiri+kanan

    return Scaffold(
      appBar: AppBar(title: Text(doc?['judul'] ?? 'Detail')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : doc == null
              ? const Center(child: Text('Dokumen tidak ditemukan'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Center(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '${doc['string_lang']} • ${doc['jumlah_entri']} entri',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 6),
                            _modeSwitch(),
                          ],
                        ),
                      ),
                    ),
                    if (_mode == 1)
                      SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                          child: Text(
                            'Tekan & tahan kata untuk melihat terjemahan (popup)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                      child: entries.isEmpty
                          ? const Center(
                              child: Text('Dokumen kosong',
                                  style: TextStyle(color: Colors.grey)),
                            )
                          : SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                  16,
                                  MediaQuery.sizeOf(context).height * 0.03,
                                  16,
                                  24),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                      maxWidth: MediaQuery.sizeOf(context)
                                              .width -
                                          32),
                                  child: _mode == 0
                                      ? _fullContent(entries, maxWidth)
                                      : _mode == 1
                                          ? Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              alignment: WrapAlignment.start,
                                              children: [
                                                for (var i = 0;
                                                    i < entries.length;
                                                    i++)
                                                  _holdTerm(
                                                      i, entries[i]
                                                          as Map<String, dynamic>),
                                              ],
                                            )
                                          : _paragraphContent(entries),
                                ),
                              ),
                    ),
                  ],
                ),
    );
  }
}
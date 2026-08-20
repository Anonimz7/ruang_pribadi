import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/plantuml_local_renderer.dart';

/// ═══════════════════════════════════════════════════════
/// CODE DIAGRAM — Tulis kode PlantUML → render lokal (SVG) → simpan SVG
/// ═══════════════════════════════════════════════════════
/// Editor monospace multi-line di atas, tombol Render di tengah.
/// Render via engine PlantUML JavaScript (TeaVM) di dalam WebView
/// tersembunyi → hasil SVG (offline, tanpa server/internet).
/// Simpan SVG: string hasil render ditulis lewat save dialog.
/// ═══════════════════════════════════════════════════════
class CodeDiagramScreen extends StatefulWidget {
  const CodeDiagramScreen({super.key});

  @override
  State<CodeDiagramScreen> createState() => _CodeDiagramScreenState();
}

class _CodeDiagramScreenState extends State<CodeDiagramScreen> {
  static const _initialSource = '''
@startuml
Alice -> Bob: Hello
Bob --> Alice: Hi!
@enduml
''';

  late final TextEditingController _controller =
      TextEditingController(text: _initialSource);
  final _renderer = PlantumlLocalRenderer();
  final _transformationController = TransformationController();
  final _previewKey = GlobalKey();

  String? _svg;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _transformationController.dispose();
    _renderer.dispose();
    super.dispose();
  }

  Future<void> _render() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _svg = null;
    });
    try {
      final svg = await _renderer.renderSvg(_controller.text);
      if (!mounted) return;
      setState(() => _svg = svg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Simpan string SVG (hasil render lokal) via save dialog.
  Future<void> _saveSvg() async {
    final svg = _svg;
    if (svg == null) {
      _showSnack('Belum ada hasil render.');
      return;
    }
    setState(() => _saving = true);
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Simpan Diagram SVG',
        fileName: 'diagram.svg',
        type: FileType.custom,
        allowedExtensions: ['svg'],
        bytes: utf8.encode(svg),
      );
      if (path == null) return; // dibatalkan user
      _showSnack('Tersimpan: $path');
    } catch (e) {
      _showSnack('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  /// Zoom in/out di sekitar tengah viewport preview.
  void _zoom(double factor) {
    final renderBox =
        _previewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final center = renderBox.size.center(Offset.zero);
    final t = _transformationController.value;
    final scale = t.getMaxScaleOnAxis();
    final newScale = (scale * factor).clamp(0.2, 4.0);
    final ratio = newScale / scale;
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(ratio, ratio, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1)
      ..multiply(t);
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap, String tooltip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 3,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_loading) {
      return const CircularProgressIndicator();
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
        ),
      );
    }
    if (_svg != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.2,
            maxScale: 4,
            constrained: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: size.width,
                minHeight: size.height,
              ),
              child: Center(
                child: SvgPicture.string(
                  _svg!,
                  placeholderBuilder: (_) => const CircularProgressIndicator(),
                ),
              ),
            ),
          );
        },
      );
    }
    return const Text(
      'Tekan Render untuk melihat hasil',
      style: TextStyle(color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Render Diagram'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ─── Editor + tombol aksi (scroll sendiri) ──
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12),
                  children: [
                    TextField(
                      controller: _controller,
                      minLines: 8,
                      maxLines: 14,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13),
                      decoration: const InputDecoration(
                        alignLabelWithHint: true,
                        labelText: 'Kode PlantUML',
                        hintText: '@startuml\n...\n@enduml',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ─── Tombol aksi ─────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _render,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Render'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _saveSvg,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_alt),
                            label: const Text('Simpan SVG'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Render lokal (offline, tanpa server).',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // ─── Preview: Expanded → sisa tinggi layar ──
              Expanded(
                child: Container(
                  key: _previewKey,
                  width: double.infinity,
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: _buildPreview(),
                ),
              ),
            ],
          ),

          // ─── WebView renderer tersembunyi (harus ada di tree) ──
          PlantumlWebView(renderer: _renderer),

          // ─── Kontrol zoom (hanya saat ada hasil) ──
          if (_svg != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _zoomButton(Icons.add, () => _zoom(1.25), 'Perbesar'),
                  _zoomButton(Icons.remove, () => _zoom(0.8), 'Perkecil'),
                  _zoomButton(Icons.restart_alt, _resetZoom, 'Reset'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

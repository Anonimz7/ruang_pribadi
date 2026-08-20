import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

/// ═══════════════════════════════════════════════════════
/// PLANTUML LOCAL RENDERER — render PlantUML via TeaVM JS (offline)
/// ═══════════════════════════════════════════════════════
/// Menjalankan engine PlantUML versi JavaScript (TeaVM) di dalam
/// WebView tersembunyi. Tidak butuh internet/server.
///
/// Kenapa server HTTP lokal?
///   `loadFlutterAsset` memuat via `file://` (origin null) → ES module
///   `import './plantuml.js'` diblokir CORS. `loadHtmlString` dengan
///   string ~8.5MB tidak andal. Maka asset JS disajikan lewat server
///   HTTP lokal (http://127.0.0.1) → origin http, ES module jalan normal.
///   (Butuh izin cleartext ke localhost di network_security_config.xml.)
///
/// Alur:
///   1. Server lokal menyajikan renderer.html + plantuml.js + viz-global.js.
///   2. [renderSvg] mengirim source (split jadi lines) ke
///      `window.renderPlantUML(...)` via JS.
///   3. Engine memanggil `renderToString` (async, worker thread TeaVM)
///      lalu hasil SVG dikirim balik lewat JS channel `PlantUMLBridge`.
///
/// Engine hanya di-init sekali (WebView persisten), bukan per-render.
/// ═══════════════════════════════════════════════════════
class PlantumlLocalRenderer {
  final WebViewController _controller = WebViewController();

  HttpServer? _server;
  _RenderRequest? _pending;
  bool _loaded = false;
  final List<_RenderRequest> _queue = [];

  PlantumlLocalRenderer() {
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('PlantUMLBridge', onMessageReceived: _onMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            debugPrint('[puml] page finished');
            _loaded = true;
            _drain();
          },
        ),
      );
    _init();
  }

  /// Controller WebView agar widget [PlantumlWebView] bisa menampilkannya.
  WebViewController get controller => _controller;

  Future<void> _init() async {
    try {
      await _startServer();
      final port = _server!.port;
      debugPrint('[puml] server on port $port');
      await _controller.loadRequest(Uri.parse('http://127.0.0.1:$port/renderer.html'));
      debugPrint('[puml] loadRequest done');
    } catch (e) {
      debugPrint('[puml] init error: $e');
      _loaded = true;
      _failAll(Exception('Gagal memuat engine PlantUML: $e'));
    }
  }

  Future<void> _startServer() async {
    final plantuml = await rootBundle.load('assets/plantuml/plantuml.js');
    final viz = await rootBundle.load('assets/plantuml/viz-global.js');
    final html = await rootBundle.loadString('assets/plantuml/renderer.html');

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((req) {
      final path = req.uri.path == '/' ? '/renderer.html' : req.uri.path;
      try {
        switch (path) {
          case '/renderer.html':
            req.response.headers.contentType = ContentType.html;
            req.response.write(html);
          case '/plantuml.js':
            req.response.headers.contentType =
                ContentType('application', 'javascript');
            req.response.add(plantuml.buffer.asUint8List());
          case '/viz-global.js':
            req.response.headers.contentType =
                ContentType('application', 'javascript');
            req.response.add(viz.buffer.asUint8List());
          default:
            req.response.statusCode = HttpStatus.notFound;
        }
      } catch (e) {
        debugPrint('[puml] serve error: $e');
      } finally {
        req.response.close();
      }
    });
  }

  /// Tutup server HTTP lokal (panggil saat screen di-dispose).
  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
  }

  void _failAll(Object error) {
    while (_queue.isNotEmpty) {
      _queue.removeAt(0).completer.completeError(error);
    }
  }

  void _onMessage(JavaScriptMessage message) {
    final data = jsonDecode(message.message) as Map<String, dynamic>;
    final req = _pending;
    _pending = null;
    debugPrint(
        '[puml] message ok=${data['ok']} svgLen=${(data['svg'] as String?)?.length} err=${data['err']}');
    if (req == null) return;
    if (data['ok'] == true) {
      req.completer.complete(data['svg'] as String);
    } else {
      req.completer.completeError(Exception(data['err']));
    }
    _drain();
  }

  /// Render source PlantUML menjadi string SVG (offline).
  Future<String> renderSvg(String source) {
    final lines = source.split(RegExp(r'\r\n|\r|\n'));
    final completer = Completer<String>();
    _queue.add(_RenderRequest(lines, completer));
    _drain();
    return completer.future;
  }

  void _drain() {
    if (_pending != null || !_loaded || _queue.isEmpty) return;
    final req = _queue.removeAt(0);
    _pending = req;
    final js = 'window.renderPlantUML(${jsonEncode(req.lines)})';
    debugPrint('[puml] runJS: $js');
    _controller.runJavaScript(js);
  }
}

class _RenderRequest {
  final List<String> lines;
  final Completer<String> completer;

  _RenderRequest(this.lines, this.completer);
}

/// Widget tersembunyi yang menampung WebView renderer.
/// Harus ada di dalam widget tree agar WebView aktif & JS bisa jalan.
class PlantumlWebView extends StatelessWidget {
  final PlantumlLocalRenderer renderer;

  const PlantumlWebView({super.key, required this.renderer});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0,
        child: SizedBox(
          width: 1,
          height: 1,
          child: WebViewWidget(controller: renderer.controller),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/download_model.dart';
import '../../services/apis.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import 'download_history_screen.dart';
import '../../settings/admin_cookies_screen.dart';
import '../../main.dart' show onDownloadStarted;

class VideoDownloaderScreen extends StatefulWidget {
  const VideoDownloaderScreen({super.key});

  @override
  State<VideoDownloaderScreen> createState() => _VideoDownloaderScreenState();
}

class _VideoDownloaderScreenState extends State<VideoDownloaderScreen> {
  final _urlCtrl = TextEditingController();
  final _videoApi = VideoApi();
  final _focusNode = FocusNode();

  VideoInfo? _videoInfo;
  bool _extracting = false;
  bool _downloading = false;
  double _progress = 0;
  String _downloadStatus = '';
  String? _error;
  String? _downloadSpeed;
  String? _downloadEta;

  Timer? _pollTimer;
  VideoFormat? _selectedFormat;
  bool _audioOnly = false;
  String? _downloadId;
  WebSocketChannel? _wsChannel;
  Timer? _activePollTimer;

  // Collapsible group states — keyed by resolution string
  final Map<String, bool> _groupExpanded = {};
  bool _audioExpanded = true;
  List<Map<String, dynamic>> _activeDownloads = [];

  // ── Poll active downloads every 10s so the card stays live ──
  void _startActiveDownloadsPolling() {
    _activePollTimer?.cancel();
    _activePollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkActiveDownloads(),
    );
  }

  @override
  void initState() {
    super.initState();
    _restorePersistedDownload();
    _checkActiveDownloads();
    _startActiveDownloadsPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _activePollTimer?.cancel();
    _wsChannel?.sink.close();
    _urlCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Cancel an active download ──────────────────────────
  Future<void> _cancelDownload(String downloadId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Download?'),
        content: const Text('File temp/fragment akan dibersihkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Ya, Batalkan', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _videoApi.cancelDownload(downloadId);
      // If this was the current download, reset state
      if (_downloadId == downloadId) {
        _clearDownloadState();
        _stopPolling();
        setState(() {
          _downloading = false;
          _downloadId = null;
          _downloadSpeed = null;
          _downloadEta = null;
          _downloadStatus = '';
        });
      }
      _checkActiveDownloads();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download dibatalkan'),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membatalkan: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ── Persist download state to SharedPreferences ─────────
  static const _persistKey = 'video_downloader_active';

  Future<void> _saveDownloadState(
      String downloadId, String url, String formatId, bool audioOnly) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _persistKey,
        jsonEncode({
          'download_id': downloadId,
          'url': url,
          'format_id': formatId,
          'audio_only': audioOnly,
          'started_at': DateTime.now().toIso8601String(),
        }));
  }

  Future<void> _clearDownloadState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_persistKey);
  }

  /// Restore download state on screen open — checks server for actual status.
  Future<void> _restorePersistedDownload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_persistKey);
      if (raw == null) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final downloadId = data['download_id'] as String?;
      if (downloadId == null) {
        await _clearDownloadState();
        return;
      }

      // Check with server what happened to this download
      final status = await _videoApi.downloadStatus(downloadId);
      final st = status['status'] as String? ?? 'not_found';

      if (!mounted) return;

      if (st == 'downloading' || st == 'interrupted') {
        // Download still running or was interrupted — resume tracking
        setState(() {
          _downloading = true;
          _downloadId = downloadId;
          _progress = (status['progress'] ?? 0).toDouble();
          _downloadStatus =
              st == 'interrupted' ? 'Menyambung ulang...' : 'Mengunduh...';
          _error = null;
        });
        _startStatusPolling(downloadId);
        _connectProgressWebSocket();
        // Notify main page to restart badge polling
        onDownloadStarted?.call();
      } else if (st == 'completed') {
        // Download finished while app was closed
        await _clearDownloadState();
        final fileName = status['file_name'] as String?;
        if (mounted) {
          setState(() {
            _downloading = false;
            _progress = 100;
            _downloadStatus = 'Selesai!';
          });
          _showSnackBar('Download selesai: $fileName', isError: false);
        }
      } else if (st == 'failed') {
        await _clearDownloadState();
        if (mounted) {
          setState(() {
            _downloading = false;
            _error = 'Download gagal: ${status['error'] ?? "Unknown error"}';
          });
        }
      } else {
        // not_found — cleaned up, remove persisted state
        await _clearDownloadState();
      }
    } catch (_) {
      // Network error — keep persisted state, will retry on next check
    }
  }

  // ── Check active downloads on screen open ──────────────
  Future<void> _checkActiveDownloads() async {
    try {
      final data = await _videoApi.activeDownloads();
      final items =
          data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) {
        setState(() => _activeDownloads = items);
        // Stop polling when no active downloads to save bandwidth
        if (items.isEmpty) {
          _activePollTimer?.cancel();
          _activePollTimer = null;
        }
      }
    } catch (_) {}
  }

  // ── WebSocket for real-time download progress ──────────
  void _connectProgressWebSocket() {
    _wsChannel?.sink.close();
    try {
      final baseUrl = ApiConfig.baseUrl.replaceFirst('http', 'ws');
      final userId = ApiClient().username;
      final wsUrl = '$baseUrl/ws/video-progress/$userId';
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _wsChannel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String);
            final status = msg['status'] as String?;
            final fn = msg['filename'] as String?;

            // Only update if it matches our current download
            if (_downloadId != null && fn != _downloadId) return;

            if (status == 'downloading' && mounted) {
              setState(() {
                _progress = (msg['progress'] ?? 0).toDouble();
                _downloadSpeed = msg['speed'] as String?;
                _downloadEta = msg['eta'] as String?;
                _downloadStatus =
                    'Mengunduh... ${_progress.toStringAsFixed(1)}%';
              });
            } else if (status == 'completed' && mounted) {
              _clearDownloadState();
              setState(() {
                _downloading = false;
                _progress = 100;
                _downloadStatus = 'Selesai!';
                _downloadId = null;
                _downloadSpeed = null;
                _downloadEta = null;
              });
              _stopPolling();
              _showSnackBar('Download selesai!', isError: false);
            } else if (status == 'error' && mounted) {
              _clearDownloadState();
              setState(() {
                _downloading = false;
                _error = 'Download gagal: ${msg["message"] ?? "Unknown"}';
                _downloadId = null;
                _downloadSpeed = null;
                _downloadEta = null;
              });
              _stopPolling();
              _checkActiveDownloads();
            } else if (status == 'cancelled' && mounted) {
              _clearDownloadState();
              setState(() {
                _downloading = false;
                _downloadStatus = 'Dibatalkan';
                _downloadId = null;
                _downloadSpeed = null;
                _downloadEta = null;
              });
              _stopPolling();
              _checkActiveDownloads();
            }
          } catch (_) {}
        },
        onDone: () {},
        onError: (_) {},
      );
    } catch (_) {}
  }

  // ── Extract ─────────────────────────────────────────────
  Future<void> _extract() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Masukkan URL video');
      return;
    }

    setState(() {
      _extracting = true;
      _error = null;
      _videoInfo = null;
      _selectedFormat = null;
    });

    try {
      final info = await _videoApi.extract(url);
      final vi =
          VideoInfo.fromJson((info['data'] ?? info) as Map<String, dynamic>);
      setState(() {
        _videoInfo = vi;
        _extracting = false;
        _groupExpanded.clear();

        // Group video formats by resolution
        final resGroups = _groupByResolution(vi.formats);

        // Find best format: prefer 1280p, then highest resolution
        VideoFormat? best;
        for (final entry in resGroups.entries) {
          if (entry.key == '1280p') {
            best = entry.value.first;
            break;
          }
        }
        best ??= resGroups.values.firstOrNull?.first;

        _selectedFormat = best;

        // Default expand the 1280p group, or highest resolution
        String expandKey = resGroups.keys.first;
        for (final key in resGroups.keys) {
          if (key == '1280p') {
            expandKey = key;
            break;
          }
        }
        _groupExpanded[expandKey] = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal: ${e.toString().replaceAll('Exception: ', '')}';
        _extracting = false;
      });
    }
  }

  // ── Download ────────────────────────────────────────────
  Future<void> _startDownload() async {
    if (_selectedFormat == null && !_audioOnly) return;
    final url = _urlCtrl.text.trim();
    final formatId =
        _audioOnly ? 'bestaudio' : (_selectedFormat?.formatId ?? 'best');

    setState(() {
      _downloading = true;
      _progress = 0;
      _downloadStatus = 'Memulai...';
      _downloadSpeed = null;
      _downloadEta = null;
      _error = null;
    });

    // Connect WebSocket for real-time progress
    _connectProgressWebSocket();

    try {
      final result = await _videoApi.download(url, formatId,
          audioOnly: _audioOnly, title: _videoInfo?.title);
      final data = (result['data'] ?? result) as Map<String, dynamic>;
      final downloadId = data['download_id'] as String?;

      if (downloadId != null) {
        // Save state to SharedPreferences so it survives app kill
        _downloadId = downloadId;
        await _saveDownloadState(downloadId, url, formatId, _audioOnly);
        // Start polling status endpoint as fallback
        _startStatusPolling(downloadId);
        // Restart active downloads polling since we now have one
        _startActiveDownloadsPolling();
        // Notify main page to restart badge polling
        onDownloadStarted?.call();
      }

      // The endpoint returns immediately now — the download runs in background.
      // Progress comes via WebSocket or polling.
    } catch (e) {
      _stopPolling();
      final errMsg =
          'Download gagal: ${e.toString().replaceAll('Exception: ', '')}';
      setState(() {
        _downloading = false;
        _error = errMsg;
        _downloadSpeed = null;
        _downloadEta = null;
        _downloadId = null;
      });
      await _clearDownloadState();
      _showSnackBar(errMsg, isError: true);
    }
  }

  // ── Poll download status by ID (fallback when WS fails) ──
  void _startStatusPolling(String downloadId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!_downloading || _downloadId == null) {
        _stopPolling();
        return;
      }
      try {
        final status = await _videoApi.downloadStatus(_downloadId!);
        final st = status['status'] as String? ?? 'not_found';
        final pct = (status['progress'] ?? 0).toDouble();
        final speed = status['speed'] as String?;
        final eta = status['eta'] as String?;

        if (!mounted) return;

        if (st == 'downloading' || st == 'interrupted') {
          setState(() {
            _progress = pct;
            _downloadSpeed = speed;
            _downloadEta = eta;
            _downloadStatus = 'Mengunduh... ${pct.toStringAsFixed(1)}%';
          });
        } else if (st == 'completed') {
          _stopPolling();
          await _clearDownloadState();
          final fileName = status['file_name'] as String?;
          setState(() {
            _downloading = false;
            _progress = 100;
            _downloadStatus = 'Selesai!';
            _downloadId = null;
            _downloadSpeed = null;
            _downloadEta = null;
          });
          _showSnackBar('Download selesai: $fileName', isError: false);
        } else if (st == 'failed') {
          _stopPolling();
          await _clearDownloadState();
          setState(() {
            _downloading = false;
            _error = 'Download gagal: ${status["error"] ?? "Unknown error"}';
            _downloadId = null;
            _downloadSpeed = null;
            _downloadEta = null;
          });
        }
      } catch (_) {}
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────
  String _formatDuration(int? seconds) {
    if (seconds == null) return '';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _urlCtrl.text = data!.text!;
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Downloader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cookie),
            tooltip: 'Kelola Cookies',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminCookiesScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat Download',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DownloadHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── URL Input ──
          _buildUrlInput(),
          const SizedBox(height: 16),

          // ── Active downloads (persistent card, replaces SnackBar) ──
          if (_activeDownloads.isNotEmpty) ...[
            _buildActiveDownloadsCard(),
            const SizedBox(height: 12),
          ],

          // ── Error ──
          if (_error != null) _buildError(),
          if (_error != null) const SizedBox(height: 12),

          // ── Extracting ──
          if (_extracting) _buildExtracting(),

          // ── Video Info ──
          if (_videoInfo != null && !_extracting) ...[
            _buildVideoCard(),
            const SizedBox(height: 16),
            _buildFormatSelector(),
            const SizedBox(height: 16),
          ],

          // ── Download Progress ──
          if (_downloading) ...[
            _buildProgressSection(),
            const SizedBox(height: 16),
          ],

          // ── Download Button ──
          if (_videoInfo != null && !_extracting && !_downloading)
            _buildDownloadButton(),
        ],
      ),
    );
  }

  Widget _buildUrlInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _urlCtrl,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: 'Paste URL video di sini...',
              prefixIcon: const Icon(Icons.link),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _extract(),
          ),
        ),
        const SizedBox(width: 8),
        // Paste button
        IconButton.filled(
          onPressed: _pasteFromClipboard,
          icon: const Icon(Icons.paste, size: 20),
          tooltip: 'Paste dari clipboard',
        ),
        const SizedBox(width: 8),
        // Extract button
        FilledButton(
          onPressed: _extracting ? null : _extract,
          child: _extracting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Extract'),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtracting() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Menganalisis video...', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard() {
    final info = _videoInfo!;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with duration badge
          if (info.thumbnail != null)
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Image.network(
                  info.thumbnail!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child:
                        const Center(child: Icon(Icons.broken_image, size: 48)),
                  ),
                ),
                if (info.duration != null)
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDuration(info.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),

          // Video info
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (info.uploader != null) ...[
                      Icon(Icons.person_outline,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          info.uploader!,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${info.formats.length} format',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Group video formats by resolution. Returns ordered map (highest first).
  Map<String, List<VideoFormat>> _groupByResolution(List<VideoFormat> formats) {
    final Map<String, List<VideoFormat>> groups = {};
    for (final f in formats) {
      if (f.isAudioOnly) continue;
      final res = f.resolution ?? '';
      if (res == 'audio only' || res.isEmpty) continue;

      // Extract width from "WIDTHxHEIGHT" format (e.g. "1920x1080" → "1920p")
      String? key;
      final whMatch =
          RegExp(r'^\s*(\d{2,5})\s*x\s*(\d{2,5})\s*$').firstMatch(res);
      if (whMatch != null) {
        key = '${whMatch.group(1)}p';
      } else {
        // Fallback: try formatNote like "1080p"
        final noteMatch = RegExp(r'(\d{3,4})p').firstMatch(f.formatNote ?? '');
        if (noteMatch != null) {
          key = '${noteMatch.group(1)}p';
        }
      }
      key ??= 'Lainnya';
      groups.putIfAbsent(key, () => []).add(f);
    }
    // Sort each group: combined (video+audio) first, then video-only
    for (final key in groups.keys) {
      groups[key]!.sort((a, b) {
        if (a.hasBothCodecs && !b.hasBothCodecs) return -1;
        if (!a.hasBothCodecs && b.hasBothCodecs) return 1;
        return 0;
      });
    }
    // Sort groups by width number descending
    final sorted = Map<String, List<VideoFormat>>.fromEntries(
      groups.entries.toList()
        ..sort((a, b) {
          final aNum =
              int.tryParse(a.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          final bNum =
              int.tryParse(b.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          return bNum.compareTo(aNum);
        }),
    );
    return sorted;
  }

  Widget _buildFormatSelector() {
    final formats = _videoInfo!.formats;
    final audioFormats = formats.where((f) => f.isAudioOnly).toList();
    final resGroups = _groupByResolution(formats);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Audio-only toggle
        SwitchListTile(
          title: const Text('🎵 Audio Saja'),
          subtitle: const Text('Download hanya audio'),
          value: _audioOnly,
          onChanged: (v) => setState(() {
            _audioOnly = v;
            _selectedFormat = null;
          }),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),

        // ── Audio-only formats ──
        if (_audioOnly && audioFormats.isNotEmpty)
          _buildCollapsibleGroup(
            title: 'Audio Formats',
            count: audioFormats.length,
            expanded: _audioExpanded,
            onToggle: () => setState(() => _audioExpanded = !_audioExpanded),
            children: audioFormats.map((f) => _buildFormatTile(f)).toList(),
          ),

        // ── Video formats grouped by resolution ──
        if (!_audioOnly) ...[
          for (final entry in resGroups.entries)
            _buildCollapsibleGroup(
              title: entry.key,
              count: entry.value.length,
              expanded: _groupExpanded[entry.key] ?? false,
              onToggle: () => setState(() {
                _groupExpanded[entry.key] =
                    !(_groupExpanded[entry.key] ?? false);
              }),
              children: _buildFormatTilesWithSeparator(entry.value),
            ),
          if (resGroups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Tidak ada format video tersedia',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildCollapsibleGroup({
    required String title,
    required int count,
    required bool expanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.arrow_drop_down,
                      size: 22,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(children: children),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFormatTilesWithSeparator(List<VideoFormat> formats) {
    final widgets = <Widget>[];
    bool? lastWasCombined;
    for (final f in formats) {
      final isCombined = f.hasBothCodecs;
      // Add separator when transitioning from combined to video-only
      if (lastWasCombined == true && !isCombined) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                  child: Divider(color: Colors.grey.shade300, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Video Only (auto-merge)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
              Expanded(
                  child: Divider(color: Colors.grey.shade300, thickness: 1)),
            ],
          ),
        ));
      }
      widgets.add(_buildFormatTile(f));
      lastWasCombined = isCombined;
    }
    return widgets;
  }

  Widget _buildFormatTile(VideoFormat f) {
    final isSelected = _selectedFormat?.formatId == f.formatId;
    return RadioListTile<VideoFormat>(
      value: f,
      groupValue: _selectedFormat,
      onChanged: (v) => setState(() => _selectedFormat = v),
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Row(
        children: [
          // Resolution
          Text(
            f.label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          // Codec badges
          if (f.vcodecLabel.isNotEmpty)
            _buildCodecBadge(f.vcodecLabel, Colors.blue.shade700),
          if (f.acodecLabel.isNotEmpty) ...[
            const SizedBox(width: 4),
            _buildCodecBadge(f.acodecLabel, Colors.teal.shade700),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          Text(
            f.fileSizeKb,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (f.formatNote != null && f.formatNote!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              f.formatNote!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
          if (f.abr != null && f.abr! > 0) ...[
            const SizedBox(width: 8),
            Text(
              '${f.abr!.toStringAsFixed(0)} kbps',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCodecBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final isComplete = _progress >= 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isComplete ? Icons.check_circle : Icons.downloading,
                  color: isComplete ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isComplete ? 'Selesai!' : 'Mengunduh...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('${_progress.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _progress / 100,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            // Speed and ETA row
            Row(
              children: [
                Text(
                  _downloadStatus,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                if (_downloadSpeed != null)
                  Text(
                    _downloadSpeed!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade600,
                    ),
                  ),
                if (_downloadSpeed != null && _downloadEta != null)
                  Text(
                    ' · ',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                if (_downloadEta != null)
                  Text(
                    'Sisa ${_downloadEta!}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton() {
    final isVideoOnly = _selectedFormat?.isVideoOnly ?? false;
    final label = _audioOnly
        ? 'Download Audio'
        : isVideoOnly
            ? 'Download Video + Audio (Merge)'
            : 'Download Video';
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: _startDownload,
        icon: const Icon(Icons.download),
        label: Text(label),
      ),
    );
  }

  // ── Persistent Active Downloads Card ──────────────────────
  Widget _buildActiveDownloadsCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _activeDownloads.length == 1
                        ? '1 download sedang berjalan'
                        : '${_activeDownloads.length} download sedang berjalan',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DownloadHistoryScreen()),
                    );
                  },
                  child: const Text('Lihat Riwayat'),
                ),
              ],
            ),
            for (final dl in _activeDownloads) ...[
              const Divider(height: 16),
              _buildActiveDownloadItem(dl),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDownloadItem(Map<String, dynamic> dl) {
    final fn = dl['filename'] as String? ?? '...';
    final pct = (dl['progress'] ?? 0).toDouble();
    final speed = dl['speed'] as String?;
    final eta = dl['eta'] as String?;
    final status = dl['status'] as String? ?? 'downloading';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              status == 'interrupted' ? Icons.sync : Icons.downloading,
              size: 16,
              color: status == 'interrupted' ? Colors.orange : Colors.blue,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                fn,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: const Icon(Icons.cancel, color: Colors.redAccent),
                tooltip: 'Batalkan',
                onPressed: () => _cancelDownload(fn),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: pct / 100,
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
        if (speed != null || eta != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              if (speed != null)
                Text(speed,
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              if (speed != null && eta != null)
                Text(' · ',
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              if (eta != null)
                Text('Sisa $eta',
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ],
    );
  }
}

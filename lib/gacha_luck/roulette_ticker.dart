import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════
/// ROULETTE TICKER - Efek suara & visual jarum
/// ═══════════════════════════════════════════════════════
/// Menghasilkan suara "tik" saat jarum melewati paku
/// dan memberi impuls getaran pada jarum
/// ═══════════════════════════════════════════════════════

class RouletteTicker {
  static final RouletteTicker _instance = RouletteTicker._internal();
  factory RouletteTicker() => _instance;

  RouletteTicker._internal();

  // Kumpulan pemutar audio yang sudah dimuat dengan bunyi tick, agar bisa
  // diputar cepat & tumpang-tindih tanpa menunggu setSource tiap hantaman.
  AudioPool? _pool;

  /// Durasi bunyi tick (di-cache setelah query pertama) untuk mengembalikan
  /// pemutar ke pool setelah selesai berbunyi.
  Duration? _tickDuration;

  /// Sudahkah pool tick berhasil dibuat. `loadAudio` set true setelah
  /// `AudioPool.createFromAsset` resolve, false bila gagal. Mencegah
  /// `_playTick` dipanggil sebelum sumber siap.
  bool _sourceLoaded = false;

  /// Pemutar siap diputar bila pool belum disposed & sumber sudah termuat.
  bool get isAudioReady => _pool != null && _sourceLoaded;

  /// Jumlah paku di sekitar roda — diisi dari screen pemakai
  /// (harus = jumlah sektor, karena 1 paku per garis batas)
  int pegCount = 40;

  /// Sudut antar paku dalam derajat
  double get pegAngle => 360 / pegCount;

  /// Posisi paku terakhir yang dilewati (untuk deteksi edge)
  int _lastPegIndex = -1;

  /// Stream controller untuk notify getaran jarum
  final _tickController = StreamController<double>.broadcast();
  Stream<double> get tickStream => _tickController.stream;

  /// Siapkan pool bunyi tick (panggil sekali saat init)
  Future<void> loadAudio() async {
    try {
      // Bikin ulang pool kalau pernah di-dispose (pengaman singleton)
      _pool ??= await AudioPool.createFromAsset(
        path: 'sounds/tick.wav',
        minPlayers: 4,
        maxPlayers: 16,
        playerMode: PlayerMode.lowLatency,
      );
      _sourceLoaded = true; // pool siap, tick boleh dimainkan
    } catch (e) {
      _sourceLoaded = false;
      debugPrint('RouletteTicker: Failed to init audio - $e');
    }
  }

  /// Play bunyi 'tik' — pakai pemutar dari pool yang sudah dimuat, sehingga
  /// bisa diputar beruntun dengan cepat & sinkron dgn hantaman tanpa menunggu
  /// setSource/seek. Pemutar dikembalikan ke pool setelah bunyi selesai.
  Future<void> _playTick() async {
    // Jangan mainkan bila belum siap/pool belum dibuat.
    if (!isAudioReady) return;
    try {
      final stop = await _pool!.start();
      _tickDuration ??= await _pool!.getDuration();
      final d = _tickDuration ?? const Duration(milliseconds: 50);
      Future.delayed(d, stop); // kembalikan pemutar ke pool setelah bunyi
    } catch (e) {
      debugPrint('RouletteTicker: tick play error - $e');
    }
  }

  /// Reset state saat spin baru dimulai
  void reset() {
    _lastPegIndex = -1;
  }

  /// Cek apakah ada paku yang dilewati berdasarkan sudut saat ini
  /// [currentAngle] dalam derajat, [angularVelocity] dalam derajat/detik
  void update(double currentAngle, double angularVelocity) {
    if (angularVelocity < 10) return; // Abaikan jika sangat lambat

    // Normalisasi sudut ke [0, 360)
    final normalizedAngle = ((currentAngle % 360) + 360) % 360;

    // Jarum statis di jam 12 (270°); hitung sambaran relatif ke posisi
    // jarum agar 'tik' & dorongan jarum terjadi pas paku menyentuh jarum.
    const needleAngle = 270.0;
    final passed = (((needleAngle - normalizedAngle) % 360) + 360) % 360;
    final currentPegIndex = (passed / pegAngle).floor() % pegCount;

    // Deteksi perubahan paku (edge detection)
    if (currentPegIndex != _lastPegIndex && _lastPegIndex >= 0) {
      // Trigger tick
      _tickController.add(angularVelocity / 100); // Normalize untuk visual
      _playTick();
    }

    _lastPegIndex = currentPegIndex;
  }

  void dispose() {
    _tickController.close();
    _pool?.dispose();
  }
}
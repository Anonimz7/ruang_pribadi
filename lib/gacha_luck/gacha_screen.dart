import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'roulette_ticker.dart';

/// ═══════════════════════════════════════════════════════
/// GACHA KEBERUNTUNGAN — Meja Rollet
/// ═══════════════════════════════════════════════════════
/// 5 tingkat keberuntungan: sangat sial → sangat beruntung.
/// Probabilitas & pesan diatur di variabel bawah.
/// 1 keberuntungan bisa punya banyak pesan (dipilih acak).
/// ═══════════════════════════════════════════════════════

/// Tingkat keberuntungan
enum LuckTier {
  veryUnlucky('Sangat Sial', Icons.sentiment_very_dissatisfied, Color(0xFF8B0000)),
  unlucky('Sial', Icons.sentiment_dissatisfied, Color(0xFFE67E22)),
  normal('Normal', Icons.sentiment_neutral, Color(0xFF7F8C8D)),
  lucky('Beruntung', Icons.sentiment_satisfied, Color(0xFF2ECC71)),
  veryLucky('Sangat Beruntung', Icons.sentiment_very_satisfied, Color(0xFFF1C40F));

  final String label;
  final IconData icon;
  final Color color;
  const LuckTier(this.label, this.icon, this.color);
}

/// Probabilitas tiap tingkat (harus total = 100)
const Map<LuckTier, int> gachaProbabilities = {
  LuckTier.veryUnlucky: 5,
  LuckTier.unlucky: 25,
  LuckTier.normal: 40,
  LuckTier.lucky: 25,
  LuckTier.veryLucky: 5,
};

/// Kumpulan pesan per tingkat — 1 tingkat bisa punya banyak pesan
const Map<LuckTier, List<String>> gachaMessages = {
  LuckTier.veryUnlucky: [
    'Hati-hati! Hari ini bukan harimu. Jangan ambil keputusan besar.',
    '⚠️ Hati-hati! Keberuntungan sedang menjauh darimu.',
    'Hati-hati: benda tajam & jalan licin sedang menunggumu.',
  ],
  LuckTier.unlucky: [
    'Hari ini agak kurang beruntung, tapi masih bisa diperbaiki.',
    'Sial ringan. Mungkin jangan beli lotre hari ini.',
    'Ada hal kecil yang tidak berjalan mulus. Tetap tenang.',
  ],
  LuckTier.normal: [
    'Hari biasa, keberuntungan biasa. Standar saja.',
    'Tidak ada yang istimewa, tidak ada yang buruk.',
    'Normal saja. Cocok untuk rutinitas harianmu.',
  ],
  LuckTier.lucky: [
    'Hari ini hoki! Manfaatkan momentum untuk hal penting.',
    'Keberuntungan sedang berpihak padamu. Ayo gas!',
    'Beruntung! Coba saja hal baru, kemungkinan besar berhasil.',
  ],
  LuckTier.veryLucky: [
    '🌟 JACKPOT! Hari ini hari paling beruntungmu!',
    'Sangat beruntung! Coba lotre, mungkin kamu menang besar!',
    'Keberuntungan besar menghampirimu. Jangan sia-siakan!',
  ],
};

class GachaLuckScreen extends StatefulWidget {
  const GachaLuckScreen({super.key});

  @override
  State<GachaLuckScreen> createState() => _GachaLuckScreenState();
}

class _GachaLuckScreenState extends State<GachaLuckScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _rng = Random();
  final _ticker = RouletteTicker();

  LuckTier? _result;
  String? _message;
  bool _spinning = false;

  /// Posisi roda sebelum putaran ini + sudut putaran berjalan
  double _baseRotation = 0;
  double _spinAngle = 0;
  
  // Simulasi fisika jarum: sudut (rad) & kecepatan sudut (rad/s).
  // Roda berputar searah jarum jam (kanan). Di Flutter rotasi positif = CW,
  // sehingga ujung jarum (di bawah pivot) bergerak ke KIRI saat sudut positif.
  // Karena paku mendorong jarum ke KANAN, impulsnya dibuat negatif.
  static const double _kStiffness = 120; // rad/s² per rad
  static const double _kDamping = 8; // per detik
  static const double _kMinKick = 2.2; // rad/s — dorongan dasar tiap hantaman
  static const double _kSpeedKick = 0.35; // rad/s tambahan dari kecepatan putar
  static const double _kMaxAmplitude = 0.6; // rad (~34°)
  double _needleAngle = 0;
  double _needleOmega = 0;
  Duration _lastElapsed = Duration.zero;
  StreamSubscription<double>? _tickSubscription;

  @override
  void initState() {
    super.initState();
    _ticker.loadAudio();
    _ticker.pegCount = LuckTier.values.length; // 1 paku per garis batas sektor
    _controller = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // Baca hasil dari posisi akhir roda (di mana pun ia berhenti)
          final finalAngle = _baseRotation + _spinAngle;
          setState(() {
            _spinning = false;
            _result = _resultFromAngle(finalAngle);
            _message = _randomMessage(_result!);
            _needleAngle = 0;
            _needleOmega = 0;
          });
          _tickSubscription?.cancel();
        } else if (status == AnimationStatus.forward) {
          // Start listening to ticks when animation starts
          _ticker.reset();
          _tickSubscription?.cancel();
          _tickSubscription = _ticker.tickStream.listen((intensity) {
            // Dorongan paku: ada nilai dasar + tonjolan dari kecepatan,
            // supaya defleksi tetap terlihat walau roda sudah melambat.
            _needleOmega -= (_kMinKick + intensity * _kSpeedKick);
            // Trigger haptic feedback jika tersedia
            HapticFeedback.lightImpact();
          });
        }
      })
      ..addListener(() {
        // Update ticker untuk deteksi paku
        final currentAngle = _baseRotation + _controller.value * _spinAngle;
        final angularVelocity = _controller.velocity * _spinAngle;
        _ticker.update(currentAngle, angularVelocity.abs());
        
        // Integrasi osilator pegas teredam dengan delta waktu nyata
        // (dt tetap 1/60 di layar refresh tinggi membuat fisik 2x lebih cepat)
        final now = _controller.lastElapsedDuration ?? Duration.zero;
        final dt = (now - _lastElapsed).inMicroseconds / 1e6;
        _lastElapsed = now;
        if (dt <= 0 || dt > 0.1) return; // lewati lompatan waktu (restart)

        final accel = -_kStiffness * _needleAngle - _kDamping * _needleOmega;
        setState(() {
          _needleOmega += accel * dt;
          _needleAngle = (_needleAngle + _needleOmega * dt)
              .clamp(-_kMaxAmplitude, _kMaxAmplitude);
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _tickSubscription?.cancel();
    // NOTE: ticker adalah singleton bersama — jangan di-dispose di sini,
    // karena akan mematikan player audio & stream tick untuk semua screen.
    super.dispose();
  }

  /// Baca hasil dari posisi akhir roda (di mana pun ia berhenti)
  /// Jarum statis ada di posisi jam 12 (270° dalam sistem koordinat Canvas)
  /// Sektor 0 dimulai dari sudut 0° (jam 3) dan berputar CW
  /// Ketika roda berputar sebesar angleDeg CW, sektor yang berada di bawah jarum
  /// dapat dihitung dengan mencari sektor mana yang mencakup sudut 270° setelah rotasi
  LuckTier _resultFromAngle(double angleDeg) {
    final n = LuckTier.values.length;
    final sectorAngle = 360 / n;
    // Normalisasi sudut ke [0, 360)
    final normalized = ((angleDeg % 360) + 360) % 360;
    // Setelah roda berputar `normalized` derajat CW, 
    // titik yang awalnya di sudut `theta` sekarang ada di `theta + normalized`
    // Kita ingin tahu sektor mana yang sekarang berada di posisi 270° (jam 12)
    // Sektor i mencakup sudut [i*sectorAngle, (i+1)*sectorAngle) sebelum rotasi
    // Setelah rotasi, sektor i mencakup [(i*sectorAngle - normalized), ...)
    // Untuk menemukan sektor di posisi 270°, kita hitung:
    // sectorIndex = floor((270 - normalized) / sectorAngle) mod n
    var sectorIndex = (((270 - normalized) % 360 + 360) % 360 / sectorAngle).floor() % n;
    return LuckTier.values[sectorIndex];
  }

  /// Pilih tingkat — random murni berbasis timestamp
  LuckTier _roll() {
    final rng = Random(DateTime.now().microsecondsSinceEpoch);
    final r = rng.nextInt(100);
    var acc = 0;
    for (final tier in LuckTier.values) {
      acc += gachaProbabilities[tier]!;
      if (r < acc) return tier;
    }
    return LuckTier.normal;
  }

  String _randomMessage(LuckTier tier) {
    final messages = gachaMessages[tier]!;
    return messages[_rng.nextInt(messages.length)];
  }

  void _spin() {
    if (_spinning) return;
    final tier = _roll();

    // Sudut tengah tiap sektor (diukur searah jarum jam dari jam 3)
    final index = LuckTier.values.indexOf(tier);
    final sectorAngle = 360 / LuckTier.values.length;
    final tierCenter = sectorAngle * index + sectorAngle / 2;
    final jitter = _rng.nextDouble() * sectorAngle * 0.6 - sectorAngle * 0.3;

    // Sektor target berhenti di bawah jarum statis (posisi jam 12 = 270°)
    // Kurangi _baseRotation agar benar untuk putaran ke-2 dst.
    var target = 270 - tierCenter - _baseRotation + jitter;
    target = ((target % 360) + 360) % 360;

    // Durasi acak 10–30 detik
    final T = 10 + _rng.nextDouble() * 20;

    // Kecepatan awal acak 95–100 (max = 100) → ×8 = 760–800 °/s ≈ 2 putaran/detik
    const maxSpeed = 100;
    const speedScale = 8; // 1 satuan = 8 °/s
    final v0 = maxSpeed * (0.95 + _rng.nextDouble() * 0.05) * speedScale;

    // Total sudut = N putaran penuh + offset target, konsisten dgn v0·T/2
    final rotations = ((v0 * T / 2) / 360).floor();
    final totalAngle = rotations * 360 + target;
    final v0Final = 2 * totalAngle / T; // kecepatan efektif agar berhenti tepat

    setState(() {
      _spinning = true;
      _result = null;
      _message = null;
      _baseRotation = _baseRotation + _spinAngle;
      _spinAngle = totalAngle;
      // Reset sisa ayunan dari putaran sebelumnya
      _needleAngle = 0;
      _needleOmega = 0;
      _lastElapsed = Duration.zero;
    });

    _controller.value = 0;
    _controller.duration = Duration(milliseconds: (T * 1000).round());
    _controller.animateWith(
        _DecelerationSimulation(v0: v0Final, totalAngle: totalAngle, T: T));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Putar roda untuk melihat keberuntunganmu hari ini!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // ─── Meja Rollet ─────────────────────
              SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Roda berputar dengan paku-paku
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: (_baseRotation +
                                  _controller.value * _spinAngle) *
                              pi / 180,
                          child: child,
                        );
                      },
                      child: CustomPaint(
                        size: const Size(280, 280),
                        painter: _RoulettePainterWithPegs(),
                      ),
                    ),
                    // Jarum statis di atas roda (dengan efek getaran)
                    Positioned(
                      top: 2,
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _needleAngle,
                              // Pivot di atas (titik tumpu), ujung runcing yang berayun
                              alignment: Alignment.topCenter,
                              child: child,
                            );
                          },
                          child: CustomPaint(
                            size: const Size(26, 56),
                            painter: _NeedlePainter(
                                color: _result?.color ?? Colors.red),
                          ),
                        ),
                      ),
                    ),
                    // Tombol tengah
                    GestureDetector(
                      onTap: _spin,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00C87A), Color(0xFF00995E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.casino,
                                color: Colors.white, size: 22),
                            SizedBox(height: 2),
                            Text('GO!',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Hasil ───────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _result == null
                    ? const SizedBox(
                        height: 100,
                        child: Center(
                            child: Text('Tekan GO untuk memutar roda',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13))),
                      )
                    : _ResultCard(
                        key: ValueKey(_result),
                        tier: _result!,
                        message: _message!,
                      ),
              ),
              const SizedBox(height: 20),

              // ─── Legenda probabilitas ────────────
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: LuckTier.values.map((tier) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: tier.color,
                      child: Icon(tier.icon,
                          size: 14, color: Colors.white),
                    ),
                    label: Text('${tier.label} ${gachaProbabilities[tier]}%'),
                    labelStyle: const TextStyle(fontSize: 11),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final LuckTier tier;
  final String message;
  const _ResultCard({super.key, required this.tier, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = tier == LuckTier.veryUnlucky;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tier.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(tier.icon, size: 40, color: tier.color),
          const SizedBox(height: 6),
          Text(tier.label,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: tier.color)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: danger
                      ? Colors.red
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: danger ? FontWeight.bold : null)),
          const SizedBox(height: 8),
          Text('Probabilitas: ${gachaProbabilities[tier]}%',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

/// Painter roda rollet dengan paku-paku di sekelilingnya
class _RoulettePainterWithPegs extends CustomPainter {
  const _RoulettePainterWithPegs();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final n = LuckTier.values.length;
    final sweep = 360 / n;

    // Background
    canvas.drawCircle(center, radius, Paint()..color = Colors.black26);

    // Sektor
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < n; i++) {
      paint.color = LuckTier.values[i].color;
      canvas.drawArc(rect, i * sweep * pi / 180, sweep * pi / 180, true, paint);
    }

    // Garis antar sektor
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    for (var i = 0; i < n; i++) {
      final angle = i * sweep * pi / 180;
      canvas.drawLine(
          center,
          center + Offset(cos(angle), sin(angle)) * radius,
          line);
    }

    // Paku di garis batas sektor (1 paku per garis), agak ke tengah:
    // 0.78 radius ≈ 70% panjang jarum dari pivot atas, selaras dgn jarum
    final pegCount = n;
    final pegAngle = 360 / pegCount;
    final pegRadius = radius * 0.78;
    
    for (var i = 0; i < pegCount; i++) {
      final angle = i * pegAngle * pi / 180;
      final pegCenter = center + Offset(cos(angle), sin(angle)) * pegRadius;
      
      // Gambar paku sebagai lingkaran kecil dengan efek 3D
      final pegPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF8a8a8a),
            const Color(0xFF4a4a4a),
            const Color(0xFF2a2a2a),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: pegCenter, radius: 6));
      
      canvas.drawCircle(pegCenter, 5, pegPaint);
      
      // Highlight untuk efek metalik
      final highlight = Paint()..color = Colors.white.withValues(alpha: 0.6);
      canvas.drawCircle(
        pegCenter + const Offset(-1.5, -1.5),
        2,
        highlight,
      );
    }

    // Bingkai luar
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = Colors.white);

  }

  @override
  bool shouldRepaint(covariant _RoulettePainterWithPegs old) => false;
}

/// Jarum penunjuk statis — segitiga runcing ke bawah + pivot
class _NeedlePainter extends CustomPainter {
  final Color color;
  const _NeedlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Badan jarum (segitiga runcing ke bawah) + bayangan
    final body = Path()
      ..moveTo(w * 0.5, h)
      ..lineTo(w * 0.06, 0)
      ..lineTo(w * 0.94, 0)
      ..close();
    canvas.drawPath(
      body.shift(const Offset(1.5, 2)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawPath(body, Paint()..color = color);

    // Pivot di pangkal
    canvas.drawCircle(
        Offset(w / 2, 0), w * 0.16, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w / 2, 0), w * 0.10, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter old) => old.color != color;
}

/// Simulasi fisika putaran: kecepatan konstan lalu melambat linear
/// hingga berhenti. v(t) = v0·(1 - t/T), θ(t) = v0·t·(1 - t/2T).
/// Mengembalikan nilai ternormalisasi 0..1 (AnimationController
/// selalu meng-clamp value ke rentang [0,1]).
class _DecelerationSimulation extends Simulation {
  final double v0; // kecepatan awal °/s
  final double totalAngle; // total sudut °
  final double T; // durasi detik

  _DecelerationSimulation(
      {required this.v0, required this.totalAngle, required this.T});

  @override
  double x(double timeInSeconds) =>
      v0 * timeInSeconds * (1 - timeInSeconds / (2 * T)) / totalAngle;

  @override
  double dx(double timeInSeconds) =>
      v0 * (1 - timeInSeconds / T) / totalAngle;

  @override
  bool isDone(double timeInSeconds) => timeInSeconds >= T;
}

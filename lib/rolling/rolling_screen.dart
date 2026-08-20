import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../gacha_luck/roulette_ticker.dart';

/// ═══════════════════════════════════════════════════════
/// ROLLING — Undi Yes / No (Meja Rollet)
/// ═══════════════════════════════════════════════════════
/// 10 grid: YES, NO, YES, NO ... (5 yes, 5 no).
/// Random murni berbasis timestamp. Putaran 10–30 detik,
/// kecepatan awal acak 95–100 (max=100), melambat hingga berhenti.
/// ═══════════════════════════════════════════════════════

enum YesNo { yes, no }

extension YesNoX on YesNo {
  String get label => this == YesNo.yes ? 'YES' : 'NO';
  Color get color =>
      this == YesNo.yes ? const Color(0xFF00C87A) : const Color(0xFFE74C3C);
  IconData get icon => this == YesNo.yes ? Icons.check_circle : Icons.cancel;
}

class RollingScreen extends StatefulWidget {
  const RollingScreen({super.key});

  @override
  State<RollingScreen> createState() => _RollingScreenState();
}

class _RollingScreenState extends State<RollingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _rng = Random();
  final _ticker = RouletteTicker();

  YesNo? _result;
  bool _spinning = false;

  double _baseRotation = 0;
  double _spinAngle = 0;
  
  // Simulasi fisika jarum: sudut (rad) & kecepatan sudut (rad/s).
  // Roda berputar searah jarum jam (kanan). Di Flutter rotasi positif = CW,
  // sehingga ujung jarum (di bawah pivot) bergerak ke KIRI saat sudut positif.
  // Karena paku mendorong jarum ke KANAN, impulsnya dibuat negatif.
  static const double _kStiffness = 120; // rad/s² per rad
  static const double _kDamping = 8; // per detik
  static const double _kMinKick = 2.2; // rad/s — dorongan dasar tiap hantaman
  static const double _kSpeedKick = 0.35; // rad/s tambahan kecepatan putar
  static const double _kMaxAmplitude = 0.6; // rad (~34°)
  double _needleAngle = 0;
  double _needleOmega = 0;
  Duration _lastElapsed = Duration.zero;
  StreamSubscription<double>? _tickSubscription;

  @override
  void initState() {
    super.initState();
    _ticker.loadAudio();
    _ticker.pegCount = 10; // 1 paku per garis batas sektor (10 sektor)
    _controller = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // Baca hasil dari posisi akhir roda (di mana pun ia berhenti)
          final finalAngle = _baseRotation + _spinAngle;
          setState(() {
            _spinning = false;
            _result = _resultFromAngle(finalAngle);
            _needleAngle = 0;
            _needleOmega = 0;
          });
          _tickSubscription?.cancel();
        } else if (status == AnimationStatus.forward) {
          // Start listening to ticks when animation starts
          _ticker.reset();
          _tickSubscription?.cancel();
          _tickSubscription = _ticker.tickStream.listen((intensity) {
            // Dorongan paku: ada dorongan dasar + tonjakan kecepatan, supaya
            // defleksi tetap terlihat walau roda sudah melambat.
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
    // NOTE: ticker adalah singleton — jangan di-dispose di sini,
    // kalau dibuang, player audio & stream tick mati untuk semua screen.
    super.dispose();
  }

  /// Random murni berbasis timestamp
  YesNo _roll() {
    final rng = Random(DateTime.now().microsecondsSinceEpoch);
    return rng.nextBool() ? YesNo.yes : YesNo.no;
  }

  /// Baca hasil dari posisi akhir roda (di mana pun ia berhenti)
  YesNo _resultFromAngle(double angleDeg) {
    const n = 10;
    final sectorAngle = 360 / n;
    // Jarum statis di atas (270°). Sektor di bawah jarum:
    final normalized = ((angleDeg % 360) + 360) % 360;
    // Hitung sektor yang berada di posisi 270° (jarum di atas)
    // Roda berputar searah jarum jam, jadi sektor yang melewati jarum adalah (270 - normalized)
    final sectorIndex = (((270 - normalized) % 360 + 360) % 360 / sectorAngle)
            .floor() %
        n;
    return sectorIndex.isEven ? YesNo.yes : YesNo.no;
  }

  void _spin() {
    if (_spinning) return;
    final target = _roll();

    // 10 sektor selang-seling: index genap = YES, ganjil = NO
    const n = 10;
    final sectorAngle = 360 / n;
    final index = target == YesNo.yes ? 0 : 1;
    final tierCenter = sectorAngle * index + sectorAngle / 2;
    final jitter = _rng.nextDouble() * sectorAngle * 0.6 - sectorAngle * 0.3;

    // Sektor target berhenti di bawah jarum statis (posisi jam 12 = 270°)
    // Kurangi _baseRotation agar benar untuk putaran ke-2 dst.
    var targetAngle = 270 - tierCenter - _baseRotation + jitter;
    targetAngle = ((targetAngle % 360) + 360) % 360;

    // Durasi acak 10–30 detik
    final T = 10 + _rng.nextDouble() * 20;

    // Kecepatan awal acak 95–100 (max = 100) → ×8 = 760–800 °/s
    const maxSpeed = 100;
    const speedScale = 8;
    final v0 = maxSpeed * (0.95 + _rng.nextDouble() * 0.05) * speedScale;

    // Total sudut = N putaran penuh + offset target, konsisten dgn v0·T/2
    final rotations = ((v0 * T / 2) / 360).floor();
    final totalAngle = rotations * 360 + targetAngle;
    final v0Final = 2 * totalAngle / T;

    setState(() {
      _spinning = true;
      _result = null;
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
                'Putar roda untuk mengundi YES atau NO!',
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
                        painter: _YesNoPainterWithPegs(),
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
                            child: Text('Tekan GO untuk mengundi',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13))),
                      )
                    : _ResultCard(
                        key: ValueKey(_result),
                        result: _result!,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final YesNo result;
  const _ResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: result.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(result.icon, size: 40, color: result.color),
          const SizedBox(height: 6),
          Text(result.label,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: result.color)),
        ],
      ),
    );
  }
}

/// Painter roda YES/NO dengan paku-paku di sekelilingnya
class _YesNoPainterWithPegs extends CustomPainter {
  const _YesNoPainterWithPegs();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const n = 10;
    final sweep = 360 / n;

    canvas.drawCircle(center, radius, Paint()..color = Colors.black26);

    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < n; i++) {
      paint.color = i.isEven ? const Color(0xFF00C87A) : const Color(0xFFE74C3C);
      canvas.drawArc(rect, i * sweep * pi / 180, sweep * pi / 180, true, paint);
    }

    // Label YES/NO di tiap sektor
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    for (var i = 0; i < n; i++) {
      final mid = (i * sweep + sweep / 2) * pi / 180;
      final label = i.isEven ? 'YES' : 'NO';
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      final pos = center +
          Offset(cos(mid), sin(mid)) * (radius * 0.72) -
          Offset(textPainter.width / 2, textPainter.height / 2);
      textPainter.paint(canvas, pos);
    }

    // Garis antar sektor
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    for (var i = 0; i < n; i++) {
      final angle = i * sweep * pi / 180;
      canvas.drawLine(
          center, center + Offset(cos(angle), sin(angle)) * radius, line);
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
  bool shouldRepaint(covariant _YesNoPainterWithPegs old) => false;
}

/// Jarum penunjuk statis — segitiga runcing ke bawah + pivot
class _NeedlePainter extends CustomPainter {
  final Color color;
  const _NeedlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

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

    canvas.drawCircle(
        Offset(w / 2, 0), w * 0.16, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w / 2, 0), w * 0.10, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter old) => old.color != color;
}

/// Simulasi fisika putaran: v(t) = v0·(1 - t/T), θ(t) = v0·t·(1 - t/2T).
/// Mengembalikan nilai ternormalisasi 0..1 (AnimationController clamp [0,1]).
class _DecelerationSimulation extends Simulation {
  final double v0;
  final double totalAngle;
  final double T;

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
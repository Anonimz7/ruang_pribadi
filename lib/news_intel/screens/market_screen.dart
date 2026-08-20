import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/apis.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _api = StockApi();
  Map<String, dynamic>? _summary;
  bool _loading = true;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _api.summary(days: _days);
      setState(() => _summary = d);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_summary == null) return const Center(child: Text('Tidak ada data'));

    final radar = _summary!['radar'] ?? {};
    final s = radar['summary'] ?? {};
    final data = radar['data'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Period
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [30, 60, 90, 180, 365]
                  .map((d) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Text('${d}H',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _days == d ? Colors.black : null)),
                          selected: _days == d,
                          selectedColor: const Color(0xFF00C87A),
                          onSelected: (_) {
                            setState(() => _days = d);
                            _load();
                          },
                        ),
                      ))
                  .toList()),
          const SizedBox(height: 16),
          // EWI/MCI
          Row(children: [
            _idxTile('EWI', (s['ewi_latest'] ?? 0).toDouble(),
                const Color(0xFF00C87A),
                change: (s['ewi_change_pct'] ?? 0).toDouble()),
            const SizedBox(width: 12),
            _idxTile('MCI', (s['mci_latest'] ?? 0).toDouble(),
                const Color(0xFFFFD700)),
          ]),
          const SizedBox(height: 20),
          // Charts
          if (data.isNotEmpty) ...[
            _radarChart(data),
            const SizedBox(height: 28),
            _chartPanel(
              title: 'Total Nilai Transaksi',
              subtitle: 'Regular value per hari',
              legend: const [
                _ChartLegendItem('Nilai transaksi', Color(0xFFF6903D)),
              ],
              height: 200,
              child: _valueChart(data),
            ),
            const SizedBox(height: 28),
            _chartPanel(
              title: 'Total Frekuensi',
              subtitle: 'Jumlah transaksi regular per hari',
              legend: const [
                _ChartLegendItem('Frekuensi', Color(0xFF6DC8EC)),
              ],
              height: 200,
              child: _freqChart(data),
            ),
            const SizedBox(height: 28),
            _chartPanel(
              title: 'ATV (Avg Transaction Value)',
              subtitle: 'Ukuran transaksi rata-rata — indikator institusional',
              legend: const [
                _ChartLegendItem('ATV', Color(0xFF9270CA)),
              ],
              height: 200,
              child: _atvChart(data),
            ),
            const SizedBox(height: 28),
            _chartPanel(
              title: 'Arus Dana Asing',
              subtitle: 'Net foreign buy / sell (estimasi IDR)',
              legend: const [
                _ChartLegendItem('Beli bersih', Color(0xFF00A86B)),
                _ChartLegendItem('Jual bersih', Color(0xFFD94B4B)),
              ],
              height: 210,
              child: _foreignChart(data),
            ),
            const SizedBox(height: 28),
            _chartPanel(
              title: 'BII Score (Buying Intensity Index)',
              subtitle: 'Skor akumulasi pasar — gabungan ATV & volatilitas',
              legend: const [
                _ChartLegendItem('BII Score', Color(0xFF7B61FF)),
              ],
              height: 210,
              child: _biiScoreChart(data),
            ),
            const SizedBox(height: 28),
            _chartPanel(
              title: 'Nilai Nego (Non-Regular)',
              subtitle: 'Transaksi negosiasi / block trade',
              legend: const [
                _ChartLegendItem('Nego Value', Color(0xFFF6C022)),
              ],
              height: 200,
              child: _negoValueChart(data),
            ),
            const SizedBox(height: 28),
            _chartPanel(
              title: 'Frekuensi Nego',
              subtitle: 'Jumlah transaksi negosiasi per hari',
              legend: const [
                _ChartLegendItem('Nego Freq', Color(0xFF90A4AE)),
              ],
              height: 180,
              child: _negoFreqChart(data),
            ),
            const SizedBox(height: 28),
          ],
          // Top accumulation
          const Text('TOP ACCUMULATION',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          _flowTable(_summary!['top_accumulation'] ?? [], Colors.green),
          const SizedBox(height: 16),
          // Top distribution
          const Text('TOP DISTRIBUTION',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          _flowTable(_summary!['top_distribution'] ?? [], Colors.red),
          const SizedBox(height: 16),
          // Top domination
          const Text('TOP 10 FOREIGN DOMINATION',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9270CA),
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          _dominationTable(_summary!['top_domination'] ?? []),
          const SizedBox(height: 16),
          // Market summary KPIs
          const Text('MARKET SUMMARY',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF6C022),
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          _marketSummaryTable(s),
        ]),
      ),
    );
  }

  // ── KPI Tiles ──────────────────────────────────────────────────────────

  Widget _idxTile(String label, double value, Color color, {double? change}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(value.toStringAsFixed(2),
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          if (change != null)
            Text('${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                style: TextStyle(
                    color: change >= 0 ? Colors.green : Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _idxChart(List<dynamic> data) {
    final colors = Theme.of(context).colorScheme;
    const ewiColor = Color(0xFF00A86B);
    const mciColor = Color(0xFFF2B705);
    final ewi = <FlSpot>[];
    final mci = <FlSpot>[];
    final values = <double>[];
    for (int i = 0; i < data.length; i++) {
      final ewiValue = (data[i]['ewi'] as num?)?.toDouble() ?? 100;
      final mciValue = (data[i]['mci'] as num?)?.toDouble() ?? 100;
      ewi.add(FlSpot(i.toDouble(), ewiValue));
      mci.add(FlSpot(i.toDouble(), mciValue));
      values.addAll([ewiValue, mciValue]);
    }
    final lowest = values.reduce((a, b) => a < b ? a : b);
    final highest = values.reduce((a, b) => a > b ? a : b);
    final padding = (highest - lowest).abs() * 0.18;
    final minY = lowest - (padding == 0 ? 1 : padding);
    final maxY = highest + (padding == 0 ? 1 : padding);
    final dateTicks = _dateTickIndexes(data.length);

    return LineChart(LineChartData(
      minX: 0,
      maxX: (data.length - 1).toDouble(),
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (maxY - minY) / 4,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 42,
          interval: (maxY - minY) / 4,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(value.toStringAsFixed(1),
                style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant)),
          ),
        )),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= data.length || !dateTicks.contains(index)) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              axisSide: meta.axisSide,
              child: Text(_dateLabel(data[index]['date']),
                  style:
                      TextStyle(fontSize: 9, color: colors.onSurfaceVariant)),
            );
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
            spots: ewi,
            isCurved: true,
            curveSmoothness: 0.18,
            color: ewiColor,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
                show: true, color: ewiColor.withValues(alpha: 0.08))),
        LineChartBarData(
            spots: mci,
            isCurved: true,
            curveSmoothness: 0.18,
            color: mciColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            dashArray: [5, 4]),
      ],
      lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => colors.inverseSurface,
        getTooltipItems: (spots) => spots.map((spot) {
          final label = spot.barIndex == 0 ? 'EWI' : 'MCI';
          return LineTooltipItem(
              '$label  ${spot.y.toStringAsFixed(2)}',
              TextStyle(
                  color: colors.onInverseSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w600));
        }).toList(),
      )),
    ));
  }

  Widget _radarChart(List<dynamic> data) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('EWI vs MCI',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Indeks relatif, basis awal periode = 100',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
        ])),
        _legend('EWI', const Color(0xFF00A86B)),
        const SizedBox(width: 10),
        _legend('MCI', const Color(0xFFF2B705)),
      ]),
      const SizedBox(height: 12),
      SizedBox(height: 230, child: _idxChart(data)),
    ]);
  }

  Widget _legend(String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]);

  Set<int> _dateTickIndexes(int count) {
    if (count <= 1) return {0};
    final last = count - 1;
    return {
      0,
      (last * 0.25).round(),
      (last * 0.5).round(),
      (last * 0.75).round(),
      last
    };
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse('$value');
    return date == null ? '$value' : DateFormat('d MMM').format(date);
  }

  // ── Chart Panel (reusable wrapper) ───────────────────────────────────

  Widget _chartPanel({
    required String title,
    required String subtitle,
    required List<_ChartLegendItem> legend,
    required double height,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
        ])),
        Wrap(
            spacing: 10,
            runSpacing: 4,
            children: legend
                .map((item) => _legend(item.label, item.color))
                .toList()),
      ]),
      const SizedBox(height: 12),
      SizedBox(height: height, child: child),
    ]);
  }

  // ── Value Chart ─────────────────────────────────────────────────────

  Widget _valueChart(List<dynamic> data) {
    final colors = Theme.of(context).colorScheme;
    const barColor = Color(0xFFF6903D);
    final bars = <BarChartGroupData>[];
    var maxValue = 0.0;
    for (int i = 0; i < data.length; i++) {
      final v = (data[i]['value'] as num?)?.toDouble() ?? 0;
      if (v > maxValue) maxValue = v;
      bars.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
            toY: v,
            color: barColor,
            width: data.length > 90 ? 2 : 5,
            borderRadius: BorderRadius.circular(1))
      ]));
    }
    final limit = maxValue == 0 ? 1.0 : maxValue * 1.15;
    final dateTicks = _dateTickIndexes(data.length);
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceBetween,
      minY: 0,
      maxY: limit,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: limit / 3,
        getDrawingHorizontalLine: (_) => FlLine(
            color: colors.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: limit / 3,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(_compact(value),
                style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant)),
          ),
        )),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= data.length || !dateTicks.contains(index)) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(_dateLabel(data[index]['date']),
                    style: TextStyle(
                        fontSize: 9, color: colors.onSurfaceVariant)));
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      barGroups: bars,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => colors.inverseSurface,
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
            '${_fullDate(data[group.x]['date'])}\nNilai Transaksi\nRp ${_compact(rod.toY)}',
            TextStyle(
                color: colors.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ));
  }

  // ── Frequency Chart ─────────────────────────────────────────────────

  Widget _freqChart(List<dynamic> data) {
    final colors = Theme.of(context).colorScheme;
    const freqColor = Color(0xFF6DC8EC);
    final bars = <BarChartGroupData>[];
    var maxValue = 0.0;
    for (int i = 0; i < data.length; i++) {
      final v = (data[i]['frequency'] as num?)?.toDouble() ?? 0;
      if (v > maxValue) maxValue = v;
      bars.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
            toY: v,
            color: freqColor,
            width: data.length > 90 ? 2 : 5,
            borderRadius: BorderRadius.circular(1))
      ]));
    }
    final limit = maxValue == 0 ? 1.0 : maxValue * 1.15;
    final dateTicks = _dateTickIndexes(data.length);
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceBetween,
      minY: 0,
      maxY: limit,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: limit / 3,
        getDrawingHorizontalLine: (_) => FlLine(
            color: colors.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: limit / 3,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(_compact(value),
                style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant)),
          ),
        )),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= data.length || !dateTicks.contains(index)) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(_dateLabel(data[index]['date']),
                    style: TextStyle(
                        fontSize: 9, color: colors.onSurfaceVariant)));
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      barGroups: bars,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => colors.inverseSurface,
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
            '${_fullDate(data[group.x]['date'])}\nFrekuensi\n${_compact(rod.toY)} transaksi',
            TextStyle(
                color: colors.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ));
  }

  // ── ATV Chart ───────────────────────────────────────────────────────

  Widget _atvChart(List<dynamic> data) {
    final colors = Theme.of(context).colorScheme;
    const atvColor = Color(0xFF9270CA);
    final bars = <BarChartGroupData>[];
    var maxValue = 0.0;
    for (int i = 0; i < data.length; i++) {
      final v = (data[i]['atv'] as num?)?.toDouble() ?? 0;
      if (v > maxValue) maxValue = v;
      bars.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
            toY: v,
            color: atvColor,
            width: data.length > 90 ? 2 : 5,
            borderRadius: BorderRadius.circular(1))
      ]));
    }
    final limit = maxValue == 0 ? 1.0 : maxValue * 1.15;
    final dateTicks = _dateTickIndexes(data.length);
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceBetween,
      minY: 0,
      maxY: limit,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: limit / 3,
        getDrawingHorizontalLine: (_) => FlLine(
            color: colors.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: limit / 3,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(_compact(value),
                style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant)),
          ),
        )),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= data.length || !dateTicks.contains(index)) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(_dateLabel(data[index]['date']),
                    style: TextStyle(
                        fontSize: 9, color: colors.onSurfaceVariant)));
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      barGroups: bars,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => colors.inverseSurface,
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
            '${_fullDate(data[group.x]['date'])}\nATV\nRp ${_compact(rod.toY)}',
            TextStyle(
                color: colors.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ));
  }

  // ── Foreign Chart ────────────────────────────────────────────────────

  Widget _foreignChart(List<dynamic> data) {
    final colors = Theme.of(context).colorScheme;
    const buy = Color(0xFF00A86B);
    const sell = Color(0xFFD94B4B);
    final bars = <BarChartGroupData>[];
    var maxValue = 0.0;
    for (int i = 0; i < data.length; i++) {
      final v = (data[i]['net_foreign'] as num?)?.toDouble() ?? 0;
      maxValue = v.abs() > maxValue ? v.abs() : maxValue;
      bars.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
            toY: v,
            color: v >= 0 ? buy : sell,
            width: data.length > 90 ? 2 : 5,
            borderRadius: BorderRadius.circular(1))
      ]));
    }
    final limit = maxValue == 0 ? 1.0 : maxValue * 1.15;
    final dateTicks = _dateTickIndexes(data.length);
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceBetween,
      minY: -limit,
      maxY: limit,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: limit,
        getDrawingHorizontalLine: (value) => FlLine(
          color: value == 0
              ? colors.onSurfaceVariant.withValues(alpha: 0.8)
              : colors.outlineVariant.withValues(alpha: 0.5),
          strokeWidth: value == 0 ? 1.2 : 1,
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: limit,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(_compact(value),
                style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant)),
          ),
        )),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= data.length || !dateTicks.contains(index)) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(_dateLabel(data[index]['date']),
                    style: TextStyle(
                        fontSize: 9, color: colors.onSurfaceVariant)));
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      barGroups: bars,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => colors.inverseSurface,
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
            '${_fullDate(data[group.x]['date'])}\n${rod.toY >= 0 ? 'Beli bersih' : 'Jual bersih'}\nRp ${_compact(rod.toY.abs())}',
            TextStyle(
                color: colors.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ));
  }

  // ── BII Score Chart ─────────────────────────────────────────────────

  Widget _biiScoreChart(List<dynamic> data) {
    final colors = Theme.of(context).colorScheme;
    const biiColor = Color(0xFF7B61FF);
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      final v = (data[i]['bii_score'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), v));
    }
    final values = spots.map((s) => s.y).toList();
    final lowest = values.reduce((a, b) => a < b ? a : b);
    final highest = values.reduce((a, b) => a > b ? a : b);
    final pad = (highest - lowest).abs() * 0.12;
    final minY = (lowest - (pad == 0 ? 5 : pad)).clamp(0, 100).toDouble();
    final maxY = (highest + (pad == 0 ? 5 : pad)).clamp(0, 100).toDouble();
    final dateTicks = _dateTickIndexes(data.length);
    return LineChart(LineChartData(
      minX: 0,
      maxX: (data.length - 1).toDouble(),
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (maxY - minY) / 4,
        getDrawingHorizontalLine: (_) => FlLine(
            color: colors.outlineVariant.withValues(alpha: 0.55),
            strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36,
          interval: (maxY - minY) / 4,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(value.toStringAsFixed(0),
                style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant)),
          ),
        )),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= data.length || !dateTicks.contains(index)) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(_dateLabel(data[index]['date']),
                    style: TextStyle(
                        fontSize: 9, color: colors.onSurfaceVariant)));
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.18,
          color: biiColor,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData:
              BarAreaData(show: true, color: biiColor.withValues(alpha: 0.12)),
        )
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => colors.inverseSurface,
          getTooltipItems: (touched) => touched.map((spot) {
            final point = data[spot.x.round()];
            return LineTooltipItem(
              '${_fullDate(point['date'])}\nBII Score: ${spot.y.toStringAsFixed(1)}',
              TextStyle(
                  color: colors.onInverseSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            );
          }).toList(),
        ),
      ),
    ));
  }

  // ── Nego Value Chart ────────────────────────────────────────────────

  Widget _negoValueChart(List<dynamic> data) {
    final colors = Theme.of(context).colorScheme;
    const negoColor = Color(0xFFF6C022);
    final bars = <BarChartGroupData>[];
    var maxValue = 0.0;
    for (int i = 0; i < data.length; i++) {
      final v = (data[i]['non_reg_value'] as num?)?.toDouble() ?? 0;
      if (v > maxValue) maxValue = v;
      bars.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
            toY: v,
            color: negoColor,
            width: data.length > 90 ? 2 : 5,
            borderRadius: BorderRadius.circular(1))
      ]));
    }
    final limit = maxValue == 0 ? 1.0 : maxValue * 1.15;
    final dateTicks = _dateTickIndexes(data.length);
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceBetween,
      minY: 0,
      maxY: limit,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: limit / 3,
        getDrawingHorizontalLine: (_) => FlLine(
            color: colors.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: limit / 3,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(_compact(value),
                style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant)),
          ),
        )),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= data.length || !dateTicks.contains(index)) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(_dateLabel(data[index]['date']),
                    style: TextStyle(
                        fontSize: 9, color: colors.onSurfaceVariant)));
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      barGroups: bars,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => colors.inverseSurface,
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
            '${_fullDate(data[group.x]['date'])}\nNego Value\nRp ${_compact(rod.toY)}',
            TextStyle(
                color: colors.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ));
  }

  // ── Nego Frequency Chart ────────────────────────────────────────────

  Widget _negoFreqChart(List<dynamic> data) {
    final colors = Theme.of(context).colorScheme;
    const freqColor = Color(0xFF90A4AE);
    final bars = <BarChartGroupData>[];
    var maxValue = 0.0;
    for (int i = 0; i < data.length; i++) {
      final v = (data[i]['non_reg_freq'] as num?)?.toDouble() ?? 0;
      if (v > maxValue) maxValue = v;
      bars.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
            toY: v,
            color: freqColor,
            width: data.length > 90 ? 2 : 5,
            borderRadius: BorderRadius.circular(1))
      ]));
    }
    final limit = maxValue == 0 ? 1.0 : maxValue * 1.15;
    final dateTicks = _dateTickIndexes(data.length);
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceBetween,
      minY: 0,
      maxY: limit,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: limit / 3,
        getDrawingHorizontalLine: (_) => FlLine(
            color: colors.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36,
          interval: limit / 3,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(_compact(value),
                style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant)),
          ),
        )),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= data.length || !dateTicks.contains(index)) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(_dateLabel(data[index]['date']),
                    style: TextStyle(
                        fontSize: 9, color: colors.onSurfaceVariant)));
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      barGroups: bars,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => colors.inverseSurface,
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
            '${_fullDate(data[group.x]['date'])}\nNego Freq: ${rod.toY.toStringAsFixed(0)}',
            TextStyle(
                color: colors.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ));
  }

  // ── Domination Table ────────────────────────────────────────────────

  Widget _dominationTable(List<dynamic> items) {
    if (items.isEmpty) return const SizedBox();
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10)),
      child: Column(
          children: items.asMap().entries.map((e) {
        final i = e.key + 1;
        final s = e.value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            SizedBox(
                width: 24,
                child: Text('$i',
                    style: const TextStyle(fontSize: 11, color: Colors.grey))),
            Expanded(
                flex: 2,
                child: Text(s['ticker'] ?? '',
                    style: const TextStyle(
                        color: Color(0xFF9270CA),
                        fontWeight: FontWeight.bold,
                        fontSize: 12))),
            Expanded(
                flex: 3,
                child: Text(s['company_name'] ?? '',
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis)),
            SizedBox(
                width: 50,
                child: Text(s['dom_txt'] ?? '',
                    style: const TextStyle(
                        color: Color(0xFF9270CA),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right)),
            SizedBox(
                width: 60,
                child: Text(s['val_txt'] ?? '',
                    style:
                        TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
                    textAlign: TextAlign.right)),
          ]),
        );
      }).toList()),
    );
  }

  // ── Market Summary Table ────────────────────────────────────────────

  Widget _marketSummaryTable(Map<String, dynamic> s) {
    final colors = Theme.of(context).colorScheme;
    final items = [
      _KpiRow('TOTAL REGULAR', _compact(s['total_reg_value'] ?? 0),
          const Color(0xFFF6903D)),
      _KpiRow('TOTAL NEGO', _compact(s['total_nego_value'] ?? 0),
          const Color(0xFFF6C022)),
      _KpiRow('GRAND NET FOREIGN', _compact(s['total_net_foreign'] ?? 0),
          (s['total_net_foreign'] ?? 0) >= 0 ? Colors.green : Colors.red),
      _KpiRow('MARKET BREADTH (EWI)', (s['ewi_latest'] ?? 0).toStringAsFixed(2),
          const Color(0xFF00A86B)),
    ];
    return Container(
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: items
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(
                        child: Text(r.label,
                            style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600))),
                    Text(r.value,
                        style: TextStyle(
                            fontSize: 13,
                            color: r.color,
                            fontWeight: FontWeight.bold)),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  // ── Formatters ──────────────────────────────────────────────────────

  String _fullDate(dynamic value) {
    final date = DateTime.tryParse('$value');
    return date == null ? '$value' : DateFormat('d MMMM yyyy').format(date);
  }

  String _compact(double value) {
    final absolute = value.abs();
    final sign = value < 0 ? '-' : '';
    if (absolute >= 1e12) {
      return '$sign${(absolute / 1e12).toStringAsFixed(1)}T';
    }
    if (absolute >= 1e9) return '$sign${(absolute / 1e9).toStringAsFixed(1)}B';
    if (absolute >= 1e6) return '$sign${(absolute / 1e6).toStringAsFixed(1)}M';
    return '$sign${absolute.toStringAsFixed(0)}';
  }

  // ── Flow Table (Accumulation / Distribution) ───────────────────────

  Widget _flowTable(List<dynamic> items, Color color) {
    if (items.isEmpty) return const SizedBox();
    return Container(
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10)),
      child: Column(
          children: items.asMap().entries.map((e) {
        final i = e.key + 1;
        final s = e.value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            SizedBox(
                width: 24,
                child: Text('$i',
                    style: const TextStyle(fontSize: 11, color: Colors.grey))),
            Expanded(
                flex: 2,
                child: Text(s['ticker'] ?? '',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12))),
            Expanded(
                flex: 4,
                child: Text(s['company_name'] ?? '',
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis)),
            Expanded(
                flex: 2,
                child: Text(s['net_flow_txt'] ?? '',
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right)),
          ]),
        );
      }).toList()),
    );
  }
}

class _ChartLegendItem {
  const _ChartLegendItem(this.label, this.color);
  final String label;
  final Color color;
}

class _KpiRow {
  const _KpiRow(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
}

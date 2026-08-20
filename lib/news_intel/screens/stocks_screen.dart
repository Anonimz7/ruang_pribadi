import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/apis.dart';
import '../models/stock_models.dart';
import '../../widgets/stock_widgets.dart';

class StocksScreen extends StatefulWidget {
  final String? initialTicker;
  const StocksScreen({super.key, this.initialTicker});

  @override
  State<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends State<StocksScreen> {
  final _api = StockApi();
  final _searchCtrl = TextEditingController();
  List<StockListItem> _results = [];
  StockAnalysis? _analysis;
  bool _loading = false;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    if (widget.initialTicker != null) {
      _searchCtrl.text = widget.initialTicker!;
      _load(widget.initialTicker!);
    }
  }

  // ── Compare state ──────────────────────────────────────────────────────────
  bool _compareMode = false;
  final List<String> _compareTickers = [];
  final Map<String, List<dynamic>> _compareData = {};
  bool _compareLoading = false;

  /// Predefined palette for compared stock lines.
  static const _compareColors = [
    Color(0xFF00A86B), // green (primary)
    Color(0xFF5B8FF9), // blue
    Color(0xFFF6903D), // orange
    Color(0xFFE86452), // red
    Color(0xFF9270CA), // purple
    Color(0xFF5AD8A6), // mint
    Color(0xFF6DC8EC), // sky
    Color(0xFFF6C022), // gold
  ];

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    try {
      final results = await _api.searchTyped(q);
      if (mounted && _searchCtrl.text == q) {
        setState(() => _results = results);
      }
    } catch (_) {}
  }

  void _resetCompare() {
    _compareMode = false;
    _compareTickers.clear();
    _compareData.clear();
  }

  Future<void> _load(String ticker) async {
    final t = ticker.toUpperCase();
    final isSameTicker = _analysis != null && _analysis!.ticker == t;
    setState(() {
      _loading = true;
      _results = [];
      _searchCtrl.text = t;
      if (!isSameTicker) _resetCompare();
    });
    try {
      final d = await _api.stockAnalysis(ticker, days: _days);
      setState(() => _analysis = d);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Compare helpers ────────────────────────────────────────────────────────

  Future<void> _addCompare(String ticker) async {
    final t = ticker.toUpperCase();
    if (_compareTickers.contains(t)) return;
    setState(() => _compareLoading = true);
    try {
      final d = await _api.stockAnalysis(t, days: _days);
      final data = d.data;
      if (data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tidak ada data untuk $t')),
          );
        }
        return;
      }
      setState(() {
        _compareTickers.add(t);
        _compareData[t] = data.map((e) => e.toJson()).toList();
        _compareMode = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _compareLoading = false);
    }
  }

  /// Refresh data comparison stock yang sudah ada (untuk perubahan periode).
  Future<void> _refreshCompare(String ticker) async {
    final t = ticker.toUpperCase();
    if (!_compareTickers.contains(t)) return;
    try {
      final d = await _api.stockAnalysis(t, days: _days);
      final data = d.data;
      if (data.isNotEmpty) {
        setState(() => _compareData[t] = data.map((e) => e.toJson()).toList());
      }
    } catch (_) {}
  }

  void _removeCompare(String ticker) {
    setState(() {
      _compareTickers.remove(ticker);
      _compareData.remove(ticker);
      if (_compareTickers.isEmpty) _compareMode = false;
    });
  }

  void _showCompareSearch() {
    final ctrl = TextEditingController();
    List<StockListItem> results = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> doSearch(String q) async {
              if (q.trim().isEmpty) {
                setSheet(() => results = []);
                return;
              }
              try {
                final r = await _api.searchTyped(q);
                if (ctx.mounted) setSheet(() => results = r);
              } catch (_) {}
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Tambah Saham untuk Dibandingkan',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Cari ticker (BBCA, GOTO...)',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: doSearch,
                  ),
                  const SizedBox(height: 8),
                  if (_compareLoading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  if (results.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final s = results[i];
                          final already =
                              _compareTickers.contains(s.ticker.toUpperCase());
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              already
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: already ? Colors.green : Colors.grey,
                            ),
                            title: Row(
                              children: [
                                Text(s.ticker,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 6),
                                StockSectorBadge(label: s.sector, small: true),
                              ],
                            ),
                            subtitle: Text(s.companyName,
                                style: const TextStyle(fontSize: 12)),
                            onTap: already
                                ? null
                                : () async {
                                    Navigator.pop(ctx);
                                    await _addCompare(s.ticker);
                                  },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _colorFor(int index) => _compareColors[index % _compareColors.length];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Back button + title — only when opened from the stock list
            // (initialTicker set); in the main menu it has no AppBar at all.
            if (widget.initialTicker != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Kembali',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _analysis?.ticker ?? 'Analisis Saham',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Search
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari ticker (BBCA, GOTO...)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: _search,
                  onSubmitted: (v) => _load(v.toUpperCase()),
                ),
                const SizedBox(height: 8),
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
                                if (_analysis != null) {
                                  _load(_analysis!.ticker);
                                  // Refresh compare data with new period
                                  for (final t in _compareTickers) {
                                    _refreshCompare(t);
                                  }
                                }
                              },
                            ),
                          ))
                      .toList(),
                ),
              ]),
            ),
            // Compare mode: chips row + add button
            if (_analysis != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.compare_arrows,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        const Text('Bandingkan',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey)),
                        const Spacer(),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 14),
                          label: const Text('Tambah',
                              style: TextStyle(fontSize: 11)),
                          onPressed: _showCompareSearch,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                    if (_compareTickers.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _compareTickers.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, i) {
                            final t = _compareTickers[i];
                            final c = _colorFor(i + 1);
                            return InputChip(
                              avatar:
                                  CircleAvatar(radius: 6, backgroundColor: c),
                              label: Text(t,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () => _removeCompare(t),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              side: BorderSide(color: c.withValues(alpha: 0.4)),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            // Search results
            if (_results.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final s = _results[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.show_chart,
                          color: Color(0xFF00C87A)),
                      title: Row(
                        children: [
                          Text(s.ticker,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          StockSectorBadge(label: s.sector, small: true),
                          if (s.isDelisted) ...[
                            const SizedBox(width: 4),
                            DelistedBadge(
                                labelDelisted: s.labelDelisted, small: true),
                          ],
                        ],
                      ),
                      subtitle: Text(s.companyName,
                          style: const TextStyle(fontSize: 12)),
                      onTap: () => _load(s.ticker),
                    );
                  },
                ),
              ),
            // Analysis
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _analysis == null
                      ? const Center(
                          child: Text('Cari saham untuk melihat analisis'))
                      : _buildAnalysis(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysis() {
    final s = _analysis!.summary;
    final data = _analysis!.data;
    final rawData = data.map((e) => e.toJson()).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(
                  children: [
                    Text(_analysis!.ticker,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    DelistedBadge(labelDelisted: _analysis!.labelDelisted),
                  ],
                ),
                Text(_analysis!.companyName,
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Rp ${_fmt(s.latestPrice)}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${s.priceChangePct.toStringAsFixed(1)}%',
                style: TextStyle(
                    color: s.priceChangePct >= 0 ? Colors.green : Colors.red)),
          ]),
        ]),

        // ── Sector Info Card ──
        StockInfoCard(stock: _analysis!),

        const SizedBox(height: 12),
        // Metrics – Row 1
        Row(children: [
          _metric(
              'BII Score', s.latestBiiScore.toStringAsFixed(1), Colors.purple),
          _metric('Foreign %', '${s.foreignDominationPct.toStringAsFixed(1)}%',
              Colors.blue),
          _metric('Net Foreign', _fmtS(s.totalNetForeign), Colors.teal),
        ]),
        const SizedBox(height: 8),
        // Metrics – Row 2
        Row(children: [
          _metric('Total Value', _fmtS(s.totalValue), Colors.orange),
          _metric('Total Vol', _fmtS(s.totalVolume), Colors.cyan),
          _metric('Avg BII', s.avgBiiScore.toStringAsFixed(1), Colors.indigo),
        ]),
        const SizedBox(height: 24),
        if (rawData.isNotEmpty) ...[
          // ── Compare chart (when compare mode + data) ──
          if (_compareMode && _compareTickers.isNotEmpty) ...[
            _chartPanel(
              title: 'Perbandingan Harga (Normalisasi)',
              subtitle: 'Persentase perubahan dari hari pertama',
              legend: [
                _ChartLegendItem(_analysis!.ticker, _colorFor(0)),
                for (int i = 0; i < _compareTickers.length; i++)
                  _ChartLegendItem(_compareTickers[i], _colorFor(i + 1)),
              ],
              height: 300,
              child: _buildCompareChart(rawData),
            ),
            const SizedBox(height: 28),
          ] else ...[
            _chartPanel(
              title: 'Pergerakan Harga',
              subtitle: 'Harga penutupan harian',
              legend: const [
                _ChartLegendItem('Harga penutupan', Color(0xFF00A86B)),
              ],
              height: 270,
              child: _priceChart(rawData),
            ),
            const SizedBox(height: 28),
          ],
          const SizedBox(height: 28),
          _chartPanel(
            title: 'Total Nilai Transaksi',
            subtitle: 'Regular value per hari',
            legend: const [
              _ChartLegendItem('Nilai transaksi', Color(0xFFF6903D)),
            ],
            height: 200,
            child: _valueChart(rawData),
          ),
          const SizedBox(height: 28),
          _chartPanel(
            title: 'Volume Perdagangan',
            subtitle: 'Jumlah lot yang diperdagangkan',
            legend: const [
              _ChartLegendItem('Volume', Color(0xFF6DC8EC)),
            ],
            height: 200,
            child: _volumeChart(rawData),
          ),
          _chartPanel(
            title: 'Arus Dana Asing',
            subtitle: 'Net foreign buy / sell',
            legend: const [
              _ChartLegendItem('Beli bersih', Color(0xFF00A86B)),
              _ChartLegendItem('Jual bersih', Color(0xFFD94B4B)),
            ],
            height: 210,
            child: _foreignChart(rawData),
          ),
          const SizedBox(height: 28),
          _chartPanel(
            title: 'BII Score (Buying Intensity Index)',
            subtitle: 'Skor akumulasi — gabungan ATV & volatilitas',
            legend: const [
              _ChartLegendItem('BII Score', Color(0xFF7B61FF)),
            ],
            height: 210,
            child: _biiScoreChart(rawData),
          ),
          const SizedBox(height: 28),
          _chartPanel(
            title: 'ATV (Avg Transaction Value)',
            subtitle:
                'Ukuran transaksi rata-rata — indikator aktivitas institusional',
            legend: const [
              _ChartLegendItem('ATV', Color(0xFF9270CA)),
            ],
            height: 200,
            child: _atvChart(rawData),
          ),
          const SizedBox(height: 28),
          _chartPanel(
            title: 'Nilai Nego (Non-Regular)',
            subtitle: 'Transaksi negosiasi / luar pasar',
            legend: const [
              _ChartLegendItem('Nego Value', Color(0xFFF6C022)),
            ],
            height: 200,
            child: _negoValueChart(rawData),
          ),
          const SizedBox(height: 28),
          _chartPanel(
            title: 'Frekuensi Nego',
            subtitle: 'Jumlah transaksi negosiasi per hari',
            legend: const [
              _ChartLegendItem('Nego Freq', Color(0xFF90A4AE)),
            ],
            height: 180,
            child: _negoFreqChart(rawData),
          ),
          const SizedBox(height: 28),
          // ── Data Summary Table ──
          _buildSummaryTable(rawData),
        ],
      ]),
    );
  }

  Widget _chartPanel({
    required String title,
    required String subtitle,
    required List<_ChartLegendItem> legend,
    required double height,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      // Analysis content is padded 12px. The charts deliberately reclaim it
      // so their axes and plot use the maximum horizontal space.
      return Transform.translate(
        offset: const Offset(-12, 0),
        child: SizedBox(
          width: constraints.maxWidth + 24,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 11, color: colors.onSurfaceVariant)),
                    ])),
                Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: legend.map(_chartLegend).toList()),
              ]),
            ),
            const SizedBox(height: 12),
            SizedBox(height: height, child: child),
          ]),
        ),
      );
    });
  }

  Widget _chartLegend(_ChartLegendItem item) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: item.color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(item.label,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]);

  Widget _metric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ),
    );
  }

  Widget _priceChart(List<dynamic> data) {
    final colors = Theme.of(context).colorScheme;
    const gain = Color(0xFF00A86B);
    final prices = <double>[];
    for (int i = 0; i < data.length; i++) {
      prices.add((data[i]['close'] as num?)?.toDouble() ?? 0);
    }
    final lowest = prices.reduce((a, b) => a < b ? a : b);
    final highest = prices.reduce((a, b) => a > b ? a : b);
    final padding = (highest - lowest).abs() * 0.12;
    final minY = lowest - (padding == 0 ? lowest.abs() * 0.04 : padding);
    final maxY = highest + (padding == 0 ? highest.abs() * 0.04 : padding);
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
          reservedSize: 44,
          interval: (maxY - minY) / 4,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(_priceAxisLabel(value),
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
            if (index < 0 ||
                index >= data.length ||
                !dateTicks.contains(index)) {
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
          spots: List.generate(
              prices.length, (i) => FlSpot(i.toDouble(), prices[i])),
          isCurved: true,
          curveSmoothness: 0.18,
          color: gain,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData:
              BarAreaData(show: true, color: gain.withValues(alpha: 0.10)),
        )
      ],
      lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => colors.inverseSurface,
        getTooltipItems: (touched) => touched.map((spot) {
          final point = data[spot.x.round()];
          return LineTooltipItem(
            '${_fullDate(point['date'])}\n',
            TextStyle(
                color: colors.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600),
            children: [
              TextSpan(
                  text: 'Penutupan  Rp ${_fmt(spot.y)}\n',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(
                  text:
                      'Open ${_fmt(point['open'])}  High ${_fmt(point['high'])}\n'),
              TextSpan(
                  text:
                      'Low  ${_fmt(point['low'])}  Vol ${_fmtS(point['volume'])}'),
            ],
          );
        }).toList(),
      )),
    ));
  }

  // ── Value Chart ─────────────────────────────────────────────────────────

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
            if (index < 0 ||
                index >= data.length ||
                !dateTicks.contains(index)) {
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
            '${_fullDate(data[group.x]['date'])}\nNilai Transaksi\nRp ${_fmtS(rod.toY)}',
            TextStyle(
                color: colors.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ));
  }

  // ── ATV Chart ────────────────────────────────────────────────────────────

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
            if (index < 0 ||
                index >= data.length ||
                !dateTicks.contains(index)) {
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
            '${_fullDate(data[group.x]['date'])}\nATV\nRp ${_fmtS(rod.toY)}',
            TextStyle(
                color: colors.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ));
  }

  // ── BII Score Chart ──────────────────────────────────────────────────────

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
            if (index < 0 ||
                index >= data.length ||
                !dateTicks.contains(index)) {
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

  // ── Nego Value Chart ────────────────────────────────────────────────────

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
            if (index < 0 ||
                index >= data.length ||
                !dateTicks.contains(index)) {
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
            '${_fullDate(data[group.x]['date'])}\nNego Value\nRp ${_fmtS(rod.toY)}',
            TextStyle(
                color: colors.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ));
  }

  // ── Nego Frequency Chart ────────────────────────────────────────────────

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
            if (index < 0 ||
                index >= data.length ||
                !dateTicks.contains(index)) {
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

  // ── Volume Chart ────────────────────────────────────────────────────────

  Widget _volumeChart(List<dynamic> data) {
    final colors = Theme.of(context).colorScheme;
    const volColor = Color(0xFF6DC8EC);
    final bars = <BarChartGroupData>[];
    var maxValue = 0.0;
    for (int i = 0; i < data.length; i++) {
      final v = (data[i]['volume'] as num?)?.toDouble() ?? 0;
      if (v > maxValue) maxValue = v;
      bars.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
            toY: v,
            color: volColor,
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
            if (index < 0 ||
                index >= data.length ||
                !dateTicks.contains(index)) {
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
            '${_fullDate(data[group.x]['date'])}\nVolume: ${_fmtS(rod.toY)}',
            TextStyle(
                color: colors.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ));
  }

  // ── Summary Table ───────────────────────────────────────────────────────

  Widget _buildSummaryTable(List<dynamic> data) {
    final colors = Theme.of(context).colorScheme;
    // Show last 15 rows (most recent first)
    final rows = data.length > 15 ? data.sublist(0, 15) : data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ringkasan Data',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('${rows.length} hari terakhir',
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
                colors.surfaceContainerHighest.withValues(alpha: 0.5)),
            dataRowMinHeight: 34,
            dataRowMaxHeight: 38,
            headingRowHeight: 36,
            horizontalMargin: 12,
            columnSpacing: 14,
            columns: const [
              DataColumn(
                  label: Text('Tanggal',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Harga',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Chg%',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Net For.',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('ATV',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('BII',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('F:R',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold))),
            ],
            rows: rows.map((r) {
              final close = (r['close'] as num?)?.toDouble() ?? 0;
              final prevPrice = (r['prev_price'] as num?)?.toDouble() ?? close;
              final chg =
                  prevPrice > 0 ? ((close - prevPrice) / prevPrice * 100) : 0.0;
              final netF = (r['net_foreign'] as num?)?.toDouble() ?? 0;
              final atv = (r['atv'] as num?)?.toDouble() ?? 0;
              final bii = (r['bii_score'] as num?)?.toDouble() ?? 0;
              final fb = (r['foreign_buy'] as num?)?.toDouble() ?? 0;
              final fs = (r['foreign_sell'] as num?)?.toDouble() ?? 0;
              final vol = (r['volume'] as num?)?.toDouble() ?? 0;
              final frRatio = vol > 0 ? ((fb + fs) / (vol * 2) * 100) : 0.0;
              return DataRow(cells: [
                DataCell(Text(_dateLabel(r['date']),
                    style: const TextStyle(fontSize: 10))),
                DataCell(Text('Rp ${_fmt(close)}',
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600))),
                DataCell(Text(
                    '${chg >= 0 ? '+' : ''}${chg.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 10,
                        color: chg >= 0 ? Colors.green : Colors.red))),
                DataCell(Text(_fmtS(netF),
                    style: TextStyle(
                        fontSize: 10,
                        color: netF >= 0 ? Colors.green : Colors.red))),
                DataCell(
                    Text(_compact(atv), style: const TextStyle(fontSize: 10))),
                DataCell(Text(bii.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF7B61FF),
                        fontWeight: FontWeight.w600))),
                DataCell(Text('${frRatio.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 10))),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Foreign Chart ────────────────────────────────────────────────────────

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
            if (index < 0 ||
                index >= data.length ||
                !dateTicks.contains(index)) {
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
            '${_fullDate(data[group.x]['date'])}\n${rod.toY >= 0 ? 'Beli bersih' : 'Jual bersih'}\nRp ${_fmtS(rod.toY.abs())}',
            TextStyle(
                color: colors.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ));
  }

  // ── Normalized compare chart ─────────────────────────────────────────────

  Widget _buildCompareChart(List<dynamic> primaryData) {
    final colors = Theme.of(context).colorScheme;
    final dateTicks = _dateTickIndexes(primaryData.length);

    // Build normalized series: primary stock first, then each compared stock.
    final series = <_CompareSeries>[];

    // Primary stock
    series.add(_CompareSeries(
      ticker: _analysis!.ticker,
      color: _colorFor(0),
      data: primaryData,
    ));

    // Compared stocks — align by date index if lengths differ
    for (int i = 0; i < _compareTickers.length; i++) {
      final d = _compareData[_compareTickers[i]];
      if (d != null && d.isNotEmpty) {
        series.add(_CompareSeries(
          ticker: _compareTickers[i],
          color: _colorFor(i + 1),
          data: d,
        ));
      }
    }

    // Normalize all to % change from first day (base = 0%)
    final normalized = <List<FlSpot>>[];
    var globalMin = 0.0;
    var globalMax = 0.0;
    for (final s in series) {
      final base = (s.data.first['close'] as num?)?.toDouble() ?? 1;
      final spots = <FlSpot>[];
      for (int i = 0; i < s.data.length; i++) {
        final close = (s.data[i]['close'] as num?)?.toDouble() ?? base;
        final pct = ((close - base) / base) * 100;
        spots.add(FlSpot(i.toDouble(), pct));
        if (pct < globalMin) globalMin = pct;
        if (pct > globalMax) globalMax = pct;
      }
      normalized.add(spots);
    }

    final padRange = (globalMax - globalMin).abs() * 0.12;
    final minY = globalMin - (padRange == 0 ? 1 : padRange);
    final maxY = globalMax + (padRange == 0 ? 1 : padRange);

    // Find the max data length for X axis
    int maxLen = primaryData.length;
    for (final s in series) {
      if (s.data.length > maxLen) maxLen = s.data.length;
    }

    return LineChart(LineChartData(
      minX: 0,
      maxX: (maxLen - 1).toDouble(),
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (maxY - minY) / 5,
        getDrawingHorizontalLine: (_) => FlLine(
          color: colors.outlineVariant.withValues(alpha: 0.55),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 48,
            interval: (maxY - minY) / 5,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              axisSide: meta.axisSide,
              child: Text(
                '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant),
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if (index < 0 ||
                  index >= primaryData.length ||
                  !dateTicks.contains(index)) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(_dateLabel(primaryData[index]['date']),
                    style:
                        TextStyle(fontSize: 9, color: colors.onSurfaceVariant)),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        for (int s = 0; s < series.length; s++)
          LineChartBarData(
            spots: normalized[s],
            isCurved: true,
            curveSmoothness: 0.18,
            color: series[s].color,
            barWidth: s == 0 ? 2.5 : 2.0,
            dotData: const FlDotData(show: false),
            belowBarData: s == 0
                ? BarAreaData(
                    show: true, color: series[s].color.withValues(alpha: 0.06))
                : BarAreaData(show: false),
          ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => colors.inverseSurface,
          tooltipRoundedRadius: 8,
          getTooltipItems: (touched) {
            return touched.map((spot) {
              final si = spot.barIndex;
              final ticker = series[si].ticker;
              final c = series[si].color;
              return LineTooltipItem(
                '$ticker  ${spot.y >= 0 ? '+' : ''}${spot.y.toStringAsFixed(2)}%',
                TextStyle(
                  color: c,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
      ),
    ));
  }

  Set<int> _dateTickIndexes(int count) {
    if (count <= 1) return {0};
    final last = count - 1;
    return {
      0,
      (last * 0.25).round(),
      (last * 0.5).round(),
      (last * 0.75).round(),
      last,
    };
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse('$value');
    return date == null ? '$value' : DateFormat('d MMM').format(date);
  }

  String _fullDate(dynamic value) {
    final date = DateTime.tryParse('$value');
    return date == null ? '$value' : DateFormat('d MMMM yyyy').format(date);
  }

  String _priceAxisLabel(double value) => value >= 1000
      ? '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k'
      : value.toStringAsFixed(0);

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

  String _fmt(dynamic v) {
    if (v == null) return '-';
    final n = (v as num).toDouble();
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
    return n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtS(dynamic v) {
    if (v == null) return '-';
    final n = (v as num).toDouble();
    final s = n < 0 ? '-' : '';
    final a = n.abs();
    if (a >= 1e12) return '$s${(a / 1e12).toStringAsFixed(1)}T';
    if (a >= 1e9) return '$s${(a / 1e9).toStringAsFixed(1)}B';
    if (a >= 1e6) return '$s${(a / 1e6).toStringAsFixed(1)}M';
    return '$s${a.toStringAsFixed(0)}';
  }
}

class _ChartLegendItem {
  const _ChartLegendItem(this.label, this.color);

  final String label;
  final Color color;
}

class _CompareSeries {
  const _CompareSeries({
    required this.ticker,
    required this.color,
    required this.data,
  });

  final String ticker;
  final Color color;
  final List<dynamic> data;
}

import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/apis.dart';
import '../models/stock_models.dart';
import '../../widgets/stock_widgets.dart';
import 'stocks_screen.dart';

/// Screen for browsing all IDX stocks with server-side pagination,
/// sector filtering, and search.
class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final _api = StockApi();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // ── Pagination state ──
  static const _pageSize = 50;
  List<StockListItem> _stocks = [];
  int _total = 0;
  int _offset = 0;
  bool _loadingFirst = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  // ── Filter state (server-side) ──
  Set<String> _sectors = {};
  Set<String> _primarySectors = {};
  Set<String> _subSectors = {};
  String _selectedSector = '';
  String _selectedPrimary = '';
  String _selectedSub = '';
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadFirstPage() async {
    setState(() {
      _loadingFirst = true;
      _error = null;
      _stocks = [];
      _offset = 0;
      _hasMore = true;
    });
    try {
      final res = await _api.stockList(
        limit: _pageSize,
        offset: 0,
        q: _query,
        sector: _selectedSector,
        primarySector: _selectedPrimary,
        subSector: _selectedSub,
      );
      // Top-level sectors fetched from a dedicated endpoint rather than
      // derived from the paginated result set — deriving from the first
      // page misses sectors whose stocks don't fall within it (e.g.
      // "Kesehatan"), causing them to disappear from the filter.
      final sectors = _selectedSector.isEmpty
          ? await _api.sectorOptions()
          : <String>[];
      if (mounted) {
        setState(() {
          _stocks = res.stocks;
          _total = res.total;
          _offset = res.stocks.length;
          _hasMore = _stocks.length < res.total;
          if (sectors.isNotEmpty) _sectors = sectors.toSet();
          _loadingFirst = false;
        });
        // Scroll back to top when filters change
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loadingFirst = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await _api.stockList(
        limit: _pageSize,
        offset: _offset,
        q: _query,
        sector: _selectedSector,
        primarySector: _selectedPrimary,
        subSector: _selectedSub,
      );
      if (mounted) {
        setState(() {
          _stocks.addAll(res.stocks);
          _offset += res.stocks.length;
          _hasMore = _offset < res.total;
          _total = res.total;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  // ── Filtering (server-side) ──────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _query = value.trim();
      _loadFirstPage();
    });
  }

  // ── Cascading sector filters ────────────────────────────────────────────
  // Selecting a parent resets all children below it (their old choices may
  // not exist under the new parent) and refetches child options from the API.

  Future<void> _onSectorChanged(String? value) async {
    _selectedSector = value ?? '';
    _selectedPrimary = '';
    _selectedSub = '';
    _primarySectors = {};
    _subSectors = {};
    if (_selectedSector.isNotEmpty) {
      final opts = await _api.sectorOptions(sector: _selectedSector);
      if (mounted) {
        setState(() => _primarySectors = opts.toSet());
      }
    }
    _loadFirstPage();
  }

  Future<void> _onPrimaryChanged(String? value) async {
    _selectedPrimary = value ?? '';
    _selectedSub = '';
    _subSectors = {};
    if (_selectedPrimary.isNotEmpty) {
      final opts = await _api.sectorOptions(
        sector: _selectedSector,
        primarySector: _selectedPrimary,
      );
      if (mounted) {
        setState(() => _subSectors = opts.toSet());
      }
    }
    _loadFirstPage();
  }

  void _onSubChanged(String? value) {
    _selectedSub = value ?? '';
    _loadFirstPage();
  }

  void _resetSectorFilters() {
    _selectedSector = '';
    _selectedPrimary = '';
    _selectedSub = '';
    _primarySectors = {};
    _subSectors = {};
    _loadFirstPage();
  }

  bool get _filterActive =>
      _query.isNotEmpty ||
      _selectedSector.isNotEmpty ||
      _selectedPrimary.isNotEmpty ||
      _selectedSub.isNotEmpty;

  /// Reusable cascading sector dropdown. Disabled (greyed) when the parent
  /// level isn't chosen yet.
  Widget _sectorDropdown({
    required String value,
    required String hint,
    required Set<String> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    final colors = Theme.of(context).colorScheme;
    final opacity = enabled ? 1.0 : 0.45;
    return Opacity(
      opacity: opacity,
      child: DropdownButton<String>(
        value: value.isEmpty ? null : value,
        hint: Text(hint,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
        isDense: true,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: [
          const DropdownMenuItem<String>(
            value: '',
            child: Text('Semua', style: TextStyle(fontSize: 12)),
          ),
          ...items.map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 12)),
              )),
        ],
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _openAnalysis(String ticker) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StocksScreen(initialTicker: ticker),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Filter bar ──
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                border: Border(
                  bottom: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Search field
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Cari ticker atau nama...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _query = '';
                                _loadFirstPage();
                              },
                            )
                          : null,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 8),
                  // Sector filters — cascading: Sektor → Sub Sektor Primer →
                  // Sub Sektor. Lower levels are disabled until their parent
                  // is chosen, and reset when the parent changes.
                  Row(
                    children: [
                      Icon(Icons.filter_list,
                          size: 16, color: colors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('Sektor:',
                          style: TextStyle(
                              fontSize: 12, color: colors.onSurfaceVariant)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _sectorDropdown(
                          value: _selectedSector,
                          hint: 'Semua',
                          items: _sectors,
                          onChanged: _onSectorChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 20),
                      Expanded(
                        child: _sectorDropdown(
                          value: _selectedPrimary,
                          hint: 'Sub Sektor Primer',
                          items: _primarySectors,
                          enabled: _selectedSector.isNotEmpty,
                          onChanged: _onPrimaryChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _sectorDropdown(
                          value: _selectedSub,
                          hint: 'Sub Sektor',
                          items: _subSectors,
                          enabled: _selectedPrimary.isNotEmpty,
                          onChanged: _onSubChanged,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedSector.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _resetSectorFilters,
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text('Reset Filter',
                              style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 0),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Status bar ──
            if (!_loadingFirst)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      _filterActive
                          ? 'Menampilkan $_total saham (filter aktif)'
                          : '$_total saham total — halaman ${(_offset / _pageSize).ceil()}',
                      style: TextStyle(
                          fontSize: 11, color: colors.onSurfaceVariant),
                    ),
                    if (_selectedSector.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      StockSectorBadge(label: _selectedSector, small: true),
                    ],
                    if (_selectedPrimary.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      StockSectorBadge(label: _selectedPrimary, small: true),
                    ],
                    if (_selectedSub.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      StockSectorBadge(label: _selectedSub, small: true),
                    ],
                    if (_selectedSector.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _resetSectorFilters,
                        child: Icon(Icons.close,
                            size: 14, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),

            // ── Stock list ──
            Expanded(
              child: _loadingFirst
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadFirstPage,
                      child: _error != null
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.3,
                                ),
                                Icon(Icons.error_outline,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.error),
                                const SizedBox(height: 8),
                                Center(
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error)),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: ElevatedButton.icon(
                                    onPressed: _loadFirstPage,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Coba Lagi'),
                                  ),
                                ),
                              ],
                            )
                          : _stocks.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 200),
                                    Center(
                                      child: Text(
                                        'Tidak ada saham ditemukan',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  controller: _scrollCtrl,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount:
                                      _stocks.length + (_hasMore ? 1 : 0),
                                  itemBuilder: (_, i) {
                                    if (i == _stocks.length) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2)),
                                      );
                                    }
                                    final stock = _stocks[i];
                                    return _StockListTile(
                                      stock: stock,
                                      onTap: () => _openAnalysis(stock.ticker),
                                    );
                                  },
                                ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual stock list tile with sector badge and delisted indicator.
class _StockListTile extends StatelessWidget {
  final StockListItem stock;
  final VoidCallback onTap;

  const _StockListTile({required this.stock, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: stock.isDelisted ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            // Ticker
            SizedBox(
              width: 64,
              child: Text(
                stock.ticker,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: stock.isDelisted
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Company name + sector badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: stock.isDelisted
                          ? colors.onSurfaceVariant.withValues(alpha: 0.6)
                          : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      if (stock.sector != null)
                        StockSectorBadge(label: stock.sector, small: true),
                      if (stock.subSector != null)
                        StockSectorBadge(label: stock.subSector, small: true),
                    ],
                  ),
                ],
              ),
            ),
            // Delisted badge + chevron
            const SizedBox(width: 8),
            DelistedBadge(labelDelisted: stock.labelDelisted, small: true),
            if (!stock.isDelisted) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 18, color: colors.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}

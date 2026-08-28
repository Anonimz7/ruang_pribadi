import 'dart:async';
import 'package:flutter/material.dart';
import '../services/apis.dart';
import '../news_intel/models/stock_models.dart';
import '../widgets/stock_widgets.dart';

class AdminStockStatusScreen extends StatefulWidget {
  const AdminStockStatusScreen({super.key});

  @override
  State<AdminStockStatusScreen> createState() => _AdminStockStatusScreenState();
}

class _AdminStockStatusScreenState extends State<AdminStockStatusScreen> {
  final _api = AdminApi();
  final _searchCtrl = TextEditingController();
  List<StockStatusItem> _stocks = [];
  bool _loading = true;
  Timer? _debounce;
  String _filter = ''; // '', 'blacklist', 'whitelist', 'unset'

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _api.getStockStatusList(
        q: _searchCtrl.text.trim(),
        status: _filter,
      );
      if (mounted) setState(() => _stocks = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load());
  }

  void _setFilter(String f) {
    setState(() => _filter = f);
    _load();
  }

  // ── Status BottomSheet ──────────────────────────────────────────────

  void _showStatusSheet(StockStatusItem stock) {
    if (stock.isDelisted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saham delisted tidak bisa di-set status')),
      );
      return;
    }

    String selectedStatus = stock.stockStatus ?? 'whitelist';
    final reasonCtrl = TextEditingController(text: stock.statusReason ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Text(
                'Set Status: ${stock.ticker}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                stock.companyName,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 16),

              // ── Status Dropdown ──
              DropdownButtonFormField<String>(
                value: selectedStatus,
                items: const [
                  DropdownMenuItem(
                      value: 'whitelist', child: Text('Whitelist')),
                  DropdownMenuItem(
                      value: 'blacklist', child: Text('Blacklist')),
                ],
                onChanged: (v) {
                  if (v != null) setSheetState(() => selectedStatus = v);
                },
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // ── Reason TextField ──
              TextField(
                controller: reasonCtrl,
                maxLines: 5,
                minLines: 3,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Alasan *',
                  hintText: 'Masukkan alasan perubahan status...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              // ── Buttons ──
              Row(
                children: [
                  if (stock.stockStatus != null) ...[
                    OutlinedButton(
                      onPressed: () => _resetStatus(ctx, stock),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final reason = reasonCtrl.text.trim();
                      if (reason.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Alasan harus diisi')),
                        );
                        return;
                      }
                      _saveStatus(ctx, stock, selectedStatus, reason);
                    },
                    child: const Text('Simpan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveStatus(
    BuildContext ctx,
    StockStatusItem stock,
    String status,
    String reason,
  ) async {
    try {
      await _api.setStockStatus(stock.ticker, status, reason);
      if (mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status ${stock.ticker} berhasil di-set')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _resetStatus(BuildContext ctx, StockStatusItem stock) async {
    try {
      await _api.resetStockStatus(stock.ticker);
      if (mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status ${stock.ticker} berhasil di-reset')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────

  int _countByStatus(String? status) {
    if (status == null) return _stocks.where((s) => s.stockStatus == null).length;
    return _stocks.where((s) => s.stockStatus == status).length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Status Saham')),
      body: Column(
        children: [
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cari ticker / nama...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // ── Filter Chips ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildFilterChip('Semua', '', colors),
                const SizedBox(width: 6),
                _buildFilterChip('-', 'unset', colors),
                const SizedBox(width: 6),
                _buildFilterChip('Whitelist', 'whitelist', colors),
                const SizedBox(width: 6),
                _buildFilterChip('Blacklist', 'blacklist', colors),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Stock List ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _stocks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined,
                                size: 48,
                                color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text(
                              'Tidak ada saham ditemukan',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _stocks.length,
                          itemBuilder: (ctx, i) =>
                              _buildStockTile(_stocks[i], colors),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, ColorScheme colors) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => _setFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.15)
              : colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.5)
                : colors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildStockTile(StockStatusItem stock, ColorScheme colors) {
    final isDelisted = stock.isDelisted;
    final statusColor = stock.isBlacklisted
        ? Colors.orange
        : stock.isWhitelisted
            ? Colors.green
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: SizedBox(
          width: 56,
          child: Text(
            stock.ticker,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDelisted
                  ? colors.onSurfaceVariant.withValues(alpha: 0.5)
                  : colors.onSurface,
            ),
          ),
        ),
        title: Text(
          stock.companyName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: isDelisted
                ? colors.onSurfaceVariant.withValues(alpha: 0.5)
                : colors.onSurface,
          ),
        ),
        subtitle: stock.sector != null
            ? StockSectorBadge(label: stock.sector, small: true)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DelistedBadge(
              labelDelisted: stock.labelDelisted,
              stockStatus: stock.stockStatus,
              small: true,
            ),
            const SizedBox(width: 6),
            if (!isDelisted)
              IconButton(
                icon: Icon(Icons.settings, size: 18, color: colors.primary),
                onPressed: () => _showStatusSheet(stock),
                tooltip: 'Set Status',
              )
            else
              Tooltip(
                message: 'Saham delisted',
                child: Icon(Icons.lock_outline,
                    size: 18, color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
              ),
          ],
        ),
      ),
    );
  }
}

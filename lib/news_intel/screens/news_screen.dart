import 'package:flutter/material.dart';
import '../../services/apis.dart';
import 'article_webview_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final _api = NewsApi();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _articles = [];
  List<dynamic> _domains = [];
  bool _loading = true;
  int _page = 1;
  int _total = 0;
  int _hours = 24;
  String? _domain;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int get _totalPages => _total == 0 ? 1 : (_total / 50).ceil();

  Future<void> _loadPage({int? page, bool refreshDomains = false}) async {
    setState(() => _loading = true);
    try {
      final requestedPage = page ?? _page;
      final r = await Future.wait([
        _api.articles(
          hours: _hours,
          domain: _domain,
          search: _search,
          page: requestedPage,
        ),
        if (refreshDomains || _domains.isEmpty) _api.domains(),
      ]);
      final articlesResult = r.first as Map<String, dynamic>;
      final articles = List<dynamic>.from(articlesResult['articles'] ?? []);
      setState(() {
        _page = requestedPage;
        _articles = articles;
        _total = articlesResult['total'] as int? ?? 0;
        if (r.length > 1) _domains = r[1] as List<dynamic>;
      });
      // Scroll to top on page change
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submitSearch(String value) {
    final query = value.trim();
    if (query == _search) return;
    setState(() => _search = query);
    _loadPage(page: 1);
  }

  void _clearSearch() {
    _searchController.clear();
    _submitSearch('');
  }

  Future<void> _jumpToPage() async {
    final controller = TextEditingController(text: '$_page');
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Loncat ke Halaman'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nomor halaman (1–$_totalPages)',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            final n = int.tryParse(v);
            if (n != null && n >= 1 && n <= _totalPages) {
              Navigator.of(ctx).pop(n);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              if (n != null && n >= 1 && n <= _totalPages) {
                Navigator.of(ctx).pop(n);
              }
            },
            child: const Text('Pergi'),
          ),
        ],
      ),
    );
    if (picked != null && picked != _page) {
      _loadPage(page: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _submitSearch,
            decoration: InputDecoration(
              hintText: 'Cari judul berita…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            DropdownButton<int>(
              value: _hours,
              items: const [
                DropdownMenuItem(value: 6, child: Text('6 Jam')),
                DropdownMenuItem(value: 24, child: Text('24 Jam')),
                DropdownMenuItem(value: 48, child: Text('2 Hari')),
                DropdownMenuItem(value: 168, child: Text('1 Minggu')),
              ],
              onChanged: (v) {
                setState(() => _hours = v!);
                _loadPage(page: 1);
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _chip('Semua', _domain == null, () {
                    setState(() => _domain = null);
                    _loadPage(page: 1);
                  }),
                  ..._domains.map(
                      (d) => _chip(d['domain'], _domain == d['domain'], () {
                            setState(() => _domain = d['domain']);
                            _loadPage(page: 1);
                          })),
                ]),
              ),
            ),
          ]),
        ),
        // List + Pagination footer
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _articles.isEmpty
                  ? const Center(child: Text('Tidak ada berita'))
                  : RefreshIndicator(
                      onRefresh: () => _loadPage(refreshDomains: true),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _articles.length + 1,
                        itemBuilder: (_, i) {
                          // Pagination footer — after last article
                          if (i == _articles.length) {
                            return _buildPaginationFooter();
                          }
                          final a = _articles[i];
                          final domain = a['domain'] ?? '';
                          final url = a['url'] ?? '';
                          final time = (a['pub_wib'] ?? '').length > 16
                              ? a['pub_wib'].substring(11, 16)
                              : '';
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    _domainColor(domain).withValues(alpha: 0.2),
                                child: Text(
                                    domain.length > 3
                                        ? domain.substring(0, 3).toUpperCase()
                                        : domain.toUpperCase(),
                                    style: TextStyle(
                                        color: _domainColor(domain),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                              title: Text(a['title'] ?? '',
                                  maxLines: 3, overflow: TextOverflow.ellipsis),
                              subtitle: Text('$domain • $time WIB',
                                  style: const TextStyle(fontSize: 12)),
                              trailing: url.isNotEmpty
                                  ? Icon(Icons.open_in_new,
                                      size: 18,
                                      color:
                                          Theme.of(context).colorScheme.outline)
                                  : null,
                              onTap: url.isNotEmpty
                                  ? () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ArticleWebViewScreen(
                                            url: url,
                                            title: a['title'] ?? '',
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // ── Pagination footer inside ListView ────────────────────────────────

  Widget _buildPaginationFooter() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row: prev | page buttons | next
          Row(
            children: [
              // Prev button
              _iconBtn(
                icon: Icons.chevron_left,
                enabled: _page > 1,
                onTap: () => _loadPage(page: _page - 1),
              ),
              // Page buttons (scrollable)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _pageItems(),
                  ),
                ),
              ),
              // Next button
              _iconBtn(
                icon: Icons.chevron_right,
                enabled: _page < _totalPages,
                onTap: () => _loadPage(page: _page + 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Info row + jump button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$_total artikel • ',
                style: theme.textTheme.labelSmall,
              ),
              GestureDetector(
                onTap: _jumpToPage,
                child: Text(
                  'Halaman $_page dari $_totalPages',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _jumpToPage,
                child: Icon(Icons.edit_calendar_rounded,
                    size: 16, color: cs.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _pageItems() {
    final pages = <int>{1, _totalPages, _page - 1, _page, _page + 1}
        .where((page) => page >= 1 && page <= _totalPages)
        .toList()
      ..sort();
    final items = <Widget>[];
    int? prev;
    for (final p in pages) {
      if (prev != null && p - prev > 1) {
        items.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('…', style: TextStyle(fontSize: 12)),
        ));
      }
      items.add(_pageChip(p));
      prev = p;
    }
    return items;
  }

  Widget _pageChip(int page) {
    final cs = Theme.of(context).colorScheme;
    final active = page == _page;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: active ? null : () => _loadPage(page: page),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? cs.primary : cs.outlineVariant,
            ),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? cs.onPrimary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: '',
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, color: enabled ? cs.primary : cs.outlineVariant),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Chip(
          label: Text(label,
              style: TextStyle(
                  fontSize: 11, color: selected ? Colors.black : null)),
          backgroundColor: selected ? const Color(0xFF00C87A) : null,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Color _domainColor(String d) {
    const m = {
      'reuters': Colors.orange,
      'bloomberg': Colors.blue,
      'bloombergtechnoz': Colors.cyan,
      'ft': Colors.pink,
      'kontan': Colors.green,
      'cna': Colors.teal,
      'rt': Colors.red,
      'people': Colors.indigo,
    };
    return m[d] ?? Colors.grey;
  }
}

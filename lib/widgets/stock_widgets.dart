import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../news_intel/models/stock_models.dart';

/// Compact badge showing a stock's sector or sub-sector.
///
/// Usage:
/// ```dart
/// StockSectorBadge(label: stock.sector)
/// StockSectorBadge(label: stock.subSector, small: true)
/// ```
class StockSectorBadge extends StatelessWidget {
  final String? label;
  final bool small;
  final Color? color;

  const StockSectorBadge({
    super.key,
    this.label,
    this.small = false,
    this.color,
  });

  /// Predefined palette mapped to IDX sector names.
  static Color _sectorColor(String sector) {
    switch (sector) {
      case 'Energi':
        return const Color(0xFFE86452);
      case 'Primer':
        return const Color(0xFF6DC8EC);
      case 'Layanan Kesehatan':
        return const Color(0xFF00C87A);
      case 'Industri':
        return const Color(0xFFF6903D);
      case 'Keuangan':
        return const Color(0xFF5B8FF9);
      case 'Utilitas':
        return const Color(0xFF9270CA);
      case 'Teknologi':
        return const Color(0xFF7B61FF);
      case 'Konsumer Non-Siklis':
        return const Color(0xFF5AD8A6);
      case 'Konsumer Siklis':
        return const Color(0xFFF6C022);
      case 'Properti & Real Estat':
        return const Color(0xFFD94B4B);
      case 'Infrastruktur':
        return const Color(0xFF90A4AE);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (label == null || label!.isEmpty) return const SizedBox.shrink();

    final bgColor = color ?? _sectorColor(label!);
    final fontSize = small ? 9.0 : 11.0;
    final horizPad = small ? 6.0 : 8.0;
    final vertPad = small ? 1.0 : 3.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizPad, vertical: vertPad),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bgColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label!,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: bgColor,
        ),
      ),
    );
  }
}

/// Delisted status indicator chip.
class DelistedBadge extends StatelessWidget {
  final int? labelDelisted;
  final bool small;

  const DelistedBadge({
    super.key,
    this.labelDelisted,
    this.small = false,
  });

  bool get isDelisted => labelDelisted == 1;

  @override
  Widget build(BuildContext context) {
    final fontSize = small ? 9.0 : 11.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 4.0 : 6.0,
        vertical: small ? 1.0 : 2.0,
      ),
      decoration: BoxDecoration(
        color: isDelisted
            ? Colors.red.withValues(alpha: 0.12)
            : Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDelisted ? Icons.cancel : Icons.check_circle,
            size: small ? 10 : 12,
            color: isDelisted ? Colors.red : Colors.green,
          ),
          SizedBox(width: small ? 2 : 4),
          Text(
            isDelisted ? 'Delisted' : 'Aktif',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: isDelisted ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sector info card for stock profile / analysis detail view.
///
/// Displays sector, primary_sector, sub_sector, core_business, and delisted
/// status in a card layout.
class StockInfoCard extends StatelessWidget {
  final StockProfile stock;

  const StockInfoCard({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Don't show the card if all sector fields are null.
    final hasSector = stock.sector != null || stock.primarySector != null;
    final hasCore =
        stock.coreBusiness != null && stock.coreBusiness!.isNotEmpty;
    if (!hasSector && !hasCore && stock.labelDelisted == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ──
          Row(
            children: [
              Icon(Icons.business_center, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                'Info Sektor',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const Spacer(),
              DelistedBadge(labelDelisted: stock.labelDelisted),
            ],
          ),
          const SizedBox(height: 10),

          // ── Sector fields ──
          if (stock.sector != null) _infoRow('Sektor', stock.sector!, colors),
          if (stock.primarySector != null)
            _infoRow('Sub Sektor Primer', stock.primarySector!, colors),
          if (stock.subSector != null)
            _infoRow('Sub Sektor', stock.subSector!, colors),

          // ── Sector badges row ──
          if (stock.sector != null || stock.subSector != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (stock.sector != null) StockSectorBadge(label: stock.sector),
                if (stock.primarySector != null)
                  StockSectorBadge(label: stock.primarySector, small: true),
                if (stock.subSector != null)
                  StockSectorBadge(label: stock.subSector, small: true),
              ],
            ),
          ],

          // ── Core business ──
          if (hasCore) ...[
            const SizedBox(height: 10),
            Divider(
                height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text(
              'Bisnis Inti',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stock.coreBusiness!,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: colors.onSurfaceVariant.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 10),
            Divider(
                height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            // ── Google AI Search button ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final query = Uri.encodeComponent(
                      'Apa itu saham ${stock.ticker} (${stock.companyName})?');
                  launchUrl(
                    Uri.parse('https://www.google.com/search?udm=50&q=$query'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.language, size: 16),
                label: Text(
                  'Pelajari ${stock.companyName}',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

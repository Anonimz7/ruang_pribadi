/// ── Stock Models ─────────────────────────────────────────────────────────────
///
/// Typed models for IDX stock data based on the backend API (2026-08-03).
/// All sector fields are nullable — never assume they have a value.

/// Lightweight item returned by search & list endpoints.
class StockListItem {
  final String ticker;
  final String companyName;
  final String? sector;
  final String? primarySector;
  final String? subSector;
  final int? labelDelisted;

  const StockListItem({
    required this.ticker,
    required this.companyName,
    this.sector,
    this.primarySector,
    this.subSector,
    this.labelDelisted,
  });

  /// `true` if the stock has been delisted.
  bool get isDelisted => labelDelisted == 1;

  factory StockListItem.fromJson(Map<String, dynamic> j) => StockListItem(
        ticker: (j['ticker'] as String?) ?? '',
        companyName: (j['company_name'] as String?) ?? '',
        sector: j['sector'] as String?,
        primarySector: j['primary_sector'] as String?,
        subSector: j['sub_sector'] as String?,
        labelDelisted: j['label_delisted'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'ticker': ticker,
        'company_name': companyName,
        'sector': sector,
        'primary_sector': primarySector,
        'sub_sector': subSector,
        'label_delisted': labelDelisted,
      };
}

/// Full stock profile — extends [StockListItem] with `core_business`.
class StockProfile extends StockListItem {
  final String? coreBusiness;

  const StockProfile({
    required super.ticker,
    required super.companyName,
    super.sector,
    super.primarySector,
    super.subSector,
    super.labelDelisted,
    this.coreBusiness,
  });

  factory StockProfile.fromJson(Map<String, dynamic> j) => StockProfile(
        ticker: (j['ticker'] as String?) ?? '',
        companyName: (j['company_name'] as String?) ?? '',
        sector: j['sector'] as String?,
        primarySector: j['primary_sector'] as String?,
        subSector: j['sub_sector'] as String?,
        labelDelisted: j['label_delisted'] as int?,
        coreBusiness: j['core_business'] as String?,
      );
}

/// Single data point in the analysis time series.
class StockDataPoint {
  final String date;
  final double close;
  final double open;
  final double high;
  final double low;
  final double volume;
  final double value;
  final int frequency;
  final double foreignBuy;
  final double foreignSell;
  final double nonRegValue;
  final double nonRegVolume;
  final int nonRegFreq;
  // ── Backend-computed metrics (returned by API) ──
  final double netForeign;
  final double atv;
  final double biiScore;
  final double prevPrice;
  final double change;

  const StockDataPoint({
    required this.date,
    required this.close,
    this.open = 0,
    this.high = 0,
    this.low = 0,
    required this.volume,
    required this.value,
    required this.frequency,
    required this.foreignBuy,
    required this.foreignSell,
    required this.nonRegValue,
    required this.nonRegVolume,
    required this.nonRegFreq,
    this.netForeign = 0,
    this.atv = 0,
    this.biiScore = 50,
    this.prevPrice = 0,
    this.change = 0,
  });

  factory StockDataPoint.fromJson(Map<String, dynamic> j) => StockDataPoint(
        date: (j['date'] ?? j['trade_date'] ?? '') as String,
        close: (j['close'] as num?)?.toDouble() ?? 0,
        open: (j['open'] as num?)?.toDouble() ?? 0,
        high: (j['high'] as num?)?.toDouble() ?? 0,
        low: (j['low'] as num?)?.toDouble() ?? 0,
        volume: (j['volume'] as num?)?.toDouble() ?? 0,
        value: (j['value'] as num?)?.toDouble() ?? 0,
        frequency: (j['frequency'] as num?)?.toInt() ?? 0,
        foreignBuy: (j['foreign_buy'] as num?)?.toDouble() ?? 0,
        foreignSell: (j['foreign_sell'] as num?)?.toDouble() ?? 0,
        nonRegValue: (j['non_reg_value'] as num?)?.toDouble() ?? 0,
        nonRegVolume: (j['non_reg_volume'] as num?)?.toDouble() ?? 0,
        nonRegFreq: (j['non_reg_freq'] as num?)?.toInt() ?? 0,
        netForeign: (j['net_foreign'] as num?)?.toDouble() ?? 0,
        atv: (j['atv'] as num?)?.toDouble() ?? 0,
        biiScore: (j['bii_score'] as num?)?.toDouble() ?? 50,
        prevPrice: (j['prev_price'] as num?)?.toDouble() ?? 0,
        change: (j['change'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'close': close,
        'open': open,
        'high': high,
        'low': low,
        'volume': volume,
        'value': value,
        'frequency': frequency,
        'foreign_buy': foreignBuy,
        'foreign_sell': foreignSell,
        'non_reg_value': nonRegValue,
        'non_reg_volume': nonRegVolume,
        'non_reg_freq': nonRegFreq,
        'net_foreign': netForeign,
        'atv': atv,
        'bii_score': biiScore,
        'prev_price': prevPrice,
        'change': change,
      };

  /// Simple foreign buy minus sell (unweighted).
  double get rawNetForeign => foreignBuy - foreignSell;
}

/// Summary statistics for the analysis period.
class StockSummary {
  final double priceChangePct;
  final double latestPrice;
  final double latestBiiScore;
  final double totalNetForeign;
  final double avgBiiScore;
  final double foreignDominationPct;
  final double totalValue;
  final double totalVolume;

  const StockSummary({
    required this.priceChangePct,
    required this.latestPrice,
    required this.latestBiiScore,
    required this.totalNetForeign,
    required this.avgBiiScore,
    required this.foreignDominationPct,
    required this.totalValue,
    required this.totalVolume,
  });

  factory StockSummary.fromJson(Map<String, dynamic> j) => StockSummary(
        priceChangePct: (j['price_change_pct'] as num?)?.toDouble() ?? 0,
        latestPrice: (j['latest_price'] as num?)?.toDouble() ?? 0,
        latestBiiScore: (j['latest_bii_score'] as num?)?.toDouble() ?? 0,
        totalNetForeign: (j['total_net_foreign'] as num?)?.toDouble() ?? 0,
        avgBiiScore: (j['avg_bii_score'] as num?)?.toDouble() ?? 0,
        foreignDominationPct:
            (j['foreign_domination_pct'] as num?)?.toDouble() ?? 0,
        totalValue: (j['total_value'] as num?)?.toDouble() ?? 0,
        totalVolume: (j['total_volume'] as num?)?.toDouble() ?? 0,
      );
}

/// Full analysis response — extends [StockProfile] with time series & summary.
class StockAnalysis extends StockProfile {
  final int periodDays;
  final List<StockDataPoint> data;
  final StockSummary summary;

  const StockAnalysis({
    required super.ticker,
    required super.companyName,
    super.sector,
    super.primarySector,
    super.subSector,
    super.labelDelisted,
    super.coreBusiness,
    required this.periodDays,
    required this.data,
    required this.summary,
  });

  factory StockAnalysis.fromJson(Map<String, dynamic> j) {
    final dataList = (j['data'] as List?) ?? [];
    return StockAnalysis(
      ticker: (j['ticker'] as String?) ?? '',
      companyName: (j['company_name'] as String?) ?? '',
      sector: j['sector'] as String?,
      primarySector: j['primary_sector'] as String?,
      subSector: j['sub_sector'] as String?,
      labelDelisted: j['label_delisted'] as int?,
      coreBusiness: j['core_business'] as String?,
      periodDays: (j['period_days'] as num?)?.toInt() ?? 90,
      data: dataList
          .map((e) => StockDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary:
          StockSummary.fromJson((j['summary'] as Map<String, dynamic>?) ?? {}),
    );
  }
}

/// Paginated list response from `GET /idx/stocks?limit=&offset=`.
class StockListResponse {
  final int total;
  final List<StockListItem> stocks;

  const StockListResponse({required this.total, required this.stocks});

  factory StockListResponse.fromJson(Map<String, dynamic> j) {
    final list = (j['stocks'] as List?) ?? [];
    return StockListResponse(
      total: (j['total'] as num?)?.toInt() ?? 0,
      stocks: list
          .map((e) => StockListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

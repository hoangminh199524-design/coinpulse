class TickerState {
  final String symbol;
  final double openPrice;
  final double currentPrice;
  final double highPrice;
  final double lowPrice;
  final double quoteVolume;
  final int sourceTimestamp;

  const TickerState({
    required this.symbol,
    required this.openPrice,
    required this.currentPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.quoteVolume,
    required this.sourceTimestamp,
  });

  // Derived metrics - computed from openPrice and currentPrice in a single place
  double get priceChangeAmount => currentPrice - openPrice;

  double get priceChangePercent {
    if (openPrice <= 0) return 0.0;
    return ((currentPrice - openPrice) / openPrice) * 100.0;
  }

  bool get isValid =>
      symbol.isNotEmpty &&
      openPrice > 0 &&
      currentPrice > 0 &&
      quoteVolume >= 0 &&
      priceChangePercent.isFinite &&
      priceChangeAmount.isFinite;

  // Normalized from REST ticker/24hr
  // symbol -> symbol
  // openPrice -> openPrice
  // lastPrice -> currentPrice
  // highPrice -> highPrice
  // lowPrice -> lowPrice
  // quoteVolume -> quoteVolume
  // closeTime -> sourceTimestamp
  factory TickerState.fromRest24hr(Map<String, dynamic> json) {
    return TickerState(
      symbol: json['symbol'] as String? ?? '',
      openPrice: double.tryParse(json['openPrice']?.toString() ?? '') ?? 0.0,
      currentPrice: double.tryParse(json['lastPrice']?.toString() ?? '') ?? 0.0,
      highPrice: double.tryParse(json['highPrice']?.toString() ?? '') ?? 0.0,
      lowPrice: double.tryParse(json['lowPrice']?.toString() ?? '') ?? 0.0,
      quoteVolume: double.tryParse(json['quoteVolume']?.toString() ?? '') ?? 0.0,
      sourceTimestamp: json['closeTime'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  // Normalized from WebSocket !miniTicker@arr
  // s -> symbol
  // o -> openPrice
  // c -> currentPrice
  // h -> highPrice
  // l -> lowPrice
  // q -> quoteVolume
  // E -> sourceTimestamp
  factory TickerState.fromMiniTicker(Map<String, dynamic> json) {
    return TickerState(
      symbol: json['s'] as String? ?? '',
      openPrice: double.tryParse(json['o']?.toString() ?? '') ?? 0.0,
      currentPrice: double.tryParse(json['c']?.toString() ?? '') ?? 0.0,
      highPrice: double.tryParse(json['h']?.toString() ?? '') ?? 0.0,
      lowPrice: double.tryParse(json['l']?.toString() ?? '') ?? 0.0,
      quoteVolume: double.tryParse(json['q']?.toString() ?? '') ?? 0.0,
      sourceTimestamp: json['E'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

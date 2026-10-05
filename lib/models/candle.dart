/// Một cây nến (kline) của Binance Spot.
class Candle {
  final int openTime;
  final int closeTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double quoteVolume;
  final bool isClosed;

  const Candle({
    required this.openTime,
    required this.closeTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.quoteVolume,
    this.isClosed = true,
  });

  /// REST `/api/v3/klines` trả về mảng:
  /// [openTime, o, h, l, c, volume, closeTime, quoteVolume, trades, ...]
  factory Candle.fromRest(List<dynamic> a) {
    return Candle(
      openTime: (a[0] as num).toInt(),
      open: double.parse(a[1].toString()),
      high: double.parse(a[2].toString()),
      low: double.parse(a[3].toString()),
      close: double.parse(a[4].toString()),
      volume: double.parse(a[5].toString()),
      closeTime: (a[6] as num).toInt(),
      quoteVolume: double.parse(a[7].toString()),
      isClosed: true,
    );
  }

  /// WebSocket `<symbol>@kline_<interval>`: object `k` bên trong event.
  factory Candle.fromWsKline(Map<String, dynamic> k) {
    return Candle(
      openTime: (k['t'] as num).toInt(),
      closeTime: (k['T'] as num).toInt(),
      open: double.parse(k['o'].toString()),
      high: double.parse(k['h'].toString()),
      low: double.parse(k['l'].toString()),
      close: double.parse(k['c'].toString()),
      volume: double.parse(k['v'].toString()),
      quoteVolume: double.parse(k['q'].toString()),
      isClosed: k['x'] == true,
    );
  }

  bool get isUp => close >= open;

  /// % thay đổi của riêng cây nến (close so với open).
  double get changePercent => open > 0 ? (close - open) / open * 100 : 0;
}

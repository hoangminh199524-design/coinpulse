/// Khung thời gian của chart. [code] là giá trị Binance API chấp nhận.
enum ChartInterval {
  m1('1m', '1m', Duration(minutes: 1)),
  m3('3m', '3m', Duration(minutes: 3)),
  m5('5m', '5m', Duration(minutes: 5)),
  m15('15m', '15m', Duration(minutes: 15)),
  m30('30m', '30m', Duration(minutes: 30)),
  h1('1h', '1H', Duration(hours: 1)),
  h4('4h', '4H', Duration(hours: 4)),
  d1('1d', '1D', Duration(days: 1)),
  w1('1w', '1W', Duration(days: 7));

  final String code;
  final String label;
  final Duration duration;

  const ChartInterval(this.code, this.label, this.duration);

  int get milliseconds => duration.inMilliseconds;
}

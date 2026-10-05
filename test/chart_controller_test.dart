import 'package:flutter_test/flutter_test.dart';
import 'package:coin_pulse/models/candle.dart';
import 'package:coin_pulse/models/chart_interval.dart';
import 'package:coin_pulse/services/chart_controller.dart';

void main() {
  group('Candle Model Tests', () {
    test('fromRest parses Binance kline array correctly', () {
      final raw = [
        1499040000000, // 0: Open time
        "0.01634790",  // 1: Open
        "0.80000000",  // 2: High
        "0.01575800",  // 3: Low
        "0.01577100",  // 4: Close
        "148976.114",  // 5: Volume
        1499644799999, // 6: Close time
        "2434.19055",  // 7: Quote asset volume
        308,           // 8: Number of trades
        "1756.874",    // 9: Taker buy base asset volume
        "28.4669",     // 10: Taker buy quote asset volume
        "17928899.62"  // 11: Ignore
      ];

      final candle = Candle.fromRest(raw);
      expect(candle.openTime, 1499040000000);
      expect(candle.open, 0.01634790);
      expect(candle.high, 0.80000000);
      expect(candle.low, 0.01575800);
      expect(candle.close, 0.01577100);
      expect(candle.volume, 148976.114);
      expect(candle.closeTime, 1499644799999);
      expect(candle.quoteVolume, 2434.19055);
      expect(candle.isUp, false);
      expect(candle.changePercent, closeTo(-3.528, 0.01));
    });

    test('fromWsKline parses WebSocket kline event', () {
      final wsK = {
        "t": 123400000,
        "T": 123460000,
        "s": "BNBUSDT",
        "i": "1m",
        "f": 100,
        "L": 200,
        "o": "100.0",
        "c": "105.0",
        "h": "106.0",
        "l": "99.0",
        "v": "1000",
        "n": 100,
        "x": false,
        "q": "102500",
        "V": "500",
        "Q": "50000",
        "B": "123456"
      };

      final candle = Candle.fromWsKline(wsK);
      expect(candle.openTime, 123400000);
      expect(candle.closeTime, 123460000);
      expect(candle.open, 100.0);
      expect(candle.close, 105.0);
      expect(candle.high, 106.0);
      expect(candle.low, 99.0);
      expect(candle.volume, 1000.0);
      expect(candle.quoteVolume, 102500.0);
      expect(candle.isClosed, false);
      expect(candle.isUp, true);
      expect(candle.changePercent, 5.0);
    });
  });

  group('ChartInterval Tests', () {
    test('Intervals define correct codes and durations', () {
      expect(ChartInterval.m1.code, '1m');
      expect(ChartInterval.m15.code, '15m');
      expect(ChartInterval.h1.code, '1h');
      expect(ChartInterval.h4.code, '4h');
      expect(ChartInterval.d1.code, '1d');
      expect(ChartInterval.w1.code, '1w');
      expect(ChartInterval.m15.milliseconds, 15 * 60 * 1000);
      expect(ChartInterval.h1.milliseconds, 60 * 60 * 1000);
    });
  });

  group('ChartController Logic Tests', () {
    test('applyLiveCandle updates existing candle on same openTime', () {
      final controller = ChartController(symbol: 'BTCUSDT');
      const c1 = Candle(
        openTime: 1000,
        closeTime: 1999,
        open: 100,
        high: 105,
        low: 99,
        close: 102,
        volume: 10,
        quoteVolume: 1020,
      );
      controller.mergeCandles([c1]);
      expect(controller.candles.length, 1);
      expect(controller.candles.first.close, 102);

      // Realtime update: same openTime, price moved to 108
      const c1Update = Candle(
        openTime: 1000,
        closeTime: 1999,
        open: 100,
        high: 108,
        low: 99,
        close: 108,
        volume: 15,
        quoteVolume: 1550,
      );
      controller.applyLiveCandle(c1Update);
      expect(controller.candles.length, 1);
      expect(controller.candles.first.close, 108);
      expect(controller.candles.first.high, 108);

      // New candle arrived (openTime 2000)
      const c2 = Candle(
        openTime: 2000,
        closeTime: 2999,
        open: 108,
        high: 110,
        low: 107,
        close: 109,
        volume: 5,
        quoteVolume: 545,
      );
      controller.applyLiveCandle(c2);
      expect(controller.candles.length, 2);
      expect(controller.candles.last.openTime, 2000);
      expect(controller.candles.last.close, 109);
    });

    test('mergeCandles sorts and deduplicates candles properly', () {
      final controller = ChartController(symbol: 'ETHUSDT');
      final list1 = [
        const Candle(openTime: 1000, closeTime: 1999, open: 10, high: 12, low: 9, close: 11, volume: 1, quoteVolume: 11),
        const Candle(openTime: 3000, closeTime: 3999, open: 11, high: 13, low: 10, close: 12, volume: 1, quoteVolume: 12),
      ];
      controller.mergeCandles(list1);
      expect(controller.candles.length, 2);

      // Incoming list filling gap and updating item
      final list2 = [
        const Candle(openTime: 2000, closeTime: 2999, open: 11, high: 12, low: 10, close: 11, volume: 1, quoteVolume: 11),
        const Candle(openTime: 3000, closeTime: 3999, open: 11, high: 14, low: 10, close: 13.5, volume: 2, quoteVolume: 25),
      ];
      controller.mergeCandles(list2);

      expect(controller.candles.length, 3);
      expect(controller.candles[0].openTime, 1000);
      expect(controller.candles[1].openTime, 2000);
      expect(controller.candles[2].openTime, 3000);
      expect(controller.candles[2].close, 13.5); // updated
    });
  });
}

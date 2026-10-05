import 'package:flutter_test/flutter_test.dart';
import 'package:coin_pulse/models/candle.dart';
import 'package:coin_pulse/models/imbalance_zone.dart';
import 'package:coin_pulse/services/imbalance_detector.dart';

void main() {
  group('ImbalanceDetector Tests', () {
    Candle makeCandle({
      required int time,
      required double open,
      required double high,
      required double low,
      required double close,
      bool isClosed = true,
    }) {
      return Candle(
        openTime: time,
        closeTime: time + 59999,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: 100,
        quoteVolume: 1000,
        isClosed: isClosed,
      );
    }

    test('Detects Top Imbalance correctly', () {
      // Pattern:
      // c0 (t=1000): low=100
      // c1 (t=2000): open=102, close=90
      // c2 (t=3000): high=95
      // Condition:
      // c0.low <= c1.open (100 <= 102: true)
      // c2.high >= c1.close (95 >= 90: true)
      // size = c0.low - c2.high = 100 - 95 = 5 (> 0)
      // TopZone: top = c0.low (100), bottom = c2.high (95)
      final candles = [
        makeCandle(time: 1000, open: 105, high: 106, low: 100, close: 101),
        makeCandle(time: 2000, open: 102, high: 103, low: 89, close: 90),
        makeCandle(time: 3000, open: 92, high: 95, low: 85, close: 86),
      ];

      final zones = ImbalanceDetector.detect(candles);
      expect(zones.length, 1);
      final z = zones.first;
      expect(z.type, ImbalanceType.top);
      expect(z.topPrice, 100);
      expect(z.bottomPrice, 95);
      expect(z.startOpenTime, 3000);
      expect(z.endOpenTime, 3000);
      expect(z.active, true);
    });

    test('Detects Bottom Imbalance correctly', () {
      // Pattern:
      // c0 (t=1000): high=90
      // c1 (t=2000): open=88, close=100
      // c2 (t=3000): low=95
      // Condition:
      // c0.high >= c1.open (90 >= 88: true)
      // c2.low <= c1.close (95 <= 100: true)
      // size = c2.low - c0.high = 95 - 90 = 5 (> 0)
      // BottomZone: top = c2.low (95), bottom = c0.high (90)
      final candles = [
        makeCandle(time: 1000, open: 85, high: 90, low: 84, close: 89),
        makeCandle(time: 2000, open: 88, high: 101, low: 87, close: 100),
        makeCandle(time: 3000, open: 98, high: 105, low: 95, close: 104),
      ];

      final zones = ImbalanceDetector.detect(candles);
      expect(zones.length, 1);
      final z = zones.first;
      expect(z.type, ImbalanceType.bottom);
      expect(z.topPrice, 95);
      expect(z.bottomPrice, 90);
      expect(z.startOpenTime, 3000);
      expect(z.endOpenTime, 3000);
      expect(z.active, true);
    });

    test('Extends active zone until violated by new candle', () {
      // Create top imbalance (100 to 95) at t=3000
      // Next candle at t=4000: stays below zone (high=92, low=85) -> extends
      // Next candle at t=5000: crosses zone bottom (high=97, low=93) -> cuts off!
      final candles = [
        makeCandle(time: 1000, open: 105, high: 106, low: 100, close: 101),
        makeCandle(time: 2000, open: 102, high: 103, low: 89, close: 90),
        makeCandle(time: 3000, open: 92, high: 95, low: 85, close: 86),
        // t=4000: does not violate (high 92 < bottom 95)
        makeCandle(time: 4000, open: 86, high: 92, low: 85, close: 91),
        // t=5000: violates bottom (high 97 > bottom 95, low 93 < bottom 95)
        makeCandle(time: 5000, open: 91, high: 97, low: 93, close: 96),
        // t=6000: subsequent candle
        makeCandle(time: 6000, open: 96, high: 98, low: 95, close: 97),
      ];

      final zones = ImbalanceDetector.detect(candles);
      final z = zones.firstWhere((zone) => zone.startOpenTime == 3000);
      expect(z.startOpenTime, 3000);
      // Extended to 4000, then cut at 5000 (stopped at 4000)
      expect(z.endOpenTime, 4000);
      expect(z.active, false);
    });

    test('Enforces maxZones limit by discarding oldest', () {
      // Generate multiple zones
      final List<Candle> candles = [];
      for (int i = 0; i < 60; i++) {
        // alternating top and bottom imbalances
        candles.add(makeCandle(
          time: (i + 1) * 1000,
          open: 100.0 + (i % 2 == 0 ? 5 : -5),
          high: 110.0 + i,
          low: 90.0 + i,
          close: 100.0,
        ));
      }

      final zones = ImbalanceDetector.detect(candles, maxZones: 10);
      expect(zones.length, lessThanOrEqualTo(10));
    });

    test('Ignores unclosed candle if confirmedOnly is true', () {
      final candles = [
        makeCandle(time: 1000, open: 105, high: 106, low: 100, close: 101),
        makeCandle(time: 2000, open: 102, high: 103, low: 89, close: 90),
        makeCandle(time: 3000, open: 92, high: 95, low: 85, close: 86, isClosed: false),
      ];

      final zones = ImbalanceDetector.detect(candles, confirmedOnly: true);
      expect(zones.isEmpty, true);

      final zonesUnconfirmed = ImbalanceDetector.detect(candles, confirmedOnly: false);
      expect(zonesUnconfirmed.length, 1);
    });
  });
}

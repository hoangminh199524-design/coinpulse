import 'package:flutter_test/flutter_test.dart';
import 'package:coin_pulse/models/app_config.dart';
import 'package:coin_pulse/models/ranked_coin.dart';
import 'package:coin_pulse/models/symbol_info.dart';
import 'package:coin_pulse/models/ticker_state.dart';
import 'package:coin_pulse/services/ranking_engine.dart';
import 'package:coin_pulse/services/ticker_cache.dart';

void main() {
  group('TickerState Normalized Model', () {
    test('Calculates derived priceChangePercent and priceChangeAmount correctly', () {
      const ticker = TickerState(
        symbol: 'BTCUSDT',
        openPrice: 50000.0,
        currentPrice: 55000.0,
        highPrice: 56000.0,
        lowPrice: 49000.0,
        quoteVolume: 10000000.0,
        sourceTimestamp: 1000,
      );

      expect(ticker.priceChangeAmount, 5000.0);
      expect(ticker.priceChangePercent, 10.0);
      expect(ticker.isValid, isTrue);
    });

    test('Identifies invalid ticker if openPrice <= 0', () {
      const ticker = TickerState(
        symbol: 'ZEROUSDT',
        openPrice: 0.0,
        currentPrice: 10.0,
        highPrice: 10.0,
        lowPrice: 0.0,
        quoteVolume: 10000.0,
        sourceTimestamp: 1000,
      );

      expect(ticker.isValid, isFalse);
    });
  });

  group('TickerCache Merge Rule', () {
    test('Only merges incoming ticker if sourceTimestamp is newer', () {
      final cache = TickerCache();
      const t1 = TickerState(
        symbol: 'SUIUSDT',
        openPrice: 1.0,
        currentPrice: 1.5,
        highPrice: 1.6,
        lowPrice: 0.9,
        quoteVolume: 2000000.0,
        sourceTimestamp: 2000,
      );
      const tOld = TickerState(
        symbol: 'SUIUSDT',
        openPrice: 1.0,
        currentPrice: 1.2,
        highPrice: 1.3,
        lowPrice: 0.9,
        quoteVolume: 1000000.0,
        sourceTimestamp: 1500, // Older
      );
      const tNew = TickerState(
        symbol: 'SUIUSDT',
        openPrice: 1.0,
        currentPrice: 2.0,
        highPrice: 2.1,
        lowPrice: 0.9,
        quoteVolume: 5000000.0,
        sourceTimestamp: 2500, // Newer
      );

      expect(cache.mergeTicker(t1), isTrue);
      expect(cache.tickers['SUIUSDT']!.currentPrice, 1.5);

      // Stale event should not overwrite
      expect(cache.mergeTicker(tOld), isFalse);
      expect(cache.tickers['SUIUSDT']!.currentPrice, 1.5);

      // Newer event should overwrite
      expect(cache.mergeTicker(tNew), isTrue);
      expect(cache.tickers['SUIUSDT']!.currentPrice, 2.0);
    });
  });

  group('RankingEngine', () {
    late RankingEngine engine;
    late AppConfig config;

    setUp(() {
      engine = RankingEngine();
      config = const AppConfig(
        topN: 3,
        minQuoteVolume: 5000000.0,
      );
    });

    test('Filters out non-USDT, non-trading, leveraged, blacklist, and low volume', () {
      final symbols = {
        'BTCUSDT': const SymbolInfo(
          symbol: 'BTCUSDT',
          baseAsset: 'BTC',
          quoteAsset: 'USDT',
          status: 'TRADING',
          permissionSets: [['SPOT']],
          tickSize: 0.01,
        ),
        'USDCUSDT': const SymbolInfo(
          symbol: 'USDCUSDT',
          baseAsset: 'USDC', // Blacklist
          quoteAsset: 'USDT',
          status: 'TRADING',
          permissionSets: [['SPOT']],
          tickSize: 0.0001,
        ),
        'HALTUSDT': const SymbolInfo(
          symbol: 'HALTUSDT',
          baseAsset: 'HALT',
          quoteAsset: 'USDT',
          status: 'HALT', // Not TRADING
          permissionSets: [['SPOT']],
          tickSize: 0.01,
        ),
        'LEVUSDT': const SymbolInfo(
          symbol: 'LEVUSDT',
          baseAsset: 'LEV',
          quoteAsset: 'USDT',
          status: 'TRADING',
          permissionSets: [['LEVERAGED']], // Leveraged
          tickSize: 0.01,
        ),
        'LOWVOLUSDT': const SymbolInfo(
          symbol: 'LOWVOLUSDT',
          baseAsset: 'LOWVOL',
          quoteAsset: 'USDT',
          status: 'TRADING',
          permissionSets: [['SPOT']],
          tickSize: 0.01,
        ),
      };

      final tickers = {
        'BTCUSDT': const TickerState(
          symbol: 'BTCUSDT',
          openPrice: 50000.0,
          currentPrice: 55000.0, // +10%
          highPrice: 56000.0,
          lowPrice: 49000.0,
          quoteVolume: 50000000.0,
          sourceTimestamp: 1000,
        ),
        'USDCUSDT': const TickerState(
          symbol: 'USDCUSDT',
          openPrice: 1.0,
          currentPrice: 1.5,
          highPrice: 1.5,
          lowPrice: 1.0,
          quoteVolume: 50000000.0,
          sourceTimestamp: 1000,
        ),
        'HALTUSDT': const TickerState(
          symbol: 'HALTUSDT',
          openPrice: 1.0,
          currentPrice: 2.0,
          highPrice: 2.0,
          lowPrice: 1.0,
          quoteVolume: 50000000.0,
          sourceTimestamp: 1000,
        ),
        'LEVUSDT': const TickerState(
          symbol: 'LEVUSDT',
          openPrice: 1.0,
          currentPrice: 3.0,
          highPrice: 3.0,
          lowPrice: 1.0,
          quoteVolume: 50000000.0,
          sourceTimestamp: 1000,
        ),
        'LOWVOLUSDT': const TickerState(
          symbol: 'LOWVOLUSDT',
          openPrice: 1.0,
          currentPrice: 2.0,
          highPrice: 2.0,
          lowPrice: 1.0,
          quoteVolume: 100000.0, // Below 5M min volume
          sourceTimestamp: 1000,
        ),
      };

      final results = engine.computeRanking(
        symbols: symbols,
        tickers: tickers,
        config: config,
      );

      expect(results.length, 1);
      expect(results.first.symbol, 'BTCUSDT');
    });

    test('Tie-break: higher quote volume wins, then symbol alphabetically', () {
      final symbols = {
        'B_COIN': const SymbolInfo(
          symbol: 'B_COIN',
          baseAsset: 'B_COIN',
          quoteAsset: 'USDT',
          status: 'TRADING',
          permissionSets: [['SPOT']],
          tickSize: 0.01,
        ),
        'A_COIN': const SymbolInfo(
          symbol: 'A_COIN',
          baseAsset: 'A_COIN',
          quoteAsset: 'USDT',
          status: 'TRADING',
          permissionSets: [['SPOT']],
          tickSize: 0.01,
        ),
      };

      // Both have identical +10% gain and identical 10M volume
      final tickers = {
        'B_COIN': const TickerState(
          symbol: 'B_COIN',
          openPrice: 100.0,
          currentPrice: 110.0,
          highPrice: 110.0,
          lowPrice: 100.0,
          quoteVolume: 10000000.0,
          sourceTimestamp: 1000,
        ),
        'A_COIN': const TickerState(
          symbol: 'A_COIN',
          openPrice: 100.0,
          currentPrice: 110.0,
          highPrice: 110.0,
          lowPrice: 100.0,
          quoteVolume: 10000000.0,
          sourceTimestamp: 1000,
        ),
      };

      final results = engine.computeRanking(
        symbols: symbols,
        tickers: tickers,
        config: config,
      );

      expect(results.first.symbol, 'A_COIN'); // Alphabetical tie-break
      expect(results[1].symbol, 'B_COIN');
    });

    test('Baseline ranking has no NEW or movement badges; subsequent ticks track rank changes', () {
      final now = DateTime(2026, 10, 5, 10, 0, 0);

      final symbols = {
        'COIN_A': const SymbolInfo(
          symbol: 'COIN_A',
          baseAsset: 'A',
          quoteAsset: 'USDT',
          status: 'TRADING',
          permissionSets: [['SPOT']],
          tickSize: 0.01,
        ),
        'COIN_B': const SymbolInfo(
          symbol: 'COIN_B',
          baseAsset: 'B',
          quoteAsset: 'USDT',
          status: 'TRADING',
          permissionSets: [['SPOT']],
          tickSize: 0.01,
        ),
      };

      // First tick: A is #1 (+20%), B is #2 (+10%)
      final tickers1 = {
        'COIN_A': const TickerState(
          symbol: 'COIN_A',
          openPrice: 100.0,
          currentPrice: 120.0, // +20%
          highPrice: 120.0,
          lowPrice: 100.0,
          quoteVolume: 10000000.0,
          sourceTimestamp: 1000,
        ),
        'COIN_B': const TickerState(
          symbol: 'COIN_B',
          openPrice: 100.0,
          currentPrice: 110.0, // +10%
          highPrice: 110.0,
          lowPrice: 100.0,
          quoteVolume: 10000000.0,
          sourceTimestamp: 1000,
        ),
      };

      // Tick 1 (Baseline):
      final rank1 = engine.computeRanking(
        symbols: symbols,
        tickers: tickers1,
        config: config,
        now: now,
      );

      expect(rank1[0].symbol, 'COIN_A');
      expect(rank1[0].movement, isNull); // Baseline -> No NEW badge
      expect(rank1[1].symbol, 'COIN_B');
      expect(rank1[1].movement, isNull);

      // Tick 2 (After 4s): COIN_B surges to +30%, overtaking COIN_A
      final tickers2 = {
        'COIN_A': tickers1['COIN_A']!,
        'COIN_B': const TickerState(
          symbol: 'COIN_B',
          openPrice: 100.0,
          currentPrice: 130.0, // +30%
          highPrice: 130.0,
          lowPrice: 100.0,
          quoteVolume: 10000000.0,
          sourceTimestamp: 2000,
        ),
      };

      final rank2 = engine.computeRanking(
        symbols: symbols,
        tickers: tickers2,
        config: config,
        now: now.add(const Duration(seconds: 4)),
      );

      expect(rank2[0].symbol, 'COIN_B');
      expect(rank2[0].movement, isNotNull);
      expect(rank2[0].movement!.type, MovementType.up);
      expect(rank2[0].movement!.badgeText, '#2 → #1');

      expect(rank2[1].symbol, 'COIN_A');
      expect(rank2[1].movement, isNotNull);
      expect(rank2[1].movement!.type, MovementType.down);
      expect(rank2[1].movement!.badgeText, '#1 → #2');

      // Tick 3 (After 15s): 10-second window expired, badge should disappear if ranks stable
      final rank3 = engine.computeRanking(
        symbols: symbols,
        tickers: tickers2,
        config: config,
        now: now.add(const Duration(seconds: 15)),
      );

      expect(rank3[0].movement, isNull);
      expect(rank3[1].movement, isNull);
    });
  });
}

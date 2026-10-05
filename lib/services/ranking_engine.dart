import '../models/app_config.dart';
import '../models/ranked_coin.dart';
import '../models/symbol_info.dart';
import '../models/ticker_state.dart';

class RankingEngine {
  bool _hasBaseline = false;
  final Map<String, int> _previousRanks = {};
  final Map<String, RankMovement> _activeMovements = {};

  bool get hasBaseline => _hasBaseline;

  void resetBaseline() {
    _hasBaseline = false;
    _previousRanks.clear();
    _activeMovements.clear();
  }

  List<RankedCoin> computeRanking({
    required Map<String, SymbolInfo> symbols,
    required Map<String, TickerState> tickers,
    required AppConfig config,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    // 1. Filter symbols & tickers
    final List<MapEntry<SymbolInfo, TickerState>> qualified = [];

    for (final entry in tickers.entries) {
      final symbol = entry.key;
      final ticker = entry.value;

      final info = symbols[symbol];
      if (info == null) continue;

      // Filter: Quote asset
      if (info.quoteAsset.toUpperCase() != config.quoteAsset.toUpperCase()) {
        continue;
      }

      // Filter: Status == TRADING
      if (!info.isTrading) {
        continue;
      }

      // Filter: Not leveraged
      if (info.isLeveraged) {
        continue;
      }

      // Filter: Blacklist base assets
      if (config.blacklistBaseAssets.contains(info.baseAsset.toUpperCase())) {
        continue;
      }

      // Filter: Excluded symbols
      if (config.excludedSymbols.contains(info.symbol.toUpperCase())) {
        continue;
      }

      // Filter: Valid ticker
      if (!ticker.isValid) {
        continue;
      }

      // Filter: Minimum quote volume
      if (ticker.quoteVolume < config.minQuoteVolume) {
        continue;
      }

      qualified.add(MapEntry(info, ticker));
    }

    // 2. Sort by % 24h descending, tie-break by volume descending, then symbol ascending
    qualified.sort((a, b) {
      final pctA = a.value.priceChangePercent;
      final pctB = b.value.priceChangePercent;
      final pctCmp = pctB.compareTo(pctA);
      if (pctCmp != 0) return pctCmp;

      final volCmp = b.value.quoteVolume.compareTo(a.value.quoteVolume);
      if (volCmp != 0) return volCmp;

      return a.key.symbol.compareTo(b.key.symbol);
    });

    // 3. Take Top N
    final int count = qualified.length < config.topN ? qualified.length : config.topN;
    final topList = qualified.sublist(0, count);

    final Map<String, int> currentRanks = {};
    for (int i = 0; i < topList.length; i++) {
      currentRanks[topList[i].key.symbol] = i + 1;
    }

    // 4. Handle baseline and movement tracking
    final List<RankedCoin> result = [];

    if (!_hasBaseline) {
      // First ranking is baseline: no movements, no NEW badges
      _hasBaseline = true;
      _previousRanks.clear();
      _activeMovements.clear();

      for (int i = 0; i < topList.length; i++) {
        final rank = i + 1;
        final info = topList[i].key;
        final ticker = topList[i].value;
        _previousRanks[info.symbol] = rank;

        result.add(RankedCoin(
          rank: rank,
          symbol: info.symbol,
          baseAsset: info.baseAsset,
          openPrice: ticker.openPrice,
          currentPrice: ticker.currentPrice,
          highPrice: ticker.highPrice,
          lowPrice: ticker.lowPrice,
          quoteVolume: ticker.quoteVolume,
          priceChangeAmount: ticker.priceChangeAmount,
          priceChangePercent: ticker.priceChangePercent,
          tickSize: info.tickSize,
          sourceTimestamp: ticker.sourceTimestamp,
          movement: null,
        ));
      }
      return result;
    }

    // Subsequent rankings: check rank movement vs previous baseline
    for (int i = 0; i < topList.length; i++) {
      final rank = i + 1;
      final info = topList[i].key;
      final ticker = topList[i].value;
      final symbol = info.symbol;

      final prevRank = _previousRanks[symbol];
      RankMovement? activeMovement = _activeMovements[symbol];

      if (prevRank == null) {
        // Newly entered Top N
        activeMovement = RankMovement(
          oldRank: null,
          newRank: rank,
          type: MovementType.newEntry,
          timestamp: currentTime,
        );
        _activeMovements[symbol] = activeMovement;
      } else if (prevRank != rank) {
        // Changed rank
        final type = rank < prevRank ? MovementType.up : MovementType.down;
        activeMovement = RankMovement(
          oldRank: prevRank,
          newRank: rank,
          type: type,
          timestamp: currentTime,
        );
        _activeMovements[symbol] = activeMovement;
      } else {
        // Rank remained same, check if existing badge is still within 10 seconds
        if (activeMovement != null && !activeMovement.isVisible(currentTime)) {
          activeMovement = null;
          _activeMovements.remove(symbol);
        }
      }

      result.add(RankedCoin(
        rank: rank,
        symbol: info.symbol,
        baseAsset: info.baseAsset,
        openPrice: ticker.openPrice,
        currentPrice: ticker.currentPrice,
        highPrice: ticker.highPrice,
        lowPrice: ticker.lowPrice,
        quoteVolume: ticker.quoteVolume,
        priceChangeAmount: ticker.priceChangeAmount,
        priceChangePercent: ticker.priceChangePercent,
        tickSize: info.tickSize,
        sourceTimestamp: ticker.sourceTimestamp,
        movement: (activeMovement != null && activeMovement.isVisible(currentTime))
            ? activeMovement
            : null,
      ));
    }

    // Update previous ranks for next comparison
    _previousRanks.clear();
    _previousRanks.addAll(currentRanks);

    return result;
  }
}

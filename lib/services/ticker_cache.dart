import '../models/symbol_info.dart';
import '../models/ticker_state.dart';

class TickerCache {
  final Map<String, SymbolInfo> _symbols = {};
  final Map<String, TickerState> _tickers = {};

  Map<String, SymbolInfo> get symbols => Map.unmodifiable(_symbols);
  Map<String, TickerState> get tickers => Map.unmodifiable(_tickers);

  void setSymbols(List<SymbolInfo> symbolList) {
    _symbols.clear();
    for (final s in symbolList) {
      _symbols[s.symbol] = s;
    }
  }

  void seedTickers(List<TickerState> tickerList) {
    _tickers.clear();
    for (final t in tickerList) {
      _tickers[t.symbol] = t;
    }
  }

  /// Merges a normalized ticker into the cache.
  /// Only updates if incoming sourceTimestamp > existing.sourceTimestamp.
  /// Never modifies the SymbolInfo metadata.
  bool mergeTicker(TickerState incoming) {
    final existing = _tickers[incoming.symbol];
    if (existing == null || incoming.sourceTimestamp > existing.sourceTimestamp) {
      _tickers[incoming.symbol] = incoming;
      return true;
    }
    return false;
  }

  void clear() {
    _symbols.clear();
    _tickers.clear();
  }
}

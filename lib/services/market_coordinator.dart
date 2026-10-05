import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_config.dart';
import '../models/ranked_coin.dart';
import '../models/ticker_state.dart';
import '../storage/settings_repository.dart';
import 'binance_rest_service.dart';
import 'binance_ws_service.dart';
import 'ranking_engine.dart';
import 'ticker_cache.dart';
import 'alert_service.dart';

enum MarketConnectionStatus {
  loading,
  live,
  connecting,
  offline,
  empty,
}

class MarketCoordinator extends ChangeNotifier {
  final BinanceRestService _restService;
  final SettingsRepository _settingsRepository;
  final TickerCache _cache = TickerCache();
  final RankingEngine _rankingEngine = RankingEngine();

  BinanceWsService? _wsService;
  Timer? _uiRefreshTimer;
  DateTime? _lastSnapshotTime;

  AppConfig _config = const AppConfig();
  MarketConnectionStatus _status = MarketConnectionStatus.loading;
  List<RankedCoin> _rankedCoins = [];

  // Init buffer
  final List<TickerState> _initBuffer = [];
  bool _isSeeding = false;
  DateTime? _bufferStartTime;
  static const int maxBufferCount = 5000;
  static const Duration maxBufferDuration = Duration(seconds: 30);

  MarketCoordinator({
    BinanceRestService? restService,
    SettingsRepository? settingsRepository,
  })  : _restService = restService ?? BinanceRestService(),
        _settingsRepository = settingsRepository ?? SettingsRepository();

  AppConfig get config => _config;
  MarketConnectionStatus get status => _status;
  List<RankedCoin> get rankedCoins => List.unmodifiable(_rankedCoins);
  DateTime? get lastSnapshotTime => _lastSnapshotTime;

  Future<void> initialize() async {
    _config = await _settingsRepository.loadConfig();
    notifyListeners();

    unawaited(AlertService.instance.initialize());

    _startUiRefreshLoop();
    await startMarketFlow();
  }

  Future<void> updateConfig(AppConfig newConfig) async {
    _config = newConfig;
    await _settingsRepository.saveConfig(newConfig);
    _rankingEngine.resetBaseline(); // Reset baseline on config change
    _refreshRanking();
    notifyListeners();
  }

  void _startUiRefreshLoop() {
    _uiRefreshTimer?.cancel();
    // Refresh UI / ranking at ~1s interval as per specification
    _uiRefreshTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (_status == MarketConnectionStatus.live || _status == MarketConnectionStatus.empty) {
        _refreshRanking();
      }
    });
  }

  Future<void> startMarketFlow() async {
    _status = MarketConnectionStatus.loading;
    _isSeeding = true;
    _initBuffer.clear();
    _bufferStartTime = DateTime.now();
    notifyListeners();

    // 1. Open WebSocket to buffer events
    _wsService?.dispose();
    _wsService = BinanceWsService(
      onTickers: _onWsTickersReceived,
      onStatusChanged: _onWsStatusChanged,
    );
    _wsService!.connect();

    // 2. Fetch REST exchangeInfo & 24hr tickers
    try {
      final symbols = await _restService.fetchExchangeInfo();
      _cache.setSymbols(symbols);

      final restTickers = await _restService.fetch24hrTickers();
      _cache.seedTickers(restTickers);
      _lastSnapshotTime = DateTime.now();

      // 3. Apply buffered WS events (conditional timestamp merge)
      for (final event in _initBuffer) {
        _cache.mergeTicker(event);
      }
      _initBuffer.clear();
      _isSeeding = false;

      // 4. Compute initial ranking (first ranking becomes baseline)
      _refreshRanking();

      if (_rankedCoins.isEmpty) {
        _status = MarketConnectionStatus.empty;
      } else {
        _status = MarketConnectionStatus.live;
      }
      notifyListeners();
    } catch (e) {
      _isSeeding = false;
      _initBuffer.clear();
      _status = MarketConnectionStatus.offline;
      notifyListeners();
    }
  }

  void _onWsTickersReceived(List<TickerState> tickers) {
    if (_isSeeding) {
      // Check buffer limits: 30s or 5000 items
      final now = DateTime.now();
      if (_initBuffer.length >= maxBufferCount ||
          (_bufferStartTime != null && now.difference(_bufferStartTime!) > maxBufferDuration)) {
        // Exceeded buffer limits, abort current seed and retry
        _isSeeding = false;
        _initBuffer.clear();
        _status = MarketConnectionStatus.connecting;
        notifyListeners();
        Future.delayed(const Duration(seconds: 2), () {
          startMarketFlow();
        });
        return;
      }

      _initBuffer.addAll(tickers);
      return;
    }

    // Live merge
    bool anyUpdated = false;
    for (final ticker in tickers) {
      if (_cache.mergeTicker(ticker)) {
        anyUpdated = true;
      }
    }

    if (anyUpdated) {
      _lastSnapshotTime = DateTime.now();
    }
  }

  void _onWsStatusChanged(WsConnectionStatus wsStatus) {
    if (_isSeeding) return;

    switch (wsStatus) {
      case WsConnectionStatus.connected:
        if (_status != MarketConnectionStatus.live) {
          _status = _rankedCoins.isEmpty ? MarketConnectionStatus.empty : MarketConnectionStatus.live;
          notifyListeners();
        }
        break;
      case WsConnectionStatus.connecting:
        if (_status != MarketConnectionStatus.connecting) {
          _status = MarketConnectionStatus.connecting;
          notifyListeners();
        }
        break;
      case WsConnectionStatus.disconnected:
        if (_status != MarketConnectionStatus.offline) {
          _status = MarketConnectionStatus.offline;
          notifyListeners();
        }
        break;
    }
  }

  void _refreshRanking() {
    final coins = _rankingEngine.computeRanking(
      symbols: _cache.symbols,
      tickers: _cache.tickers,
      config: _config,
    );

    _rankedCoins = coins;

    // Trigger alerts for any coin crossing configured milestone thresholds
    AlertService.instance.evaluateCoins(
      coins,
      thresholds: _config.alertThresholds,
      config: _config,
    );

    if (_status == MarketConnectionStatus.live && coins.isEmpty) {
      _status = MarketConnectionStatus.empty;
    } else if (_status == MarketConnectionStatus.empty && coins.isNotEmpty) {
      _status = MarketConnectionStatus.live;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _wsService?.dispose();
    _restService.dispose();
    super.dispose();
  }
}

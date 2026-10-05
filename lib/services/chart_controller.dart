import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/candle.dart';
import '../models/chart_interval.dart';
import '../models/imbalance_zone.dart';
import 'binance_rest_service.dart';
import 'imbalance_detector.dart';
import 'kline_ws_service.dart';

enum ChartStatus { loading, ready, error }

/// Quản lý dữ liệu chart của MỘT coin: load nến lịch sử (REST), nhận nến
/// realtime (WebSocket kline), load thêm khi kéo về quá khứ, đổi interval,
/// và tính toán Imbalance zones (OFIF).
class ChartController extends ChangeNotifier {
  static const int pageSize = 500;

  final String symbol;
  final BinanceRestService _rest;
  final bool _ownsRest;

  ChartInterval _interval;
  List<Candle> _candles = [];
  List<ImbalanceZone> _imbalanceZones = [];
  bool _showImbalance = true;
  ChartStatus _status = ChartStatus.loading;
  bool _loadingMore = false;
  bool _reachedStart = false;
  bool _liveConnected = false;
  bool _hasConnectedOnce = false;
  int _serverOffsetMs = 0;
  int _generation = 0;
  int _lastLoadMoreFailure = 0;
  bool _disposed = false;
  KlineWsService? _ws;

  ChartController({
    required this.symbol,
    ChartInterval interval = ChartInterval.m15,
    BinanceRestService? rest,
  })  : _interval = interval,
        _rest = rest ?? BinanceRestService(),
        _ownsRest = rest == null;

  ChartInterval get interval => _interval;
  List<Candle> get candles => _candles;
  List<ImbalanceZone> get imbalanceZones => _imbalanceZones;
  bool get showImbalance => _showImbalance;
  ChartStatus get status => _status;
  bool get loadingMore => _loadingMore;
  bool get reachedStart => _reachedStart;
  bool get liveConnected => _liveConnected;

  void toggleImbalance() {
    _showImbalance = !_showImbalance;
    _notify();
  }

  void _recalculateImbalances() {
    if (_candles.length < 3) {
      _imbalanceZones = [];
    } else {
      _imbalanceZones = ImbalanceDetector.detect(
        _candles,
        maxZones: 50,
        confirmedOnly: true,
      );
    }
  }

  /// Giờ Binance ước lượng (đã bù lệch đồng hồ máy) — dùng cho countdown nến.
  int get serverNowMs => DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;

  Future<void> start() => _load();

  Future<void> reload() => _load();

  Future<void> setInterval(ChartInterval value) async {
    if (value == _interval && _status != ChartStatus.error) return;
    _interval = value;
    await _load();
  }

  Future<void> _load() async {
    final gen = ++_generation;
    _ws?.dispose();
    _ws = null;
    _candles = [];
    _reachedStart = false;
    _loadingMore = false;
    _liveConnected = false;
    _hasConnectedOnce = false;
    _status = ChartStatus.loading;
    _notify();

    try {
      final data = await _rest.fetchKlines(
        symbol: symbol,
        interval: _interval.code,
        limit: pageSize,
      );
      if (_disposed || gen != _generation) return;
      _candles = data;
      _recalculateImbalances();
      _status = data.isEmpty ? ChartStatus.error : ChartStatus.ready;
      _notify();
      if (data.isNotEmpty) _connectWs(gen);
    } catch (_) {
      if (_disposed || gen != _generation) return;
      _status = ChartStatus.error;
      _notify();
    }
  }

  void _connectWs(int gen) {
    _ws = KlineWsService(
      symbol: symbol,
      interval: _interval.code,
      onCandle: (candle, serverTime) {
        if (_disposed || gen != _generation) return;
        _serverOffsetMs = serverTime - DateTime.now().millisecondsSinceEpoch;
        applyLiveCandle(candle);
      },
      onStatus: (connected) {
        if (_disposed || gen != _generation) return;
        final reconnected = connected && _hasConnectedOnce;
        _liveConnected = connected;
        if (connected) _hasConnectedOnce = true;
        _notify();
        // Sau khi nối lại: bù các nến bị lỡ trong lúc mất kết nối.
        if (reconnected) _resync(gen);
      },
    )..connect();
  }

  Future<void> _resync(int gen) async {
    try {
      final fresh = await _rest.fetchKlines(
        symbol: symbol,
        interval: _interval.code,
        limit: 200,
      );
      if (_disposed || gen != _generation) return;
      mergeCandles(fresh);
    } catch (_) {
      // WebSocket vẫn đang chạy; lần reconnect sau sẽ thử lại.
    }
  }

  /// Áp một cây nến realtime: cập nhật nến hiện tại hoặc thêm nến mới.
  @visibleForTesting
  void applyLiveCandle(Candle c) {
    if (_candles.isEmpty) return;
    final last = _candles.last;
    if (c.openTime == last.openTime) {
      _candles[_candles.length - 1] = c;
    } else if (c.openTime > last.openTime) {
      _candles.add(c);
      _recalculateImbalances();
    } else {
      return; // event cũ hơn dữ liệu hiện có
    }
    _notify();
  }

  /// Cập nhật giá nến hiện tại từ luồng ticker nếu chưa nhận được live kline
  void updateLivePrice(double currentPrice) {
    if (currentPrice <= 0 || _candles.isEmpty) return;
    final last = _candles.last;
    if (!last.isClosed && (last.close - currentPrice).abs() > 0.00000001) {
      _candles[_candles.length - 1] = Candle(
        openTime: last.openTime,
        closeTime: last.closeTime,
        open: last.open,
        high: currentPrice > last.high ? currentPrice : last.high,
        low: currentPrice < last.low ? currentPrice : last.low,
        close: currentPrice,
        volume: last.volume,
        quoteVolume: last.quoteVolume,
        isClosed: false,
      );
      _notify();
    }
  }

  /// Gộp danh sách nến mới vào dữ liệu hiện có theo openTime.
  @visibleForTesting
  void mergeCandles(List<Candle> incoming) {
    if (incoming.isEmpty) return;
    final byTime = <int, Candle>{for (final c in _candles) c.openTime: c};
    for (final c in incoming) {
      byTime[c.openTime] = c;
    }
    final keys = byTime.keys.toList()..sort();
    _candles = [for (final k in keys) byTime[k]!];
    _recalculateImbalances();
    _notify();
  }

  /// Load thêm nến cũ hơn khi người dùng kéo về quá khứ.
  Future<void> loadOlder() async {
    if (_loadingMore ||
        _reachedStart ||
        _candles.isEmpty ||
        _status != ChartStatus.ready) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastLoadMoreFailure < 3000) return;

    final gen = _generation;
    _loadingMore = true;
    _notify();

    try {
      final firstOpen = _candles.first.openTime;
      final older = await _rest.fetchKlines(
        symbol: symbol,
        interval: _interval.code,
        limit: pageSize,
        endTime: firstOpen - 1,
      );
      if (_disposed || gen != _generation) return;
      final fresh = older.where((c) => c.openTime < firstOpen).toList();
      if (fresh.length < pageSize) _reachedStart = true;
      if (fresh.isNotEmpty) {
        _candles = [...fresh, ..._candles];
        _recalculateImbalances();
      }
    } catch (_) {
      _lastLoadMoreFailure = DateTime.now().millisecondsSinceEpoch;
    } finally {
      if (!_disposed && gen == _generation) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ws?.dispose();
    if (_ownsRest) _rest.dispose();
    super.dispose();
  }
}

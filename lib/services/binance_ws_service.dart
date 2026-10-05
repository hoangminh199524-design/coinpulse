import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/ticker_state.dart';

enum WsConnectionStatus {
  connecting,
  connected,
  disconnected,
}

class BinanceWsService {
  static const List<String> endpoints = [
    'wss://stream.binance.com:9443/ws/!miniTicker@arr',
    'wss://stream.binance.com/ws/!miniTicker@arr',
    'wss://data-stream.binance.vision/ws/!miniTicker@arr',
  ];

  int _currentEndpointIndex = 0;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _watchdogTimer;
  Timer? _reconnectTimer;
  Timer? _proactive24hTimer;

  final Duration watchdogTimeout;
  final void Function(List<TickerState> tickers) onTickers;
  final void Function(WsConnectionStatus status) onStatusChanged;

  int _reconnectAttempts = 0;
  bool _isDisposed = false;
  final Random _random = Random();

  BinanceWsService({
    this.watchdogTimeout = const Duration(seconds: 10),
    required this.onTickers,
    required this.onStatusChanged,
  });

  String get currentEndpoint => endpoints[_currentEndpointIndex];

  void _rotateEndpoint() {
    _currentEndpointIndex = (_currentEndpointIndex + 1) % endpoints.length;
  }

  void connect() {
    if (_isDisposed) return;
    _cleanUpCurrentConnection();

    onStatusChanged(WsConnectionStatus.connecting);

    try {
      final uri = Uri.parse(currentEndpoint);
      _channel = WebSocketChannel.connect(uri);

      _resetWatchdog();
      _start24hProactiveReconnect();

      _channel!.ready.then((_) {
        if (!_isDisposed) {
          onStatusChanged(WsConnectionStatus.connected);
          _reconnectAttempts = 0;
        }
      }).catchError((_) {
        _handleDisconnect();
      });

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _onMessage(dynamic rawMessage) {
    if (_isDisposed) return;
    _resetWatchdog();

    try {
      final decoded = jsonDecode(rawMessage.toString());
      if (decoded is List) {
        final List<TickerState> tickers = [];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            tickers.add(TickerState.fromMiniTicker(item));
          }
        }
        if (tickers.isNotEmpty) {
          onTickers(tickers);
        }
      }
    } catch (_) {
      // Ignore malformed individual frame
    }
  }

  void _resetWatchdog() {
    _watchdogTimer?.cancel();
    if (_isDisposed) return;

    _watchdogTimer = Timer(watchdogTimeout, () {
      // Watchdog triggered: stream is stale
      _rotateEndpoint();
      _handleDisconnect();
    });
  }

  void _start24hProactiveReconnect() {
    _proactive24hTimer?.cancel();
    // Proactively reconnect after 23 hours 50 minutes
    _proactive24hTimer = Timer(const Duration(hours: 23, minutes: 50), () {
      connect();
    });
  }

  void _handleDisconnect() {
    if (_isDisposed) return;
    _cleanUpCurrentConnection();
    onStatusChanged(WsConnectionStatus.disconnected);

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_isDisposed) return;

    // Exponential backoff with jitter: min 1s, max 30s
    final baseSeconds = min(pow(2, _reconnectAttempts).toInt(), 30);
    final jitterMs = _random.nextInt(1000);
    final delay = Duration(seconds: baseSeconds, milliseconds: jitterMs);

    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  void _cleanUpCurrentConnection() {
    _watchdogTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _isDisposed = true;
    _watchdogTimer?.cancel();
    _reconnectTimer?.cancel();
    _proactive24hTimer?.cancel();
    _cleanUpCurrentConnection();
  }
}

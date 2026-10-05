import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/candle.dart';

/// Kết nối WebSocket kline của MỘT symbol + interval (`<symbol>@kline_<interval>`).
/// Tự reconnect với exponential backoff + jitter, xoay endpoint khi lỗi.
class KlineWsService {
  static const List<String> hosts = [
    'wss://stream.binance.com:9443/ws',
    'wss://stream.binance.com/ws',
    'wss://data-stream.binance.vision/ws',
  ];

  final String symbol;
  final String interval;

  /// [serverTime] là event time `E` của Binance (ms), dùng để căn countdown.
  final void Function(Candle candle, int serverTime) onCandle;
  final void Function(bool connected) onStatus;

  int _hostIndex = 0;
  int _attempts = 0;
  bool _disposed = false;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  final Random _random = Random();

  KlineWsService({
    required this.symbol,
    required this.interval,
    required this.onCandle,
    required this.onStatus,
  });

  String get _url => '${hosts[_hostIndex]}/${symbol.toLowerCase()}@kline_$interval';

  void connect() {
    if (_disposed) return;
    _cleanUp();

    try {
      // pingInterval giúp phát hiện connection chết (half-open) và đóng để reconnect.
      final channel = IOWebSocketChannel.connect(
        Uri.parse(_url),
        pingInterval: const Duration(seconds: 15),
      );
      _channel = channel;

      channel.ready.then((_) {
        if (_disposed || _channel != channel) return;
        _attempts = 0;
        onStatus(true);
      }).catchError((_) {
        if (_channel == channel) _handleDisconnect();
      });

      _sub = channel.stream.listen(
        _onMessage,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is Map<String, dynamic> && decoded['e'] == 'kline') {
        final k = decoded['k'];
        if (k is Map<String, dynamic>) {
          onCandle(
            Candle.fromWsKline(k),
            (decoded['E'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
          );
        }
      }
    } catch (_) {
      // Bỏ qua frame lỗi
    }
  }

  void _handleDisconnect() {
    if (_disposed) return;
    _cleanUp();
    onStatus(false);
    _hostIndex = (_hostIndex + 1) % hosts.length;

    final baseSeconds = min(pow(2, _attempts).toInt(), 20);
    final delay = Duration(
      seconds: baseSeconds,
      milliseconds: _random.nextInt(800),
    );
    _attempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, connect);
  }

  void _cleanUp() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _cleanUp();
  }
}

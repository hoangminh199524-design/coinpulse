import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/candle.dart';

/// Kết nối WebSocket kline của MỘT symbol + interval (`<symbol>@kline_<interval>`).
/// Tự reconnect với exponential backoff + jitter, xoay endpoint khi lỗi.
class KlineWsService {
  static const List<String> hosts = [
    'wss://stream.binance.com:9443/stream?streams=',
    'wss://data-stream.binance.vision/stream?streams=',
    'wss://stream.binance.com/stream?streams=',
  ];

  final String symbol;
  final String interval;

  /// [serverTime] là event time `E` của Binance (ms), dùng để căn countdown.
  final void Function(Candle candle, int serverTime) onCandle;
  final void Function(double price, int serverTime)? onTrade;
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
    this.onTrade,
    required this.onStatus,
  });

  String get _url {
    final sym = symbol.toLowerCase();
    final base = hosts[_hostIndex];
    if (base.contains('streams=')) {
      return '$base$sym@kline_$interval/$sym@aggTrade';
    } else {
      return '$base/$sym@kline_$interval';
    }
  }

  void connect() {
    if (_disposed) return;
    _cleanUp();

    try {
      final channel = WebSocketChannel.connect(Uri.parse(_url));
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
      if (decoded is! Map<String, dynamic>) return;

      // Hỗ trợ cả Combined Streams (`stream` + `data`) và Raw Stream
      final Map<String, dynamic> data = (decoded['data'] is Map<String, dynamic>)
          ? decoded['data'] as Map<String, dynamic>
          : decoded;

      final eventType = data['e'];
      if (eventType == 'kline') {
        _attempts = 0;
        onStatus(true);
        final k = data['k'];
        if (k is Map<String, dynamic>) {
          onCandle(
            Candle.fromWsKline(k),
            (data['E'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
          );
        }
      } else if (eventType == 'aggTrade') {
        _attempts = 0;
        onStatus(true);
        final p = double.tryParse(data['p']?.toString() ?? '') ?? 0.0;
        if (p > 0 && onTrade != null) {
          onTrade!(
            p,
            (data['E'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
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

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/candle.dart';
import '../models/symbol_info.dart';
import '../models/ticker_state.dart';

class BinanceRestService {
  static const List<String> hosts = [
    'https://api.binance.com',
    'https://api1.binance.com',
    'https://api2.binance.com',
    'https://api3.binance.com',
    'https://data-api.binance.vision',
  ];

  int _currentHostIndex = 0;
  final http.Client _client;

  BinanceRestService({http.Client? client}) : _client = client ?? http.Client();

  String get currentHost => hosts[_currentHostIndex];

  void _rotateHost() {
    _currentHostIndex = (_currentHostIndex + 1) % hosts.length;
  }

  Future<http.Response> _getWithFallback(String path) async {
    int attempts = 0;
    while (attempts < hosts.length) {
      final url = Uri.parse('$currentHost$path');
      try {
        final response = await _client.get(url).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          return response;
        }
      } catch (_) {
        // Fallback to next host on network or timeout failure
      }
      _rotateHost();
      attempts++;
    }
    throw Exception('Failed to connect to any Binance REST host');
  }

  /// Fetches exchangeInfo and parses symbols metadata
  Future<List<SymbolInfo>> fetchExchangeInfo() async {
    final response = await _getWithFallback('/api/v3/exchangeInfo');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final symbolsList = data['symbols'] as List? ?? [];

    return symbolsList
        .whereType<Map<String, dynamic>>()
        .map((s) => SymbolInfo.fromJson(s))
        .toList();
  }

  /// Fetches 24hr tickers for all symbols and normalizes to TickerState
  Future<List<TickerState>> fetch24hrTickers() async {
    final response = await _getWithFallback('/api/v3/ticker/24hr');
    final list = jsonDecode(response.body) as List? ?? [];

    return list
        .whereType<Map<String, dynamic>>()
        .map((t) => TickerState.fromRest24hr(t))
        .toList();
  }

  /// Fetches candles (oldest → newest). [endTime] (ms) lấy các nến có
  /// openTime <= endTime, dùng để load thêm lịch sử khi kéo về quá khứ.
  Future<List<Candle>> fetchKlines({
    required String symbol,
    required String interval,
    int limit = 500,
    int? endTime,
  }) async {
    final query = StringBuffer(
        '/api/v3/klines?symbol=$symbol&interval=$interval&limit=$limit');
    if (endTime != null) query.write('&endTime=$endTime');

    final response = await _getWithFallback(query.toString());
    final list = jsonDecode(response.body) as List? ?? [];

    return list
        .whereType<List<dynamic>>()
        .map((a) => Candle.fromRest(a))
        .toList();
  }

  void dispose() {
    _client.close();
  }
}

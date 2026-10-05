import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/ranked_coin.dart';

class AlertService {
  static const MethodChannel _channel = MethodChannel('com.coinpulse.coin_pulse/service');

  // Track which milestone thresholds have already been triggered for each symbol
  final Map<String, Set<double>> _triggeredThresholds = {};

  static final AlertService instance = AlertService._internal();
  AlertService._internal();

  /// Initialize background service and request notification permissions on Android
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
      await _channel.invokeMethod('startBackgroundService');
      debugPrint('[AlertService] Background service initialized successfully.');
    } catch (e) {
      debugPrint('[AlertService] Error initializing background service: $e');
    }
  }

  /// Evaluates coins against all user-configured milestone thresholds
  void evaluateCoins(List<RankedCoin> coins, {List<double> thresholds = const [15.0, 20.0]}) {
    if (thresholds.isEmpty) return;
    final sortedThresholds = List<double>.from(thresholds)..sort();

    for (final coin in coins) {
      final percent = coin.priceChangePercent;
      final symbol = coin.symbol;
      final triggered = _triggeredThresholds.putIfAbsent(symbol, () => <double>{});

      for (final milestone in sortedThresholds) {
        if (percent >= milestone) {
          if (!triggered.contains(milestone)) {
            triggered.add(milestone);
            _sendAlert(
              title: '🚀 ${coin.baseAsset}/USDT chạm mốc +${milestone.toStringAsFixed(0)}%! (+${percent.toStringAsFixed(2)}%)',
              message: 'Giá: \$${coin.formattedPrice} • 24h Vol: ${coin.formattedVolume}',
              id: (symbol.hashCode ^ milestone.hashCode).abs() % 100000,
            );
          }
        } else if (percent < milestone - 2.0 || percent < milestone * 0.9) {
          // If price pulled back below milestone, reset it so future pump alerts again
          triggered.remove(milestone);
        }
      }
    }
  }

  Future<void> _sendAlert({
    required String title,
    required String message,
    required int id,
  }) async {
    try {
      await _channel.invokeMethod('sendGainAlert', {
        'title': title,
        'message': message,
        'id': id,
      });
      debugPrint('[AlertService] Sent alert for: $title');
    } catch (e) {
      debugPrint('[AlertService] Error sending alert: $e');
    }
  }
}

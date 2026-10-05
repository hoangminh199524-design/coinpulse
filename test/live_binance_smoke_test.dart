import 'package:flutter_test/flutter_test.dart';
import 'package:coin_pulse/services/binance_rest_service.dart';

void main() {
  test('Live Binance REST API connectivity test', () async {
    final rest = BinanceRestService();

    // 1. Fetch exchangeInfo
    final symbols = await rest.fetchExchangeInfo();
    expect(symbols, isNotEmpty);
    final btc = symbols.firstWhere((s) => s.symbol == 'BTCUSDT');
    expect(btc.baseAsset, 'BTC');
    expect(btc.quoteAsset, 'USDT');
    expect(btc.status, 'TRADING');

    // 2. Fetch 24hr tickers
    final tickers = await rest.fetch24hrTickers();
    expect(tickers, isNotEmpty);
    final btcTicker = tickers.firstWhere((t) => t.symbol == 'BTCUSDT');
    expect(btcTicker.currentPrice, greaterThan(0.0));
    expect(btcTicker.openPrice, greaterThan(0.0));
    expect(btcTicker.quoteVolume, greaterThan(0.0));
    expect(btcTicker.priceChangePercent.isFinite, isTrue);

    rest.dispose();
  });
}

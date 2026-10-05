import 'package:flutter/material.dart';
import '../models/ranked_coin.dart';
import '../services/chart_controller.dart';
import '../services/market_coordinator.dart';
import 'chart_fullscreen_screen.dart';
import 'widgets/candle_chart.dart';
import 'widgets/interval_selector.dart';

/// Coin Detail: thông tin 24H + chart nến realtime.
class CoinDetailScreen extends StatefulWidget {
  final RankedCoin coin;
  final MarketCoordinator coordinator;

  const CoinDetailScreen({
    super.key,
    required this.coin,
    required this.coordinator,
  });

  @override
  State<CoinDetailScreen> createState() => _CoinDetailScreenState();
}

class _CoinDetailScreenState extends State<CoinDetailScreen> {
  late final ChartController _chart;

  @override
  void initState() {
    super.initState();
    _chart = ChartController(symbol: widget.coin.symbol)..start();
  }

  @override
  void dispose() {
    _chart.dispose();
    super.dispose();
  }

  /// Lấy số liệu 24H mới nhất từ bảng xếp hạng; nếu coin đã rớt khỏi Top N
  /// thì dùng snapshot lúc mở màn hình.
  RankedCoin _latestCoin() {
    for (final c in widget.coordinator.rankedCoins) {
      if (c.symbol == widget.coin.symbol) return c;
    }
    return widget.coin;
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChartFullScreen(
          controller: _chart,
          coin: _latestCoin(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A22),
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.coin.baseAsset}/USDT',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const Text(
              'Binance Spot',
              style: TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('open_fullscreen'),
            icon: const Icon(Icons.fullscreen, color: Color(0xFFC9D1D9), size: 28),
            tooltip: 'Toàn màn hình (xoay ngang)',
            onPressed: _openFullScreen,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([widget.coordinator, _chart]),
        builder: (context, _) {
          final coin = _latestCoin();
          if (!_chart.liveConnected && coin.currentPrice > 0) {
            _chart.updateLivePrice(coin.currentPrice);
          }
          final candles = _chart.candles;
          final livePrice = (_chart.liveConnected && candles.isNotEmpty)
              ? candles.last.close
              : coin.currentPrice;
          final double livePercent = (coin.openPrice > 0 && livePrice > 0)
              ? ((livePrice - coin.openPrice) / coin.openPrice) * 100
              : coin.priceChangePercent;
          final isPositive = livePercent >= 0;
          final changeColor = isPositive ? kCandleUp : kCandleDown;

          return Column(
            children: [
              _buildHeader(coin, livePrice, livePercent, changeColor),
              Container(
                color: const Color(0xFF161A22),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: IntervalSelector(
                        selected: _chart.interval,
                        onSelected: _chart.setInterval,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildImbalanceChip(_chart),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11151C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF262D3D), width: 0.8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CandleChart(
                    key: ValueKey('detail_${_chart.interval.code}'),
                    controller: _chart,
                    pricePrecision: coin.pricePrecision,
                  ),
                ),
              ),
              _buildFooter(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(RankedCoin coin, double price, double livePercent, Color changeColor) {
    final liveHigh = price > coin.highPrice ? price : coin.highPrice;
    final liveLow = (price < coin.lowPrice && price > 0) ? price : coin.lowPrice;

    return Container(
      width: double.infinity,
      color: const Color(0xFF161A22),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '\$${price.toStringAsFixed(coin.pricePrecision)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${livePercent >= 0 ? '+' : ''}${livePercent.toStringAsFixed(2)}%  24H',
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _stat('Cao 24H', liveHigh.toStringAsFixed(coin.pricePrecision)),
              _stat('Thấp 24H', liveLow.toStringAsFixed(coin.pricePrecision)),
              _stat('Vol 24H', coin.formattedVolume),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF6E7B8B), fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE6EDF3),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final live = _chart.liveConnected;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: live ? const Color(0xFF00E676) : const Color(0xFFFFB300),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              live ? 'TRỰC TIẾP' : 'ĐANG KẾT NỐI...',
              style: TextStyle(
                color: live ? const Color(0xFF00E676) : const Color(0xFFFFB300),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Chạm: crosshair • Kéo: lịch sử • Chụm: zoom',
              style: TextStyle(color: Color(0xFF6E7B8B), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImbalanceChip(ChartController chart) {
    final active = chart.showImbalance;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('toggle_imbalance'),
        borderRadius: BorderRadius.circular(8),
        onTap: chart.toggleImbalance,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF00B0FF).withValues(alpha: 0.16)
                : const Color(0xFF161A22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? const Color(0xFF00B0FF).withValues(alpha: 0.7)
                  : const Color(0xFF262D3D),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.layers : Icons.layers_outlined,
                size: 15,
                color: active ? const Color(0xFF00B0FF) : const Color(0xFF8B949E),
              ),
              const SizedBox(width: 4),
              Text(
                'OFIF',
                style: TextStyle(
                  color: active ? const Color(0xFF00B0FF) : const Color(0xFF8B949E),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

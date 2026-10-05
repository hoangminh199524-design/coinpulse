import 'package:flutter/material.dart';
import '../../models/ranked_coin.dart';
import '../../services/market_coordinator.dart';
import 'coin_detail_screen.dart';
import 'settings_screen.dart';
import 'widgets/coin_card.dart';
import 'widgets/status_badge.dart';

class HomeScreen extends StatelessWidget {
  final MarketCoordinator coordinator;

  const HomeScreen({
    super.key,
    required this.coordinator,
  });

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          initialConfig: coordinator.config,
          onSave: (newConfig) {
            coordinator.updateConfig(newConfig);
          },
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, RankedCoin coin) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoinDetailScreen(coin: coin, coordinator: coordinator),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: coordinator,
      builder: (context, _) {
        final status = coordinator.status;
        final coins = coordinator.rankedCoins;
        final lastTime = coordinator.lastSnapshotTime;

        return Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          appBar: AppBar(
            backgroundColor: const Color(0xFF161A22),
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Top Tăng Trưởng',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      status: status,
                      lastSnapshotTime: lastTime,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Binance • USDT • Biến Động 24H',
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
                icon: const Icon(Icons.settings_outlined, color: Color(0xFFC9D1D9)),
                tooltip: 'Cài đặt',
                onPressed: () => _openSettings(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: RefreshIndicator(
            color: const Color(0xFF00E676),
            backgroundColor: const Color(0xFF161A22),
            onRefresh: () async {
              await coordinator.startMarketFlow();
            },
            child: _buildBody(context, status, coins),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    MarketConnectionStatus status,
    List<RankedCoin> coins,
  ) {
    if (status == MarketConnectionStatus.loading && coins.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF00E676)),
            SizedBox(height: 16),
            Text(
              'Đang tải dữ liệu thị trường Binance...',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (coins.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 380,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    status == MarketConnectionStatus.offline
                        ? Icons.cloud_off_outlined
                        : Icons.filter_alt_off_outlined,
                    size: 54,
                    color: const Color(0xFF484F58),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    status == MarketConnectionStatus.offline
                        ? 'Không thể kết nối tới Binance'
                        : 'Không có coin nào khớp bộ lọc',
                    style: const TextStyle(
                      color: Color(0xFFC9D1D9),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status == MarketConnectionStatus.offline
                        ? 'Kiểm tra mạng hoặc kéo xuống để thử lại'
                        : 'Thử giảm khối lượng 24h tối thiểu trong Cài đặt',
                    style: const TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 10, bottom: 24),
      itemCount: coins.length,
      itemBuilder: (context, index) {
        final coin = coins[index];
        return CoinCard(
          key: ValueKey(coin.symbol),
          coin: coin,
          onTap: () => _openDetail(context, coin),
        );
      },
    );
  }
}

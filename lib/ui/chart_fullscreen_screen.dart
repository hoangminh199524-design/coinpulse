import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ranked_coin.dart';
import '../services/chart_controller.dart';
import 'widgets/candle_chart.dart';
import 'widgets/interval_selector.dart';

/// Chart toàn màn hình xoay ngang. Dùng chung [ChartController] với màn Detail
/// nên dữ liệu realtime không bị gián đoạn khi chuyển qua lại.
class ChartFullScreen extends StatefulWidget {
  final ChartController controller;
  final RankedCoin coin;

  const ChartFullScreen({
    super.key,
    required this.controller,
    required this.coin,
  });

  @override
  State<ChartFullScreen> createState() => _ChartFullScreenState();
}

class _ChartFullScreenState extends State<ChartFullScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Danh sách rỗng = trả về hành vi mặc định của hệ điều hành.
    SystemChrome.setPreferredOrientations(const []);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final candles = controller.candles;
            final price = (controller.liveConnected && candles.isNotEmpty)
                ? candles.last.close
                : widget.coin.currentPrice;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('fullscreen_close'),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, color: Color(0xFFC9D1D9)),
                        tooltip: 'Thoát toàn màn hình',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        '${widget.coin.baseAsset}/USDT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        price.toStringAsFixed(widget.coin.pricePrecision),
                        style: TextStyle(
                          color: candles.isNotEmpty && !candles.last.isUp
                              ? kCandleDown
                              : kCandleUp,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: controller.liveConnected
                              ? const Color(0xFF00E676)
                              : const Color(0xFFFFB300),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: IntervalSelector(
                          compact: true,
                          selected: controller.interval,
                          onSelected: controller.setInterval,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: controller.toggleImbalance,
                        child: Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          decoration: BoxDecoration(
                            color: controller.showImbalance
                                ? const Color(0xFF00B0FF).withValues(alpha: 0.16)
                                : const Color(0xFF161A22),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: controller.showImbalance
                                  ? const Color(0xFF00B0FF).withValues(alpha: 0.7)
                                  : const Color(0xFF262D3D),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'OFIF',
                              style: TextStyle(
                                color: controller.showImbalance
                                    ? const Color(0xFF00B0FF)
                                    : const Color(0xFF8B949E),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CandleChart(
                    key: ValueKey('fs_${controller.interval.code}'),
                    controller: controller,
                    pricePrecision: widget.coin.pricePrecision,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

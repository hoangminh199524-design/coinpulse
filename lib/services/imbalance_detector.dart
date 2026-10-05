import '../models/candle.dart';
import '../models/imbalance_zone.dart';

/// Pure Dart implementation of the "Order Flow Imbalance Finder (OFIF)"
/// Pine Script indicator by Turk.
///
/// Phân tích price imbalance / FVG dựa trên chuỗi 3 nến liên tiếp:
/// - Top Imbalance (Supply zone): low[2] <= open[1] and high[0] >= close[1]
/// - Bottom Imbalance (Demand zone): high[2] >= open[1] and low[0] <= close[1]
/// - Cắt box khi giá của nến mới xuyên thủng biên trên hoặc biên dưới.
class ImbalanceDetector {
  static const int defaultMaxZones = 50;

  /// Phát hiện các vùng Imbalance trong danh sách nến [candles].
  /// [confirmedOnly]: nếu true, bỏ qua nến chưa đóng ở cuối danh sách.
  /// [maxZones]: số lượng zone tối đa được giữ lại (mặc định 50 như Pine Script).
  static List<ImbalanceZone> detect(
    List<Candle> candles, {
    int maxZones = defaultMaxZones,
    bool confirmedOnly = true,
  }) {
    if (candles.length < 3) return const [];

    final evalCount = (confirmedOnly && candles.isNotEmpty && !candles.last.isClosed)
        ? candles.length - 1
        : candles.length;

    if (evalCount < 3) return const [];

    final List<_ActiveBox> boxes = [];

    for (int i = 2; i < evalCount; i++) {
      final c2 = candles[i - 2];
      final c1 = candles[i - 1];
      final c0 = candles[i];

      final isTop = c2.low <= c1.open && c0.high >= c1.close;
      final topSize = c2.low - c0.high;

      final isBottom = c2.high >= c1.open && c0.low <= c1.close;
      final bottomSize = c0.low - c2.high;

      // 1. Tạo box mới nếu thỏa mãn điều kiện và size > 0
      if (isTop && topSize > 0) {
        final box = _ActiveBox(
          id: 'imb_top_${c0.openTime}',
          type: ImbalanceType.top,
          topPrice: c2.low,
          bottomPrice: c0.high,
          startIndex: i,
          startOpenTime: c0.openTime,
          rightIndex: i,
          endOpenTime: c0.openTime,
          active: true,
        );
        if (boxes.length >= maxZones) {
          boxes.removeAt(0);
        }
        boxes.add(box);
      } else if (isBottom && bottomSize > 0) {
        final box = _ActiveBox(
          id: 'imb_bot_${c0.openTime}',
          type: ImbalanceType.bottom,
          topPrice: c0.low,
          bottomPrice: c2.high,
          startIndex: i,
          startOpenTime: c0.openTime,
          rightIndex: i,
          endOpenTime: c0.openTime,
          active: true,
        );
        if (boxes.length >= maxZones) {
          boxes.removeAt(0);
        }
        boxes.add(box);
      }

      // 2. Kéo dài hoặc cắt các box cũ (f_choppedoffimb)
      for (final box in boxes) {
        if (!box.active) continue;

        // Chỉ kiểm tra các box được kéo dài tới ngay cây nến trước (i - 1)
        if (box.rightIndex == i - 1) {
          final highViolates = c0.high > box.topPrice && c0.low < box.topPrice;
          final lowViolates = c0.high > box.bottomPrice && c0.low < box.bottomPrice;

          if (!highViolates && !lowViolates) {
            // Không bị cắt: tiếp tục kéo dài sang nến hiện tại
            box.rightIndex = i;
            box.endOpenTime = c0.openTime;
          } else {
            // Bị cắt: kết thúc kéo dài
            box.active = false;
          }
        }
      }
    }

    return boxes
        .map((b) => ImbalanceZone(
              id: b.id,
              type: b.type,
              topPrice: b.topPrice,
              bottomPrice: b.bottomPrice,
              startOpenTime: b.startOpenTime,
              endOpenTime: b.endOpenTime,
              active: b.active,
            ))
        .toList();
  }
}

class _ActiveBox {
  final String id;
  final ImbalanceType type;
  final double topPrice;
  final double bottomPrice;
  final int startIndex;
  final int startOpenTime;
  int rightIndex;
  int endOpenTime;
  bool active;

  _ActiveBox({
    required this.id,
    required this.type,
    required this.topPrice,
    required this.bottomPrice,
    required this.startIndex,
    required this.startOpenTime,
    required this.rightIndex,
    required this.endOpenTime,
    required this.active,
  });
}

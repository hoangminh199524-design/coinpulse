import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/market_coordinator.dart';

class StatusBadge extends StatelessWidget {
  final MarketConnectionStatus status;
  final DateTime? lastSnapshotTime;

  const StatusBadge({
    super.key,
    required this.status,
    this.lastSnapshotTime,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    String label;
    Color bgTint;

    switch (status) {
      case MarketConnectionStatus.live:
        dotColor = const Color(0xFF00E676); // Vibrant emerald
        label = 'TRỰC TIẾP';
        bgTint = const Color(0x1A00E676);
        break;
      case MarketConnectionStatus.loading:
        dotColor = const Color(0xFFFFB300); // Amber
        label = 'ĐANG TẢI';
        bgTint = const Color(0x1AFFB300);
        break;
      case MarketConnectionStatus.connecting:
        dotColor = const Color(0xFF29B6F6); // Light blue
        label = 'KẾT NỐI...';
        bgTint = const Color(0x1A29B6F6);
        break;
      case MarketConnectionStatus.offline:
        dotColor = const Color(0xFFFF5252); // Red
        label = 'MẤT MẠNG';
        bgTint = const Color(0x1AFF5252);
        break;
      case MarketConnectionStatus.empty:
        dotColor = const Color(0xFF9E9E9E); // Grey
        label = 'TRỐNG';
        bgTint = const Color(0x1A9E9E9E);
        break;
    }

    String? timeString;
    if (status == MarketConnectionStatus.offline && lastSnapshotTime != null) {
      timeString = DateFormat('HH:mm:ss').format(lastSnapshotTime!);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dotColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: dotColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          if (timeString != null) ...[
            const SizedBox(width: 4),
            Text(
              '($timeString)',
              style: TextStyle(
                color: dotColor.withValues(alpha: 0.8),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

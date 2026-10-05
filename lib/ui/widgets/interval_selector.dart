import 'package:flutter/material.dart';
import '../../models/chart_interval.dart';

/// Thanh chọn khung thời gian (1m … 1W), cuộn ngang được.
class IntervalSelector extends StatelessWidget {
  final ChartInterval selected;
  final ValueChanged<ChartInterval> onSelected;
  final bool compact;

  const IntervalSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 30 : 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 12),
        itemCount: ChartInterval.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final item = ChartInterval.values[i];
          final active = item == selected;
          return GestureDetector(
            key: ValueKey('interval_${item.code}'),
            onTap: () => onSelected(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF00E676).withValues(alpha: 0.14)
                    : const Color(0xFF161A22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? const Color(0xFF00E676).withValues(alpha: 0.7)
                      : const Color(0xFF262D3D),
                ),
              ),
              child: Text(
                item.label,
                style: TextStyle(
                  color: active ? const Color(0xFF00E676) : const Color(0xFF8B949E),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

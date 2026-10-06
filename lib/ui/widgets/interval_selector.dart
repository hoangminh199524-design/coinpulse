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
    final h = compact ? 32.0 : 42.0;
    return SizedBox(
      height: h,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: ChartInterval.values.map((item) {
            final active = item == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                key: ValueKey('interval_${item.code}'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => onSelected(item),
                onTap: () => onSelected(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 14,
                    vertical: compact ? 5 : 9,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF00E676).withValues(alpha: 0.16)
                        : const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active
                          ? const Color(0xFF00E676).withValues(alpha: 0.8)
                          : const Color(0xFF262D3D),
                      width: active ? 1.2 : 0.8,
                    ),
                  ),
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: active ? const Color(0xFF00E676) : const Color(0xFF8B949E),
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

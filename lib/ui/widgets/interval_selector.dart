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
    final h = compact ? 34.0 : 44.0;
    return SizedBox(
      height: h,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: ChartInterval.values.map((item) {
            return _IntervalButton(
              key: ValueKey('interval_${item.code}'),
              item: item,
              active: item == selected,
              compact: compact,
              onTap: () => onSelected(item),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _IntervalButton extends StatefulWidget {
  final ChartInterval item;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  const _IntervalButton({
    super.key,
    required this.item,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_IntervalButton> createState() => _IntervalButtonState();
}

class _IntervalButtonState extends State<_IntervalButton> {
  Offset? _downOffset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _downOffset = e.position;
        },
        onPointerUp: (e) {
          final down = _downOffset;
          _downOffset = null;
          if (down != null && (e.position - down).distance < 20.0) {
            widget.onTap();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 10 : 15,
              vertical: widget.compact ? 6 : 10,
            ),
            decoration: BoxDecoration(
              color: widget.active
                  ? const Color(0xFF00E676).withValues(alpha: 0.16)
                  : const Color(0xFF161A22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.active
                    ? const Color(0xFF00E676).withValues(alpha: 0.8)
                    : const Color(0xFF262D3D),
                width: widget.active ? 1.2 : 0.8,
              ),
            ),
            child: Text(
              widget.item.label,
              style: TextStyle(
                color: widget.active
                    ? const Color(0xFF00E676)
                    : const Color(0xFF8B949E),
                fontSize: widget.compact ? 12 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../models/candle.dart';
import '../../models/chart_interval.dart';
import '../../models/imbalance_zone.dart';
import '../../services/chart_controller.dart';

const Color kCandleUp = Color(0xFF0ECB81);
const Color kCandleDown = Color(0xFFF6465D);

/// Chart nến realtime: kéo để xem lịch sử, pinch để zoom, chạm để bật crosshair.
///
/// Trục X dùng "scroll" = số nến lệch so với nến mới nhất (0 = đang ở mép live).
/// Cách tính này không đổi khi prepend nến cũ vào đầu danh sách.
class CandleChart extends StatefulWidget {
  final ChartController controller;
  final int pricePrecision;

  const CandleChart({
    super.key,
    required this.controller,
    required this.pricePrecision,
  });

  @override
  State<CandleChart> createState() => _CandleChartState();
}

class _CandleChartState extends State<CandleChart>
    with SingleTickerProviderStateMixin {
  static const double _axisW = 62;
  static const double _timeH = 22;
  static const double _pad = 6; // số nến trống bên phải khi ở mép live
  static const double _minW = 2.5;
  static const double _maxW = 30;

  double _w = 7; // bề rộng 1 nến (px)
  double _baseW = 7;
  double _scroll = 0;
  double _plotW = 300;
  double _plotH = 300;
  int _lastPointerCount = 0;
  Offset? _cross;
  int? _lastOpenTime;
  Timer? _clock;
  double _flingLast = 0;
  late final AnimationController _fling;

  ChartController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _fling = AnimationController.unbounded(vsync: this)
      ..addListener(_onFlingTick);
    final candles = _c.candles;
    _lastOpenTime = candles.isEmpty ? null : candles.last.openTime;
    _c.addListener(_onData);
    // Tick mỗi giây để countdown nến chạy.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _c.removeListener(_onData);
    _fling.dispose();
    super.dispose();
  }

  double _rightEdge(int n) => n - 1 + _pad - _scroll;

  double _clampScroll(double s, int n) {
    final maxS = math.max(-4.0, n - 1 + _pad - 5.0);
    return s.clamp(-4.0, maxS);
  }

  void _onData() {
    if (!mounted) return;
    final candles = _c.candles;
    if (candles.isEmpty) {
      _lastOpenTime = null;
      setState(() {});
      return;
    }
    final lastOpen = candles.last.openTime;
    final prev = _lastOpenTime;
    if (prev != null && lastOpen > prev && _scroll > 2) {
      // Đang xem quá khứ: giữ nguyên vị trí khi có nến mới.
      final added = ((lastOpen - prev) / _c.interval.milliseconds).round();
      _scroll += added;
    }
    _lastOpenTime = lastOpen;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
  }

  void _maybeLoadMore() {
    if (!mounted) return;
    final n = _c.candles.length;
    if (n == 0) return;
    final leftmost = _rightEdge(n) - _plotW / _w;
    if (leftmost < 40) _c.loadOlder();
  }

  void _onFlingTick() {
    final n = _c.candles.length;
    if (n == 0) return;
    final dx = _fling.value - _flingLast;
    _flingLast = _fling.value;
    setState(() => _scroll = _clampScroll(_scroll + dx / _w, n));
    _maybeLoadMore();
  }

  Offset _clampToPlot(Offset p) => Offset(
        p.dx.clamp(0.0, _plotW),
        p.dy.clamp(0.0, _plotH),
      );

  void _onScaleStart(ScaleStartDetails d) {
    _fling.stop();
    _baseW = _w;
    _lastPointerCount = d.pointerCount;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final n = _c.candles.length;
    if (n == 0) return;

    // Crosshair đang bật: 1 ngón kéo = di chuyển crosshair.
    if (_cross != null && d.pointerCount == 1) {
      setState(() => _cross = _clampToPlot(d.localFocalPoint));
      return;
    }

    if (d.pointerCount != _lastPointerCount) {
      _baseW = _w;
      _lastPointerCount = d.pointerCount;
    }

    final prevFocalX = d.localFocalPoint.dx - d.focalPointDelta.dx;
    final idxAtFocal = _rightEdge(n) - (_plotW - prevFocalX) / _w;

    var w2 = _w;
    if (d.pointerCount >= 2) {
      w2 = (_baseW * d.scale).clamp(_minW, _maxW);
    }
    final edge2 = idxAtFocal + (_plotW - d.localFocalPoint.dx) / w2;

    setState(() {
      _w = w2;
      _scroll = _clampScroll(n - 1 + _pad - edge2, n);
    });
    _maybeLoadMore();
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_cross != null || d.pointerCount != 0) return;
    final vx = d.velocity.pixelsPerSecond.dx;
    if (vx.abs() < 150) return;
    _flingLast = _fling.value;
    _fling.animateWith(FrictionSimulation(0.135, _fling.value, vx));
  }

  void _onTapUp(TapUpDetails d) {
    setState(() {
      _cross = _cross == null ? _clampToPlot(d.localPosition) : null;
    });
  }

  void _jumpToLatest() {
    _fling.stop();
    setState(() {
      _scroll = 0;
      _cross = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      _plotW = math.max(50, cons.maxWidth - _axisW);
      _plotH = math.max(50, cons.maxHeight - _timeH);

      final candles = _c.candles;

      if (candles.isEmpty) {
        if (_c.status == ChartStatus.error) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined,
                    color: Color(0xFF484F58), size: 40),
                const SizedBox(height: 10),
                const Text(
                  'Không tải được dữ liệu chart',
                  style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _c.reload,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)),
        );
      }

      final n = candles.length;
      _scroll = _clampScroll(_scroll, n);
      final edge = _rightEdge(n);

      Candle shown = candles.last;
      if (_cross != null) {
        final idx = (edge - (_plotW - _cross!.dx) / _w).round().clamp(0, n - 1);
        shown = candles[idx];
      }

      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              onTapUp: _onTapUp,
              child: CustomPaint(
                painter: _ChartPainter(
                  candles: candles,
                  interval: _c.interval,
                  rightEdge: edge,
                  candleW: _w,
                  plotW: _plotW,
                  axisW: _axisW,
                  timeH: _timeH,
                  precision: widget.pricePrecision,
                  cross: _cross,
                  nowMs: _c.serverNowMs,
                  imbalanceZones: _c.imbalanceZones,
                  showImbalance: _c.showImbalance,
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 4,
            right: _axisW + 8,
            child: IgnorePointer(
              child: _OhlcOverlay(
                candle: shown,
                precision: widget.pricePrecision,
              ),
            ),
          ),
          if (_c.loadingMore)
            const Positioned(
              left: 10,
              bottom: _timeH + 10,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00E676),
                ),
              ),
            ),
          if (_scroll > 3)
            Positioned(
              right: _axisW + 8,
              bottom: _timeH + 8,
              child: Material(
                color: const Color(0xFF21262D),
                shape: const CircleBorder(
                  side: BorderSide(color: Color(0xFF30363D)),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _jumpToLatest,
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(Icons.keyboard_double_arrow_right,
                        size: 18, color: Color(0xFFC9D1D9)),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// OHLC overlay
// ---------------------------------------------------------------------------

class _OhlcOverlay extends StatelessWidget {
  final Candle candle;
  final int precision;

  const _OhlcOverlay({required this.candle, required this.precision});

  @override
  Widget build(BuildContext context) {
    final color = candle.isUp ? kCandleUp : kCandleDown;
    final pct = candle.changePercent;
    final sign = pct >= 0 ? '+' : '';

    TextSpan item(String label, String value) => TextSpan(children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(color: Color(0xFF6E7B8B)),
          ),
          TextSpan(text: '$value   ', style: TextStyle(color: color)),
        ]);

    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
        children: [
          item('O', candle.open.toStringAsFixed(precision)),
          item('H', candle.high.toStringAsFixed(precision)),
          item('L', candle.low.toStringAsFixed(precision)),
          item('C', candle.close.toStringAsFixed(precision)),
          item('', '$sign${pct.toStringAsFixed(2)}%'),
          item('Vol', _compact(candle.volume)),
        ],
      ),
    );
  }
}

String _compact(double v) {
  if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
  if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
  if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(2)}K';
  return v.toStringAsFixed(v >= 100 ? 0 : 2);
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _ChartPainter extends CustomPainter {
  final List<Candle> candles;
  final ChartInterval interval;
  final double rightEdge;
  final double candleW;
  final double plotW;
  final double axisW;
  final double timeH;
  final int precision;
  final Offset? cross;
  final int nowMs;
  final List<ImbalanceZone> imbalanceZones;
  final bool showImbalance;

  _ChartPainter({
    required this.candles,
    required this.interval,
    required this.rightEdge,
    required this.candleW,
    required this.plotW,
    required this.axisW,
    required this.timeH,
    required this.precision,
    required this.cross,
    required this.nowMs,
    required this.imbalanceZones,
    required this.showImbalance,
  });

  static const Color _grid = Color(0xFF1A2030);
  static const Color _axisText = Color(0xFF6E7B8B);

  static final DateFormat _fHm = DateFormat('HH:mm');
  static final DateFormat _fDm = DateFormat('dd/MM');
  static final DateFormat _fDmy = DateFormat('dd/MM/yy');
  static final DateFormat _fFullIntraday = DateFormat('dd/MM/yy HH:mm');

  double _x(int i) => plotW - (rightEdge - i) * candleW;

  @override
  void paint(Canvas canvas, Size size) {
    final n = candles.length;
    if (n == 0) return;

    canvas.clipRect(Offset.zero & size);

    final plotH = size.height - timeH;
    final volTop = plotH * 0.80;
    final volBottom = plotH - 2;
    const priceTop = 36.0;
    final priceBottom = volTop - 8;

    final first = math.max(0, (rightEdge - plotW / candleW).floor() - 1);
    final last = math.min(n - 1, rightEdge.ceil());
    if (first > last) return;

    // --- Vùng đang xem: high/low/volume ---
    var lo = double.infinity;
    var hi = -double.infinity;
    var maxVol = 0.0;
    var hiIdx = first;
    var loIdx = first;
    for (var i = first; i <= last; i++) {
      final c = candles[i];
      if (c.high > hi) {
        hi = c.high;
        hiIdx = i;
      }
      if (c.low < lo) {
        lo = c.low;
        loIdx = i;
      }
      if (c.volume > maxVol) maxVol = c.volume;
    }
    final visHi = hi;
    final visLo = lo;
    var range = hi - lo;
    if (range <= 0) range = hi * 0.01;
    final padR = range * 0.06;
    hi += padR;
    lo -= padR;
    final span = hi - lo;

    double priceToY(double p) =>
        priceTop + (hi - p) / span * (priceBottom - priceTop);
    double yToPrice(double y) =>
        hi - (y - priceTop) / (priceBottom - priceTop) * span;

    final gridPaint = Paint()
      ..color = _grid
      ..strokeWidth = 1;

    // --- Lưới giá + nhãn trục phải ---
    final step = _niceStep(span / 5);
    var p = (lo / step).ceil() * step;
    while (p <= hi) {
      final y = priceToY(p);
      if (y >= priceTop - 4 && y <= priceBottom + 2) {
        canvas.drawLine(Offset(0, y), Offset(plotW, y), gridPaint);
        _text(canvas, p.toStringAsFixed(precision), Offset(plotW + 6, y),
            const TextStyle(color: _axisText, fontSize: 10.5),
            vCenter: true);
      }
      p += step;
    }

    // --- Lưới thời gian + nhãn trục dưới ---
    final ivMs = interval.milliseconds;
    final stepCandles = _niceCount((70 / candleW).ceil());
    for (var i = first; i <= last; i++) {
      final slot = candles[i].openTime ~/ ivMs;
      if (slot % stepCandles != 0) continue;
      final x = _x(i);
      if (x < 12 || x > plotW - 12) continue;
      canvas.drawLine(Offset(x, 0), Offset(x, plotH), gridPaint);
      _text(canvas, _timeLabel(candles[i].openTime), Offset(x, plotH + 5),
          const TextStyle(color: _axisText, fontSize: 10.5),
          hCenter: true);
    }

    // Đường phân cách khối lượng
    canvas.drawLine(Offset(0, volTop), Offset(plotW, volTop), gridPaint);

    // --- Vùng Imbalance (OFIF) ---
    if (showImbalance && imbalanceZones.isNotEmpty) {
      int findIndex(int openTime) {
        int low = 0, high = n - 1;
        while (low <= high) {
          final mid = (low + high) >> 1;
          final ot = candles[mid].openTime;
          if (ot == openTime) return mid;
          if (ot < openTime) {
            low = mid + 1;
          } else {
            high = mid - 1;
          }
        }
        return low.clamp(0, n - 1);
      }

      final imbFillPaint = Paint()..style = PaintingStyle.fill;

      for (final zone in imbalanceZones) {
        final startIdx = findIndex(zone.startOpenTime);
        final endIdx = zone.active ? (n - 1) : findIndex(zone.endOpenTime);

        if (endIdx < first || startIdx > last) continue;

        final startX = _x(startIdx) - candleW / 2;
        final endX = _x(endIdx) + candleW / 2;

        final yTop = priceToY(zone.topPrice);
        final yBottom = priceToY(zone.bottomPrice);
        final top = math.min(yTop, yBottom);
        final bottom = math.max(yTop, yBottom);

        if (bottom < priceTop || top > priceBottom) continue;

        final rect = Rect.fromLTRB(
          startX.clamp(0.0, plotW),
          top.clamp(priceTop, priceBottom),
          endX.clamp(0.0, plotW),
          bottom.clamp(priceTop, priceBottom),
        );

        if (rect.width <= 0 || rect.height <= 0) continue;

        final isTop = zone.type == ImbalanceType.top;
        final baseColor = isTop ? const Color(0xFFF6465D) : const Color(0xFF0ECB81);

        // Nền mờ
        imbFillPaint.color = baseColor.withValues(alpha: 0.15);
        canvas.drawRect(rect, imbFillPaint);

        // Viền nét đứt
        _dashedLine(canvas, rect.topLeft, rect.topRight, baseColor.withValues(alpha: 0.65));
        _dashedLine(canvas, rect.bottomLeft, rect.bottomRight, baseColor.withValues(alpha: 0.65));
        _dashedLine(canvas, rect.topLeft, rect.bottomLeft, baseColor.withValues(alpha: 0.65));
        _dashedLine(canvas, rect.topRight, rect.bottomRight, baseColor.withValues(alpha: 0.65));

        // Nhãn nhỏ
        if (rect.width > 38 && rect.height > 10) {
          _text(
            canvas,
            isTop ? 'TOP IMB' : 'BOT IMB',
            Offset(rect.left + 4, rect.top + 2),
            TextStyle(
              color: baseColor.withValues(alpha: 0.8),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          );
        }
      }
    }

    // --- Nến + volume ---
    final paintFill = Paint()..style = PaintingStyle.fill;
    final paintWick = Paint()..strokeWidth = 1;
    final bodyW = math.max(1.0, candleW * 0.68);
    final volMaxH = volBottom - volTop - 4;

    for (var i = first; i <= last; i++) {
      final c = candles[i];
      final x = _x(i);
      final color = c.isUp ? kCandleUp : kCandleDown;

      paintWick.color = color;
      canvas.drawLine(
        Offset(x, priceToY(c.high)),
        Offset(x, priceToY(c.low)),
        paintWick,
      );

      final yO = priceToY(c.open);
      final yC = priceToY(c.close);
      var top = math.min(yO, yC);
      var bottom = math.max(yO, yC);
      if (bottom - top < 1) bottom = top + 1;
      paintFill.color = color;
      canvas.drawRect(
        Rect.fromLTRB(x - bodyW / 2, top, x + bodyW / 2, bottom),
        paintFill,
      );

      if (maxVol > 0) {
        final h = math.max(1.0, c.volume / maxVol * volMaxH);
        paintFill.color = color.withValues(alpha: 0.4);
        canvas.drawRect(
          Rect.fromLTRB(x - bodyW / 2, volBottom - h, x + bodyW / 2, volBottom),
          paintFill,
        );
      }
    }

    // --- High / Low của vùng đang xem ---
    _extremeLabel(canvas, hiIdx, visHi, priceToY(visHi));
    if (loIdx != hiIdx || visHi != visLo) {
      _extremeLabel(canvas, loIdx, visLo, priceToY(visLo));
    }

    // --- Giá hiện tại + countdown ---
    final live = candles.last;
    final liveColor = live.isUp ? kCandleUp : kCandleDown;
    final yLive = priceToY(live.close).clamp(priceTop, priceBottom);
    _dashedLine(canvas, Offset(0, yLive), Offset(plotW, yLive),
        liveColor.withValues(alpha: 0.75));
    _tag(canvas, Offset(plotW, yLive - 9), axisW, 18, liveColor,
        live.close.toStringAsFixed(precision), Colors.white,
        bold: true);
    final remaining = math.max(0, live.closeTime + 1 - nowMs);
    _tag(canvas, Offset(plotW, yLive + 9), axisW, 15,
        const Color(0xFF2B3139), _countdown(remaining), const Color(0xFFC9D1D9),
        fontSize: 9.5);

    // --- Crosshair ---
    if (cross != null) {
      final idx = (rightEdge - (plotW - cross!.dx) / candleW)
          .round()
          .clamp(0, n - 1);
      final cx = _x(idx);
      final cy = cross!.dy.clamp(0.0, plotH);
      const crossColor = Color(0xFF8B949E);
      _dashedLine(canvas, Offset(cx, 0), Offset(cx, plotH), crossColor);
      _dashedLine(canvas, Offset(0, cy), Offset(plotW, cy), crossColor);

      final label = cy > volTop
          ? _compact(candles[idx].volume)
          : yToPrice(cy).toStringAsFixed(precision);
      _tag(canvas, Offset(plotW, cy - 9), axisW, 18, const Color(0xFF3A4352),
          label, Colors.white);

      final timeText = interval.milliseconds >= 86400000
          ? _fDmy.format(DateTime.fromMillisecondsSinceEpoch(candles[idx].openTime))
          : _fFullIntraday
              .format(DateTime.fromMillisecondsSinceEpoch(candles[idx].openTime));
      const tagW = 98.0;
      final tx = (cx - tagW / 2).clamp(0.0, plotW - tagW);
      _tag(canvas, Offset(tx, plotH + 2), tagW, 18, const Color(0xFF3A4352),
          timeText, Colors.white);
    }
  }

  void _extremeLabel(Canvas canvas, int idx, double price, double y) {
    final x = _x(idx);
    final onLeftHalf = x < plotW * 0.5;
    final dir = onLeftHalf ? 1.0 : -1.0;
    const color = Color(0xFFB0BAC6);
    canvas.drawLine(
      Offset(x + dir * 4, y),
      Offset(x + dir * 12, y),
      Paint()
        ..color = color
        ..strokeWidth = 1,
    );
    _text(
      canvas,
      price.toStringAsFixed(precision),
      Offset(x + dir * 15, y),
      const TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      vCenter: true,
      alignRight: !onLeftHalf,
    );
  }

  String _timeLabel(int openTime) {
    final dt = DateTime.fromMillisecondsSinceEpoch(openTime);
    if (interval.milliseconds >= 7 * 86400000) return _fDmy.format(dt);
    if (interval.milliseconds >= 86400000) return _fDm.format(dt);
    if (dt.hour == 0 && dt.minute == 0) return _fDm.format(dt);
    return _fHm.format(dt);
  }

  static String _countdown(int ms) {
    final total = ms ~/ 1000;
    final d = total ~/ 86400;
    final h = (total % 86400) ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    if (d > 0) return '${d}d ${h}h ${m}m';
    if (h > 0) return '${two(h)}:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }

  static double _niceStep(double raw) {
    if (raw <= 0 || raw.isNaN || raw.isInfinite) return 1;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    final nice = norm <= 1
        ? 1
        : norm <= 2
            ? 2
            : norm <= 2.5
                ? 2.5
                : norm <= 5
                    ? 5
                    : 10;
    return nice * mag;
  }

  static int _niceCount(int raw) {
    const steps = [1, 2, 3, 5, 10, 15, 20, 30, 50, 100, 200, 500, 1000];
    for (final s in steps) {
      if (s >= raw) return s;
    }
    return steps.last;
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final e = math.min(d + dash, total);
      canvas.drawLine(a + dir * d, a + dir * e, paint);
      d += dash + gap;
    }
  }

  void _tag(Canvas canvas, Offset topLeft, double w, double h, Color bg,
      String text, Color fg,
      {bool bold = false, double fontSize = 10.5}) {
    final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = bg,
    );
    _text(
      canvas,
      text,
      Offset(rect.center.dx, rect.center.dy),
      TextStyle(
        color: fg,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
      ),
      hCenter: true,
      vCenter: true,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    bool hCenter = false,
    bool vCenter = false,
    bool alignRight = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    var dy = at.dy;
    if (hCenter) dx -= tp.width / 2;
    if (alignRight) dx -= tp.width;
    if (vCenter) dy -= tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => true;
}

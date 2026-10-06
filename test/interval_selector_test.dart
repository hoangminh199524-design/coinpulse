import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coin_pulse/models/chart_interval.dart';
import 'package:coin_pulse/ui/widgets/interval_selector.dart';

void main() {
  testWidgets('IntervalSelector taps trigger onSelected', (tester) async {
    ChartInterval selected = ChartInterval.m15;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IntervalSelector(
            selected: selected,
            onSelected: (val) {
              selected = val;
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('interval_1m')), findsOneWidget);
    expect(find.byKey(const ValueKey('interval_5m')), findsOneWidget);

    // Tap 1m
    await tester.tap(find.byKey(const ValueKey('interval_1m')));
    await tester.pumpAndSettle();
    expect(selected, ChartInterval.m1);

    // Tap 5m
    await tester.tap(find.byKey(const ValueKey('interval_5m')));
    await tester.pumpAndSettle();
    expect(selected, ChartInterval.m5);
  });
}

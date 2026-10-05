import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/market_coordinator.dart';
import 'ui/home_screen.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Dark navigation bar and status bar style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0D1117),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    final coordinator = MarketCoordinator();
    runApp(CoinPulseApp(coordinator: coordinator));
    unawaited(coordinator.initialize());
  }, (error, stack) {
    debugPrint('CoinPulse error caught in zone: $error');
  });
}

class CoinPulseApp extends StatelessWidget {
  final MarketCoordinator coordinator;

  const CoinPulseApp({
    super.key,
    required this.coordinator,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoinPulse — Binance Top Gainers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFF00E676),
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF00B0FF),
          surface: Color(0xFF161A22),
        ),
      ),
      home: HomeScreen(coordinator: coordinator),
    );
  }
}

class AppConfig {
  final String quoteAsset;
  final double minQuoteVolume;
  final int topN;
  final double alertGainThresholdPercent;
  final List<double> alertThresholds;
  final Set<String> blacklistBaseAssets;
  final Set<String> excludedSymbols;

  static const List<String> defaultBlacklist = [
    'USDC',
    'FDUSD',
    'TUSD',
    'DAI',
    'USDP',
    'USDE',
    'USD1',
    'USDS',
    'PYUSD',
    'AEUR',
    'BFUSD',
    'XUSD',
    'EUR',
  ];

  const AppConfig({
    this.quoteAsset = 'USDT',
    this.minQuoteVolume = 5000000.0,
    this.topN = 10,
    this.alertGainThresholdPercent = 20.0,
    this.alertThresholds = const [15.0, 20.0],
    this.blacklistBaseAssets = const {
      'USDC',
      'FDUSD',
      'TUSD',
      'DAI',
      'USDP',
      'USDE',
      'USD1',
      'USDS',
      'PYUSD',
      'AEUR',
      'BFUSD',
      'XUSD',
      'EUR',
    },
    this.excludedSymbols = const {},
  });

  AppConfig copyWith({
    String? quoteAsset,
    double? minQuoteVolume,
    int? topN,
    double? alertGainThresholdPercent,
    List<double>? alertThresholds,
    Set<String>? blacklistBaseAssets,
    Set<String>? excludedSymbols,
  }) {
    return AppConfig(
      quoteAsset: quoteAsset ?? this.quoteAsset,
      minQuoteVolume: minQuoteVolume ?? this.minQuoteVolume,
      topN: (topN ?? this.topN).clamp(5, 50),
      alertGainThresholdPercent: alertGainThresholdPercent ?? this.alertGainThresholdPercent,
      alertThresholds: alertThresholds ?? this.alertThresholds,
      blacklistBaseAssets: blacklistBaseAssets ?? this.blacklistBaseAssets,
      excludedSymbols: excludedSymbols ?? this.excludedSymbols,
    );
  }
}

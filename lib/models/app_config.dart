class AppConfig {
  final String quoteAsset;
  final double minQuoteVolume;
  final int topN;
  final double alertGainThresholdPercent;
  final List<double> alertThresholds;
  final Set<String> blacklistBaseAssets;
  final Set<String> excludedSymbols;

  final bool telegramEnabled;
  final String telegramBotToken;
  final String telegramChatId;

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
    this.telegramEnabled = true,
    this.telegramBotToken = '8696394019:AAEN_9-u1gIly8O39WmTMJ9wuV_uBO7VfKg',
    this.telegramChatId = '6437919028',
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
    bool? telegramEnabled,
    String? telegramBotToken,
    String? telegramChatId,
    Set<String>? blacklistBaseAssets,
    Set<String>? excludedSymbols,
  }) {
    return AppConfig(
      quoteAsset: quoteAsset ?? this.quoteAsset,
      minQuoteVolume: minQuoteVolume ?? this.minQuoteVolume,
      topN: (topN ?? this.topN).clamp(5, 50),
      alertGainThresholdPercent: alertGainThresholdPercent ?? this.alertGainThresholdPercent,
      alertThresholds: alertThresholds ?? this.alertThresholds,
      telegramEnabled: telegramEnabled ?? this.telegramEnabled,
      telegramBotToken: telegramBotToken ?? this.telegramBotToken,
      telegramChatId: telegramChatId ?? this.telegramChatId,
      blacklistBaseAssets: blacklistBaseAssets ?? this.blacklistBaseAssets,
      excludedSymbols: excludedSymbols ?? this.excludedSymbols,
    );
  }
}

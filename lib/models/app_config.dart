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
    this.alertThresholds = const [20.0],
    this.telegramEnabled = true,
    this.telegramBotToken = '8696394019:AAEN_9-u1gIly8O39WmTMJ9wuV_uBO7VfKg',
    this.telegramChatId = '-5544970151',
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

  Map<String, dynamic> toJson() {
    return {
      'quoteAsset': quoteAsset,
      'minQuoteVolume': minQuoteVolume,
      'topN': topN,
      'alertGainThresholdPercent': alertGainThresholdPercent,
      'alertThresholds': alertThresholds,
      'telegramEnabled': telegramEnabled,
      'telegramBotToken': telegramBotToken,
      'telegramChatId': telegramChatId,
      'blacklistBaseAssets': blacklistBaseAssets.toList(),
      'excludedSymbols': excludedSymbols.toList(),
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final rawThresholds = json['alertThresholds'];
    List<double> thresholds = const [15.0, 20.0];
    if (rawThresholds is List) {
      thresholds = rawThresholds
          .map((e) => (e is num) ? e.toDouble() : double.tryParse(e.toString()))
          .whereType<double>()
          .toList()
        ..sort();
    }
    if (thresholds.isEmpty) {
      thresholds = const [15.0, 20.0];
    }

    final rawBlacklist = json['blacklistBaseAssets'];
    Set<String> blacklist = Set<String>.from(AppConfig.defaultBlacklist);
    if (rawBlacklist is List) {
      blacklist = rawBlacklist.map((e) => e.toString().trim().toUpperCase()).where((e) => e.isNotEmpty).toSet();
    }

    return AppConfig(
      quoteAsset: json['quoteAsset'] as String? ?? 'USDT',
      minQuoteVolume: (json['minQuoteVolume'] as num?)?.toDouble() ?? 5000000.0,
      topN: ((json['topN'] as num?)?.toInt() ?? 10).clamp(5, 50),
      alertGainThresholdPercent: (json['alertGainThresholdPercent'] as num?)?.toDouble() ?? (thresholds.isNotEmpty ? thresholds.first : 20.0),
      alertThresholds: thresholds,
      telegramEnabled: json['telegramEnabled'] as bool? ?? true,
      telegramBotToken: json['telegramBotToken'] as String? ?? '8696394019:AAEN_9-u1gIly8O39WmTMJ9wuV_uBO7VfKg',
      telegramChatId: json['telegramChatId'] as String? ?? '-5544970151',
      blacklistBaseAssets: blacklist,
      excludedSymbols: (json['excludedSymbols'] as List?)?.map((e) => e.toString()).toSet() ?? const {},
    );
  }
}

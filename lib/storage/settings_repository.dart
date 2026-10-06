import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';
import 'web_storage.dart';

class SettingsRepository {
  static const String _keyJsonConfig = 'coinpulse_app_config_json';
  static const String _keyTopN = 'setting_top_n';
  static const String _keyMinVolume = 'setting_min_volume';
  static const String _keyAlertThreshold = 'setting_alert_threshold';
  static const String _keyAlertThresholds = 'setting_alert_thresholds_list';
  static const String _keyBlacklist = 'setting_blacklist';
  static const String _keyQuoteAsset = 'setting_quote_asset';
  static const String _keyTelegramEnabled = 'setting_telegram_enabled';
  static const String _keyTelegramBotToken = 'setting_telegram_bot_token';
  static const String _keyTelegramChatId = 'setting_telegram_chat_id';

  Future<AppConfig> loadConfig() async {
    // 1. Check direct WebStorage (instant synchronous localStorage on Web)
    try {
      final webJson = WebStorage.getItem(_keyJsonConfig);
      if (webJson != null && webJson.isNotEmpty) {
        final decoded = jsonDecode(webJson) as Map<String, dynamic>;
        return AppConfig.fromJson(decoded);
      }
    } catch (_) {}

    // 2. Check SharedPreferences with fresh reload
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (_) {}

    final jsonStr = prefs.getString(_keyJsonConfig);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return AppConfig.fromJson(decoded);
      } catch (_) {}
    }

    // 3. Fallback to legacy individual keys
    final topN = prefs.getInt(_keyTopN) ?? 10;
    final minVol = prefs.getDouble(_keyMinVolume) ?? 5000000.0;
    final alertThreshold = prefs.getDouble(_keyAlertThreshold) ?? 20.0;
    final blacklistList = prefs.getStringList(_keyBlacklist);
    final quoteAsset = prefs.getString(_keyQuoteAsset) ?? 'USDT';
    final telegramEnabled = prefs.getBool(_keyTelegramEnabled) ?? true;
    final telegramBotToken = prefs.getString(_keyTelegramBotToken) ?? '8696394019:AAEN_9-u1gIly8O39WmTMJ9wuV_uBO7VfKg';
    final telegramChatId = prefs.getString(_keyTelegramChatId) ?? '-5544970151';

    final thresholdsStrings = prefs.getStringList(_keyAlertThresholds);
    List<double> alertThresholds;
    if (thresholdsStrings != null && thresholdsStrings.isNotEmpty) {
      alertThresholds = thresholdsStrings
          .map((e) => double.tryParse(e))
          .whereType<double>()
          .toSet()
          .toList()
        ..sort();
    } else {
      final oldSingleThreshold = prefs.getDouble(_keyAlertThreshold);
      alertThresholds = oldSingleThreshold != null
          ? [oldSingleThreshold]
          : const [15.0, 20.0];
    }

    final Set<String> blacklist = blacklistList != null
        ? blacklistList.map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty).toSet()
        : Set<String>.from(AppConfig.defaultBlacklist);

    return AppConfig(
      topN: topN.clamp(5, 50),
      minQuoteVolume: minVol,
      alertGainThresholdPercent: alertThreshold,
      alertThresholds: alertThresholds,
      telegramEnabled: telegramEnabled,
      telegramBotToken: telegramBotToken,
      telegramChatId: telegramChatId,
      blacklistBaseAssets: blacklist,
      quoteAsset: quoteAsset,
    );
  }

  Future<void> saveConfig(AppConfig config) async {
    final jsonStr = jsonEncode(config.toJson());

    // 1. Immediately write to WebStorage (synchronous, direct localStorage)
    WebStorage.setItem(_keyJsonConfig, jsonStr);

    // 2. Also persist to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyJsonConfig, jsonStr);
    await prefs.setInt(_keyTopN, config.topN.clamp(5, 50));
    await prefs.setDouble(_keyMinVolume, config.minQuoteVolume);
    await prefs.setDouble(_keyAlertThreshold, config.alertGainThresholdPercent);
    await prefs.setStringList(
      _keyAlertThresholds,
      config.alertThresholds.map((e) => e.toString()).toList(),
    );
    await prefs.setStringList(
      _keyBlacklist,
      config.blacklistBaseAssets.map((e) => e.trim().toUpperCase()).toList(),
    );
    await prefs.setString(_keyQuoteAsset, config.quoteAsset);
    await prefs.setBool(_keyTelegramEnabled, config.telegramEnabled);
    await prefs.setString(_keyTelegramBotToken, config.telegramBotToken);
    await prefs.setString(_keyTelegramChatId, config.telegramChatId);
  }
}

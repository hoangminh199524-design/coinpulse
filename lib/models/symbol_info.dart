class SymbolInfo {
  final String symbol;
  final String baseAsset;
  final String quoteAsset;
  final String status;
  final List<List<String>> permissionSets;
  final double tickSize;

  const SymbolInfo({
    required this.symbol,
    required this.baseAsset,
    required this.quoteAsset,
    required this.status,
    required this.permissionSets,
    required this.tickSize,
  });

  bool get isTrading => status.toUpperCase() == 'TRADING';

  bool get isLeveraged {
    for (final set in permissionSets) {
      if (set.any((p) => p.toUpperCase() == 'LEVERAGED')) {
        return true;
      }
    }
    return false;
  }

  factory SymbolInfo.fromJson(Map<String, dynamic> json) {
    final symbol = json['symbol'] as String? ?? '';
    final baseAsset = json['baseAsset'] as String? ?? '';
    final quoteAsset = json['quoteAsset'] as String? ?? '';
    final status = json['status'] as String? ?? '';

    // Parse permissionSets. Binance docs: permissionSets is List of List of String.
    // If permissionSets is absent or empty, fallback to permissions list.
    final rawPermissionSets = json['permissionSets'];
    final List<List<String>> parsedPermissionSets = [];

    if (rawPermissionSets is List) {
      for (final item in rawPermissionSets) {
        if (item is List) {
          parsedPermissionSets.add(item.map((e) => e.toString()).toList());
        }
      }
    }

    if (parsedPermissionSets.isEmpty && json['permissions'] is List) {
      final perms = (json['permissions'] as List).map((e) => e.toString()).toList();
      if (perms.isNotEmpty) {
        parsedPermissionSets.add(perms);
      }
    }

    // Parse tickSize from filters where filterType == 'PRICE_FILTER'
    double tickSize = 0.01;
    if (json['filters'] is List) {
      for (final filter in json['filters']) {
        if (filter is Map && filter['filterType'] == 'PRICE_FILTER') {
          final rawTick = filter['tickSize'];
          if (rawTick != null) {
            tickSize = double.tryParse(rawTick.toString()) ?? 0.01;
          }
          break;
        }
      }
    }

    return SymbolInfo(
      symbol: symbol,
      baseAsset: baseAsset,
      quoteAsset: quoteAsset,
      status: status,
      permissionSets: parsedPermissionSets,
      tickSize: tickSize,
    );
  }
}

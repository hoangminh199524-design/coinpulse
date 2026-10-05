enum MovementType {
  none,
  newEntry,
  up,
  down,
}

class RankMovement {
  final int? oldRank;
  final int newRank;
  final MovementType type;
  final DateTime timestamp;

  const RankMovement({
    this.oldRank,
    required this.newRank,
    required this.type,
    required this.timestamp,
  });

  bool isVisible(DateTime now) {
    if (type == MovementType.none) return false;
    return now.difference(timestamp).inMilliseconds <= 10000;
  }

  String get badgeText {
    switch (type) {
      case MovementType.newEntry:
        return 'MỚI';
      case MovementType.up:
      case MovementType.down:
        if (oldRank != null) {
          return '#$oldRank → #$newRank';
        }
        return '#$newRank';
      case MovementType.none:
        return '';
    }
  }
}

class RankedCoin {
  final int rank;
  final String symbol;
  final String baseAsset;
  final double openPrice;
  final double currentPrice;
  final double highPrice;
  final double lowPrice;
  final double quoteVolume;
  final double priceChangeAmount;
  final double priceChangePercent;
  final double tickSize;
  final int sourceTimestamp;
  final RankMovement? movement;

  const RankedCoin({
    required this.rank,
    required this.symbol,
    required this.baseAsset,
    required this.openPrice,
    required this.currentPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.quoteVolume,
    required this.priceChangeAmount,
    required this.priceChangePercent,
    required this.tickSize,
    required this.sourceTimestamp,
    this.movement,
  });

  /// Số chữ số thập phân theo tickSize của symbol (tối đa 8).
  int get pricePrecision {
    if (tickSize <= 0) return 2;
    int decimals = 2;
    if (tickSize < 1) {
      final str = tickSize.toString();
      final dot = str.indexOf('.');
      if (dot != -1) {
        decimals = str.length - dot - 1;
      }
    }
    if (decimals > 8) decimals = 8;
    return decimals;
  }

  String get formattedPrice => currentPrice.toStringAsFixed(pricePrecision);

  String get formattedVolume {
    if (quoteVolume >= 1e9) {
      return '\$${(quoteVolume / 1e9).toStringAsFixed(1)}B';
    } else if (quoteVolume >= 1e6) {
      return '\$${(quoteVolume / 1e6).toStringAsFixed(1)}M';
    } else if (quoteVolume >= 1e3) {
      return '\$${(quoteVolume / 1e3).toStringAsFixed(1)}K';
    }
    return '\$${quoteVolume.toStringAsFixed(0)}';
  }

  String get formattedPercent {
    final sign = priceChangePercent >= 0 ? '+' : '';
    return '$sign${priceChangePercent.toStringAsFixed(2)}%';
  }
}

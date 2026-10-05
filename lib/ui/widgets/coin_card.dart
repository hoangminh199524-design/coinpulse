import 'package:flutter/material.dart';
import '../../models/ranked_coin.dart';

class CoinCard extends StatelessWidget {
  final RankedCoin coin;
  final VoidCallback? onTap;

  const CoinCard({
    super.key,
    required this.coin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTop1 = coin.rank == 1;
    final isTop2 = coin.rank == 2;
    final isTop3 = coin.rank == 3;

    Color rankColor;
    if (isTop1) {
      rankColor = const Color(0xFFFFD700); // Gold
    } else if (isTop2) {
      rankColor = const Color(0xFFE0E0E0); // Silver
    } else if (isTop3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
    } else {
      rankColor = const Color(0xFF90A4AE); // Slate Grey
    }

    final isPositive = coin.priceChangePercent >= 0;
    final changeColor = isPositive ? const Color(0xFF00E676) : const Color(0xFFFF5252);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTop1
              ? const Color(0xFFFFD700).withValues(alpha: 0.3)
              : const Color(0xFF262D3D),
          width: isTop1 ? 1.2 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
        children: [
          // Rank column
          SizedBox(
            width: 38,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '#${coin.rank}',
                  style: TextStyle(
                    color: rankColor,
                    fontSize: isTop1 ? 17 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // Symbol and Volume
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      coin.baseAsset,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '/USDT',
                      style: TextStyle(
                        color: Color(0xFF78889B),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Rank movement pill
                    if (coin.movement != null && coin.movement!.badgeText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _buildMovementBadge(coin.movement!),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Vol: ${coin.formattedVolume}',
                  style: const TextStyle(
                    color: Color(0xFF8899A6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Price and 24h %
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${coin.formattedPrice}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  coin.formattedPercent,
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMovementBadge(RankMovement movement) {
    Color badgeBg;

    if (movement.type == MovementType.newEntry) {
      badgeBg = const Color(0xFF00C853);
    } else if (movement.type == MovementType.up) {
      badgeBg = const Color(0xFF00B0FF);
    } else {
      badgeBg = const Color(0xFFFF7043);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeBg.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: badgeBg.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        movement.badgeText,
        style: TextStyle(
          color: badgeBg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

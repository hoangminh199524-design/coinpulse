enum ImbalanceType {
  top,
  bottom,
}

/// Đại diện cho một vùng Imbalance (OFIF - Order Flow Imbalance Finder)
/// tính từ 3 cây nến liên tiếp.
class ImbalanceZone {
  final String id;
  final ImbalanceType type;
  final double topPrice;
  final double bottomPrice;
  final int startOpenTime;
  int endOpenTime;
  bool active;

  ImbalanceZone({
    required this.id,
    required this.type,
    required this.topPrice,
    required this.bottomPrice,
    required this.startOpenTime,
    required this.endOpenTime,
    this.active = true,
  });

  double get size => topPrice - bottomPrice;
}

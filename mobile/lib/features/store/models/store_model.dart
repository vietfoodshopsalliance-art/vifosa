class OpeningHour {
  final int dayOfWeek;
  final String open;
  final String close;
  final bool isClosed;

  OpeningHour({
    required this.dayOfWeek,
    required this.open,
    required this.close,
    required this.isClosed,
  });

  factory OpeningHour.fromJson(Map<String, dynamic> json) => OpeningHour(
        dayOfWeek: json['dayOfWeek'] ?? 0,
        open: json['open'] ?? '08:00',
        close: json['close'] ?? '22:00',
        isClosed: json['isClosed'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'open': open,
        'close': close,
        'isClosed': isClosed,
      };
}

class ShipFeeFormula {
  final double a;
  final double b;
  final double c;

  ShipFeeFormula({required this.a, required this.b, required this.c});

  factory ShipFeeFormula.fromJson(Map<String, dynamic> json) => ShipFeeFormula(
        a: (json['a'] ?? 12000).toDouble(),
        b: (json['b'] ?? 5000).toDouble(),
        c: (json['c'] ?? 0).toDouble(),
      );

  double calculate(double km) => (a + b * km) * (1 + c / 100);
}

class StoreStats {
  final int completedOrdersThisMonth;
  final double avgRating;
  final int totalReviews;

  StoreStats({
    required this.completedOrdersThisMonth,
    required this.avgRating,
    required this.totalReviews,
  });

  factory StoreStats.fromJson(Map<String, dynamic> json) => StoreStats(
        completedOrdersThisMonth: json['completedOrdersThisMonth'] ?? 0,
        avgRating: (json['avgRating'] ?? 0).toDouble(),
        totalReviews: json['totalReviews'] ?? 0,
      );
}

enum StoreStatus { open, preorder, emergencyClosed, suspended }

class StoreModel {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String coverImage;
  final String avatarImage;
  final String addressText;
  final double lat;
  final double lng;
  final List<OpeningHour> openingHours;
  final bool emergencyClosed;
  final bool isSuspended;
  final bool isAdLockedByAdmin;
  final ShipFeeFormula shipFeeFormula;
  final StoreStats stats;

  StoreModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.coverImage,
    required this.avatarImage,
    required this.addressText,
    required this.lat,
    required this.lng,
    required this.openingHours,
    required this.emergencyClosed,
    required this.isSuspended,
    required this.isAdLockedByAdmin,
    required this.shipFeeFormula,
    required this.stats,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    final coords = json['address']?['location']?['coordinates'];
    return StoreModel(
      id: json['_id'] ?? '',
      ownerId: json['ownerId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      coverImage: json['coverImage'] ?? '',
      avatarImage: json['avatarImage'] ?? '',
      addressText: json['address']?['text'] ?? '',
      lat: coords != null && coords.length > 1 ? (coords[1] as num).toDouble() : 0.0,
      lng: coords != null && coords.length > 0 ? (coords[0] as num).toDouble() : 0.0,
      openingHours: (json['openingHours'] as List? ?? [])
          .map((e) => OpeningHour.fromJson(e))
          .toList(),
      emergencyClosed: json['emergencyClosed'] ?? true,
      isSuspended: json['isSuspended'] ?? false,
      isAdLockedByAdmin: json['isAdLockedByAdmin'] ?? false,
      shipFeeFormula: ShipFeeFormula.fromJson(json['shipFeeFormula'] ?? {}),
      stats: StoreStats.fromJson(json['stats'] ?? {}),
    );
  }

  StoreStatus get status {
    if (isSuspended) return StoreStatus.suspended;
    if (emergencyClosed) return StoreStatus.emergencyClosed;

    final now = DateTime.now();
    final today = openingHours.where((h) => h.dayOfWeek == now.weekday % 7).firstOrNull;
    if (today == null || today.isClosed) return StoreStatus.preorder;

    final current = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    if (current.compareTo(today.open) >= 0 && current.compareTo(today.close) <= 0) return StoreStatus.open;
    return StoreStatus.preorder;
  }
}

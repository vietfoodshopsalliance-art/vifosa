// ─── StoreHours ───────────────────────────────────────────────────────────────

class StoreHours {
  final int dayOfWeek;
  final String open;
  final String close;
  final bool isClosed;

  const StoreHours({
    required this.dayOfWeek,
    required this.open,
    required this.close,
    required this.isClosed,
  });

  factory StoreHours.fromJson(Map<String, dynamic> j) => StoreHours(
        dayOfWeek: (j['dayOfWeek'] as num?)?.toInt() ?? 0,
        open: j['open'] as String? ?? '00:00',
        close: j['close'] as String? ?? '00:00',
        isClosed: j['isClosed'] as bool? ?? false,
      );
}

// ─── ShipFeeFormula ───────────────────────────────────────────────────────────

class ShipFeeFormula {
  final num a;
  final num b;
  final num c;

  const ShipFeeFormula({required this.a, required this.b, required this.c});

  factory ShipFeeFormula.fromJson(Map<String, dynamic> j) => ShipFeeFormula(
        a: j['a'] as num? ?? 12000,
        b: j['b'] as num? ?? 5000,
        c: j['c'] as num? ?? 0,
      );

  double calculate(double distanceKm) =>
      (a + b * distanceKm) * (1 + c / 100);
}

// ─── StoreStats ───────────────────────────────────────────────────────────────

class StoreStats {
  final double avgRating;
  final int totalReviews;

  const StoreStats({required this.avgRating, required this.totalReviews});

  factory StoreStats.fromJson(Map<String, dynamic> j) => StoreStats(
        avgRating: (j['avgRating'] as num?)?.toDouble() ?? 0.0,
        totalReviews: (j['totalReviews'] as num?)?.toInt() ?? 0,
      );
}

// ─── StoreBankAccount ─────────────────────────────────────────────────────────

class StoreBankAccount {
  final String number;
  final String bank;
  final String holder;
  final String? qrImage;

  const StoreBankAccount({
    required this.number,
    required this.bank,
    required this.holder,
    this.qrImage,
  });

  factory StoreBankAccount.fromJson(Map<String, dynamic> j) => StoreBankAccount(
        number: j['number'] as String? ?? '',
        bank: j['bank'] as String? ?? '',
        holder: j['holder'] as String? ?? '',
        qrImage: j['qrImage'] as String?,
      );
}

// ─── StorePaymentMethods ──────────────────────────────────────────────────────

class StorePaymentMethods {
  final bool bankTransfer;
  final bool cod;
  final bool fiftyFifty;
  final bool momo;
  final bool zaloPay;

  const StorePaymentMethods({
    required this.bankTransfer,
    required this.cod,
    required this.fiftyFifty,
    required this.momo,
    required this.zaloPay,
  });

  factory StorePaymentMethods.fromJson(Map<String, dynamic> j) =>
      StorePaymentMethods(
        bankTransfer: j['bankTransfer'] as bool? ?? false,
        cod: j['cod'] as bool? ?? false,
        fiftyFifty: j['fiftyFifty'] as bool? ?? false,
        momo: j['momo'] as bool? ?? false,
        zaloPay: j['zaloPay'] as bool? ?? false,
      );
}

// ─── StoreStatus ──────────────────────────────────────────────────────────────

enum StoreStatus { open, preOrder, emergencyClosed, suspended }

// ─── Store ────────────────────────────────────────────────────────────────────

class Store {
  final String id;
  final String name;
  final String? description;
  final String? coverImage;
  final List<String> coverImages;
  final String? avatarImage;
  final String addressText;
  final double? lat;
  final double? lng;
  final bool emergencyClosed;
  final bool isSuspended;
  final bool isAdLockedByAdmin;
  final List<StoreHours> openingHours;
  final StoreBankAccount? bankAccount;
  final StorePaymentMethods? paymentMethods;
  final ShipFeeFormula? shipFeeFormula;
  final int autoCancelMinutes;
  final StoreStats stats;
  final double? distanceKm;
  final String? likeId;
  final String? phone;

  const Store({
    required this.id,
    required this.name,
    this.description,
    this.coverImage,
    this.coverImages = const [],
    this.avatarImage,
    required this.addressText,
    this.lat,
    this.lng,
    required this.emergencyClosed,
    required this.isSuspended,
    required this.isAdLockedByAdmin,
    required this.openingHours,
    this.bankAccount,
    this.paymentMethods,
    this.shipFeeFormula,
    this.autoCancelMinutes = 15,
    required this.stats,
    this.distanceKm,
    this.likeId,
    this.phone,
  });

  factory Store.fromJson(Map<String, dynamic> j) {
    final address = j['address'] as Map<String, dynamic>? ?? {};
    final coords = (address['location']?['coordinates'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    return Store(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      description: j['description'] as String?,
      coverImage: j['coverImage'] as String?,
      coverImages: (j['coverImages'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      avatarImage: j['avatarImage'] as String?,
      addressText: address['text'] as String? ?? '',
      lat: coords.length >= 2 ? coords[1] : null,
      lng: coords.isNotEmpty ? coords[0] : null,
      emergencyClosed: j['emergencyClosed'] as bool? ?? false,
      isSuspended: j['isSuspended'] as bool? ?? false,
      isAdLockedByAdmin: j['isAdLockedByAdmin'] as bool? ?? false,
      openingHours: (j['openingHours'] as List<dynamic>? ?? [])
          .map((e) => StoreHours.fromJson(e as Map<String, dynamic>))
          .toList(),
      bankAccount: j['bankAccount'] != null
          ? StoreBankAccount.fromJson(j['bankAccount'] as Map<String, dynamic>)
          : null,
      paymentMethods: j['paymentMethods'] != null
          ? StorePaymentMethods.fromJson(
              j['paymentMethods'] as Map<String, dynamic>)
          : null,
      shipFeeFormula: j['shipFeeFormula'] != null
          ? ShipFeeFormula.fromJson(j['shipFeeFormula'] as Map<String, dynamic>)
          : null,
      autoCancelMinutes: (j['autoCancelMinutes'] as num?)?.toInt() ?? 15,
      stats: j['stats'] != null
          ? StoreStats.fromJson(j['stats'] as Map<String, dynamic>)
          : const StoreStats(avgRating: 0, totalReviews: 0),
      distanceKm: (j['distanceKm'] as num?)?.toDouble(),
      likeId: j['likeId'] as String?,
      phone: j['phone'] as String?,
    );
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  /// Trả về danh sách ảnh bìa để hiển thị carousel.
  /// Ưu tiên `coverImages`, fallback về `coverImage` nếu mảng rỗng.
  List<String> get allCoverImages {
    if (coverImages.isNotEmpty) return coverImages;
    if (coverImage != null && coverImage!.isNotEmpty) return [coverImage!];
    return [];
  }

  StoreStatus get displayStatus {
    if (emergencyClosed || isSuspended) return StoreStatus.emergencyClosed;
    if (isCurrentlyOpen) return StoreStatus.open;
    return StoreStatus.preOrder;
  }

  bool get isCurrentlyOpen {
    final now = DateTime.now();
    final dow = now.weekday == 7 ? 0 : now.weekday;
    final todayHours =
        openingHours.where((h) => h.dayOfWeek == dow).toList();
    if (todayHours.isEmpty) return false;
    final h = todayHours.first;
    if (h.isClosed) return false;
    int toMin(String t) {
      final p = t.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }
    final nowMin = now.hour * 60 + now.minute;
    return nowMin >= toMin(h.open) && nowMin < toMin(h.close);
  }

  bool get isHiddenFromFeed => emergencyClosed || isSuspended;
}

// lib/core/models/store.dart
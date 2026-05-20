// lib/features/home/models/store_card.dart

class StoreCard {
  final String id;
  final String name;
  final String? description;
  final String? avatarImage;
  final String? coverImage;
  final String addressText;
  final double? distanceKm;
  final bool isOpen;
  final bool emergencyClosed;
  final double avgRating;
  final int totalReviews;
  final String vipTier;

  const StoreCard({
    required this.id,
    required this.name,
    this.description,
    this.avatarImage,
    this.coverImage,
    required this.addressText,
    this.distanceKm,
    required this.isOpen,
    required this.emergencyClosed,
    required this.avgRating,
    required this.totalReviews,
    required this.vipTier,
  });

  factory StoreCard.fromJson(Map<String, dynamic> j) => StoreCard(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        avatarImage: j['avatarImage'] as String?,
        coverImage: j['coverImage'] as String?,
        addressText: j['addressText'] as String? ?? '',
        distanceKm: (j['distanceKm'] as num?)?.toDouble(),
        isOpen: j['isOpen'] as bool? ?? false,
        emergencyClosed: j['emergencyClosed'] as bool? ?? false,
        avgRating: (j['avgRating'] as num?)?.toDouble() ?? 0.0,
        totalReviews: j['totalReviews'] as int? ?? 0,
        vipTier: j['vipTier'] as String? ?? 'none',
      );

  bool get effectivelyOpen => isOpen && !emergencyClosed;
}

List<StoreCard> _parseList(dynamic raw) =>
    (raw as List<dynamic>? ?? [])
        .map((e) => StoreCard.fromJson(e as Map<String, dynamic>))
        .toList();

class HomeFeedData {
  final List<StoreCard> newStores;
  final List<StoreCard> trendingStores;
  final List<StoreCard> recentPurchases;
  final List<StoreCard> favorites;
  final List<StoreCard> nearbyStores;
  final int? nextCursor;
  final bool hasMore;

  const HomeFeedData({
    this.newStores = const [],
    this.trendingStores = const [],
    this.recentPurchases = const [],
    this.favorites = const [],
    this.nearbyStores = const [],
    this.nextCursor,
    this.hasMore = false,
  });

  factory HomeFeedData.fromJson(Map<String, dynamic> j) => HomeFeedData(
        newStores: _parseList(j['newStores']),
        trendingStores: _parseList(j['trendingStores']),
        recentPurchases: _parseList(j['recentPurchases']),
        favorites: _parseList(j['favorites']),
        nearbyStores: _parseList(j['nearbyStores']),
        nextCursor: j['nextCursor'] as int?,
        hasMore: j['hasMore'] as bool? ?? false,
      );

  HomeFeedData appendNearby(
    List<StoreCard> more,
    int? cursor,
    // ignore: non_constant_identifier_names
    bool hasMore_,
  ) =>
      HomeFeedData(
        newStores: newStores,
        trendingStores: trendingStores,
        recentPurchases: recentPurchases,
        favorites: favorites,
        nearbyStores: [...nearbyStores, ...more],
        nextCursor: cursor,
        hasMore: hasMore_,
      );
}

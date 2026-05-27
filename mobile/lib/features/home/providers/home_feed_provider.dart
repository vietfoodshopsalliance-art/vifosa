// lib/features/home/providers/home_feed_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/providers/location_provider.dart';
import '../models/food_item_card.dart';
import '../models/store_card.dart';
import '../../auth/providers/auth_provider.dart';

const _defaultRadius = 25;

// ── Single /home-feed call ────────────────────────────────────────────────────

final homeFeedDataProvider =
    FutureProvider.family<HomeFeedData, int>((ref, radius) async {
  final loc = await ref.read(locationProvider.future);
  final res = await ref.read(dioClientProvider).dio.get(
    '/home-feed',
    queryParameters: {
      'lat': loc.lat,
      'lng': loc.lng,
      'radius': radius,
    },
  );
  return HomeFeedData.fromJson(res.data as Map<String, dynamic>);
});

// ── Section providers ─────────────────────────────────────────────────────────

final newStoresProvider =
    Provider<AsyncValue<List<StoreCard>>>((ref) =>
        ref.watch(homeFeedDataProvider(_defaultRadius)).whenData((d) => d.newStores));

final popularStoresProvider =
    Provider<AsyncValue<List<StoreCard>>>((ref) =>
        ref.watch(homeFeedDataProvider(_defaultRadius)).whenData((d) => d.trendingStores));

final recentPurchaseStoresProvider =
    Provider<AsyncValue<List<StoreCard>>>((ref) =>
        ref.watch(homeFeedDataProvider(_defaultRadius)).whenData((d) => d.recentPurchases));

final favoriteStoresProvider =
    Provider<AsyncValue<List<StoreCard>>>((ref) =>
        ref.watch(homeFeedDataProvider(_defaultRadius)).whenData((d) => d.favorites));

// ── Nearby: stores + items (infinite scroll via cursor) ───────────────────────

class NearbyState {
  final List<FoodItemCard> newStoreItems;
  final List<FoodItemCard> topSellingItems;
  final List<FoodItemCard> topReviewedStoreItems;
  final List<FoodItemCard> personalItems;
  final List<StoreCard> stores;
  final List<FoodItemCard> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int? nextCursor;

  const NearbyState({
    this.newStoreItems = const [],
    this.topSellingItems = const [],
    this.topReviewedStoreItems = const [],
    this.personalItems = const [],
    this.stores = const [],
    this.items = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
    this.nextCursor,
  });

  NearbyState copyWith({
    List<FoodItemCard>? newStoreItems,
    List<FoodItemCard>? topSellingItems,
    List<FoodItemCard>? topReviewedStoreItems,
    List<FoodItemCard>? personalItems,
    List<StoreCard>? stores,
    List<FoodItemCard>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? nextCursor,
  }) =>
      NearbyState(
        newStoreItems: newStoreItems ?? this.newStoreItems,
        topSellingItems: topSellingItems ?? this.topSellingItems,
        topReviewedStoreItems: topReviewedStoreItems ?? this.topReviewedStoreItems,
        personalItems: personalItems ?? this.personalItems,
        stores: stores ?? this.stores,
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: error,
        nextCursor: nextCursor ?? this.nextCursor,
      );
}

class NearbyNotifier extends StateNotifier<NearbyState> {
  NearbyNotifier(this._ref) : super(const NearbyState()) {
    _init();
    _ref.listen<bool>(
      authProvider.select((s) => s.isAuthenticated),
      (prev, next) {
        if (prev != null && prev != next) refresh();
      },
    );
  }

  final Ref _ref;

  Future<void> _init() async {
    state = const NearbyState(isLoading: true);
    try {
      final data = await _ref.read(homeFeedDataProvider(_defaultRadius).future);
      state = NearbyState(
        newStoreItems: data.newStoreItems,
        topSellingItems: data.topSellingItems,
        topReviewedStoreItems: data.topReviewedStoreItems,
        personalItems: data.personalItems,
        stores: data.nearbyStores,
        items: data.nearbyItems,
        isLoading: false,
        hasMore: data.hasMore,
        nextCursor: data.nextCursor,
      );
    } catch (e) {
      state = NearbyState(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    _ref.invalidate(homeFeedDataProvider(_defaultRadius));
    await _init();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    if (state.nextCursor == null) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final loc = await _ref.read(locationProvider.future);
      final res = await _ref.read(dioClientProvider).dio.get(
        '/home-feed',
        queryParameters: {
          'lat': loc.lat,
          'lng': loc.lng,
          'radius': _defaultRadius,
          'cursor': state.nextCursor,
        },
      );
      final d = res.data as Map<String, dynamic>;
      final moreStores = (d['nearbyStores'] as List<dynamic>? ?? [])
          .map((e) => StoreCard.fromJson(e as Map<String, dynamic>))
          .toList();
      final moreItems = parseFoodItems(d['nearbyItems']);
      state = NearbyState(
        newStoreItems: state.newStoreItems,
        topSellingItems: state.topSellingItems,
        topReviewedStoreItems: state.topReviewedStoreItems,
        personalItems: state.personalItems,
        stores: [...state.stores, ...moreStores],
        items: [...state.items, ...moreItems],
        isLoading: false,
        hasMore: d['hasMore'] as bool? ?? false,
        nextCursor: d['nextCursor'] as int?,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }
}

final nearbyStoresProvider =
    StateNotifierProvider<NearbyNotifier, NearbyState>(
  (ref) => NearbyNotifier(ref),
);

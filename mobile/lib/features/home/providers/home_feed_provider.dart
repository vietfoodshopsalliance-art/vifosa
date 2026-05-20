// lib/features/home/providers/home_feed_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/providers/location_provider.dart';
import '../models/store_card.dart';

// ── Radius ────────────────────────────────────────────────────────────────────

final selectedRadiusProvider = StateProvider<int>((ref) => 5);

// ── Single /home-feed call ────────────────────────────────────────────────────

final homeFeedDataProvider =
    FutureProvider.autoDispose.family<HomeFeedData, int>((ref, radius) async {
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

// ── Section providers derived from the single feed ────────────────────────────

final newStoresProvider =
    Provider.autoDispose.family<AsyncValue<List<StoreCard>>, int>((ref, radius) {
  return ref.watch(homeFeedDataProvider(radius)).whenData((d) => d.newStores);
});

final popularStoresProvider =
    Provider.autoDispose.family<AsyncValue<List<StoreCard>>, int>((ref, radius) {
  return ref.watch(homeFeedDataProvider(radius)).whenData((d) => d.trendingStores);
});

final recentPurchaseStoresProvider =
    Provider.autoDispose<AsyncValue<List<StoreCard>>>((ref) {
  final radius = ref.watch(selectedRadiusProvider);
  return ref.watch(homeFeedDataProvider(radius)).whenData((d) => d.recentPurchases);
});

final favoriteStoresProvider =
    Provider.autoDispose<AsyncValue<List<StoreCard>>>((ref) {
  final radius = ref.watch(selectedRadiusProvider);
  return ref.watch(homeFeedDataProvider(radius)).whenData((d) => d.favorites);
});

// ── Nearby section: infinite scroll (load-more via cursor) ───────────────────

class NearbyState {
  final List<StoreCard> stores;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int? nextCursor;

  const NearbyState({
    this.stores = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
    this.nextCursor,
  });

  NearbyState copyWith({
    List<StoreCard>? stores,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? nextCursor,
  }) =>
      NearbyState(
        stores: stores ?? this.stores,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: error,
        nextCursor: nextCursor ?? this.nextCursor,
      );
}

class NearbyNotifier extends StateNotifier<NearbyState> {
  NearbyNotifier(this._ref) : super(const NearbyState()) {
    _ref.listen<int>(selectedRadiusProvider, (_, radius) {
      _init(radius);
    });
    _init(_ref.read(selectedRadiusProvider));
  }

  final Ref _ref;

  Future<void> _init(int radius) async {
    state = const NearbyState(isLoading: true);
    try {
      final data = await _ref.read(homeFeedDataProvider(radius).future);
      state = NearbyState(
        stores: data.nearbyStores,
        isLoading: false,
        hasMore: data.hasMore,
        nextCursor: data.nextCursor,
      );
    } catch (e) {
      state = NearbyState(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    final radius = _ref.read(selectedRadiusProvider);
    _ref.invalidate(homeFeedDataProvider(radius));
    await _init(radius);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    if (state.nextCursor == null) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final radius = _ref.read(selectedRadiusProvider);
      final loc = await _ref.read(locationProvider.future);
      final res = await _ref.read(dioClientProvider).dio.get(
        '/home-feed',
        queryParameters: {
          'lat': loc.lat,
          'lng': loc.lng,
          'radius': radius,
          'cursor': state.nextCursor,
        },
      );
      final d = res.data as Map<String, dynamic>;
      final moreStores = (d['nearbyStores'] as List<dynamic>? ?? [])
          .map((e) => StoreCard.fromJson(e as Map<String, dynamic>))
          .toList();
      state = NearbyState(
        stores: [...state.stores, ...moreStores],
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
    StateNotifierProvider.autoDispose<NearbyNotifier, NearbyState>(
  (ref) => NearbyNotifier(ref),
);

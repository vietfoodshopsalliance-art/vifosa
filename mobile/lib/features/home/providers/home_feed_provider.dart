// lib/features/home/providers/home_feed_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/providers/location_provider.dart';
import '../models/store_card.dart';
import '../../auth/providers/auth_provider.dart';

// Radius cố định 25km — đủ bao phủ nội thành TP.HCM.
// Tăng lên khi DB có nhiều store hơn và cần thu hẹp vùng.
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

// ── Section providers derived from the single feed ────────────────────────────

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
    StateNotifierProvider<NearbyNotifier, NearbyState>(
  (ref) => NearbyNotifier(ref),
);

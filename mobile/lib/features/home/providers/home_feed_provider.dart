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
  static const _radii = [5, 10, 25];

  NearbyNotifier(this._ref) : super(const NearbyState()) {
    _init(5);
  }

  final Ref _ref;
  int _effectiveRadius = 5; // radius thực sự có quán

  // Issue 7: Tự động mở rộng bán kính 5→10→25 khi không có quán
  Future<void> _init(int startRadius) async {
    state = const NearbyState(isLoading: true);

    final startIdx = _radii.indexOf(startRadius).clamp(0, _radii.length - 1);

    for (int i = startIdx; i < _radii.length; i++) {
      final radius = _radii[i];
      try {
        final data = await _ref.read(homeFeedDataProvider(radius).future);
        if (data.nearbyStores.isNotEmpty || i == _radii.length - 1) {
          _effectiveRadius = radius;
          state = NearbyState(
            stores: data.nearbyStores,
            isLoading: false,
            hasMore: data.hasMore,
            nextCursor: data.nextCursor,
          );
          return;
        }
        // nearbyStores rỗng, thử bán kính lớn hơn
      } catch (e) {
        state = NearbyState(isLoading: false, error: e.toString());
        return;
      }
    }
  }

  Future<void> refresh() async {
    // Invalidate cache của tất cả các bán kính
    for (final r in _radii) {
      _ref.invalidate(homeFeedDataProvider(r));
    }
    _effectiveRadius = 5;
    await _init(5);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    if (state.nextCursor == null) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final radius = _effectiveRadius; // dùng radius đã tìm được quán
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

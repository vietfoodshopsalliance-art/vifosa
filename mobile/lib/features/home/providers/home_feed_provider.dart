// lib/features/home/providers/home_feed_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/providers/location_provider.dart';
import '../models/store_card.dart';
import '../../auth/providers/auth_provider.dart';

// ── Radius ────────────────────────────────────────────────────────────────────

final selectedRadiusProvider = StateProvider<int>((ref) => 5);

// Radius thực sự có quán — được cập nhật bởi NearbyNotifier khi auto-expand.
// Tất cả section dùng chung radius này để tránh nhiều API call và đảm bảo
// "Quán mới" / "Bán chạy" dùng cùng dữ liệu với "Quán gần bạn".
final effectiveRadiusProvider = StateProvider<int>((ref) => 5);

// ── Single /home-feed call ────────────────────────────────────────────────────

final homeFeedDataProvider =
    FutureProvider.autoDispose.family<HomeFeedData, int>((ref, radius) async {
  // Re-fetch khi trạng thái đăng nhập thay đổi (guest→logged in hoặc logout)
  // để backend có thể trả favorites / recentPurchases theo đúng user.
  ref.watch(authProvider.select((s) => s.isAuthenticated));

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
// Tất cả dùng effectiveRadiusProvider để dùng chung 1 API call với NearbySection.

final newStoresProvider =
    Provider.autoDispose<AsyncValue<List<StoreCard>>>((ref) {
  final radius = ref.watch(effectiveRadiusProvider);
  return ref.watch(homeFeedDataProvider(radius)).whenData((d) => d.newStores);
});

final popularStoresProvider =
    Provider.autoDispose<AsyncValue<List<StoreCard>>>((ref) {
  final radius = ref.watch(effectiveRadiusProvider);
  return ref.watch(homeFeedDataProvider(radius)).whenData((d) => d.trendingStores);
});

final recentPurchaseStoresProvider =
    Provider.autoDispose<AsyncValue<List<StoreCard>>>((ref) {
  final radius = ref.watch(effectiveRadiusProvider);
  return ref.watch(homeFeedDataProvider(radius)).whenData((d) => d.recentPurchases);
});

final favoriteStoresProvider =
    Provider.autoDispose<AsyncValue<List<StoreCard>>>((ref) {
  final radius = ref.watch(effectiveRadiusProvider);
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
  int _effectiveRadius = 5;

  // Tự động mở rộng bán kính 5→10→25 khi không có quán.
  // Cập nhật effectiveRadiusProvider để các section khác dùng cùng radius.
  Future<void> _init(int startRadius) async {
    state = const NearbyState(isLoading: true);
    // Reset về startRadius ngay lập tức để tránh flash dữ liệu cũ từ lần trước
    _ref.read(effectiveRadiusProvider.notifier).state = startRadius;

    final startIdx = _radii.indexOf(startRadius).clamp(0, _radii.length - 1);

    for (int i = startIdx; i < _radii.length; i++) {
      final radius = _radii[i];
      try {
        final data = await _ref.read(homeFeedDataProvider(radius).future);
        if (data.nearbyStores.isNotEmpty || i == _radii.length - 1) {
          _effectiveRadius = radius;
          // Cập nhật để newStores / trendingStores dùng cùng radius
          _ref.read(effectiveRadiusProvider.notifier).state = radius;
          state = NearbyState(
            stores: data.nearbyStores,
            isLoading: false,
            hasMore: data.hasMore,
            nextCursor: data.nextCursor,
          );
          return;
        }
        // nearbyStores rỗng → thử bán kính lớn hơn
      } catch (e) {
        state = NearbyState(isLoading: false, error: e.toString());
        return;
      }
    }
  }

  Future<void> refresh() async {
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
      final radius = _effectiveRadius;
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

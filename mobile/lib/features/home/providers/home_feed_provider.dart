// lib/features/home/providers/home_feed_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/providers/location_provider.dart';
import '../models/store_card.dart';

// ── Radius ────────────────────────────────────────────────────────────────────

final homeFeedRadiusProvider = StateProvider<int>((ref) => 5);

// ── Feed state ────────────────────────────────────────────────────────────────

class HomeFeedState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final HomeFeedData? data;

  const HomeFeedState({
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.data,
  });

  HomeFeedState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    HomeFeedData? data,
  }) =>
      HomeFeedState(
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: error,
        data: data ?? this.data,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class HomeFeedNotifier extends StateNotifier<HomeFeedState> {
  HomeFeedNotifier(this._ref) : super(const HomeFeedState()) {
    // Re-fetch whenever radius changes
    _ref.listen<int>(homeFeedRadiusProvider, (_, radius) => _fetch(radius: radius));
    _fetch(radius: _ref.read(homeFeedRadiusProvider));
  }

  final Ref _ref;

  Future<void> _fetch({required int radius}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final location = await _ref.read(locationProvider.future);
      final client = _ref.read(dioClientProvider);
      final res = await client.dio.get(
        ApiEndpoints.homeFeed,
        queryParameters: {
          'lat': location.lat,
          'lng': location.lng,
          'radius': radius,
        },
      );
      final raw = res.data as Map<String, dynamic>;
      state = state.copyWith(
        isLoading: false,
        data: HomeFeedData.fromJson(raw),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => _fetch(radius: _ref.read(homeFeedRadiusProvider));

  Future<void> loadMore() async {
    final data = state.data;
    if (data == null || !data.hasMore || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final location = await _ref.read(locationProvider.future);
      final radius = _ref.read(homeFeedRadiusProvider);
      final client = _ref.read(dioClientProvider);
      final res = await client.dio.get(
        ApiEndpoints.homeFeed,
        queryParameters: {
          'lat': location.lat,
          'lng': location.lng,
          'radius': radius,
          'cursor': data.nextCursor,
        },
      );
      final raw = res.data as Map<String, dynamic>;
      final newData = HomeFeedData.fromJson(raw);
      state = state.copyWith(
        isLoadingMore: false,
        data: data.appendNearby(newData.nearbyStores, newData.nextCursor, newData.hasMore),
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final homeFeedProvider =
    StateNotifierProvider<HomeFeedNotifier, HomeFeedState>(
  (ref) => HomeFeedNotifier(ref),
);

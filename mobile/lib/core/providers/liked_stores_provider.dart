// lib/core/providers/liked_stores_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/store.dart';
import '../network/api_endpoints.dart';
import '../network/dio_client.dart';
import '../../features/auth/providers/auth_provider.dart';

// State: storeId → likeId (null = not liked, non-null = liked, key absent = unknown)
class LikedStoresNotifier extends StateNotifier<Map<String, String?>> {
  LikedStoresNotifier() : super({});

  bool _loaded = false;

  Future<void> loadIfNeeded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final res = await DioClient.instance.get(ApiEndpoints.favoriteStores);
      final raw = res.data is Map
          ? (res.data['stores'] ?? res.data['data'] ?? [])
          : res.data;
      final Map<String, String?> map = {};
      for (final e in raw as List) {
        final store = Store.fromJson(e as Map<String, dynamic>);
        if (store.id.isNotEmpty) map[store.id] = store.likeId;
      }
      state = map;
    } catch (_) {
      _loaded = false;
    }
  }

  Future<void> reload() async {
    _loaded = false;
    await loadIfNeeded();
  }

  Future<void> toggle(String storeId) async {
    final current = Map<String, String?>.from(state);
    final likeId = current[storeId];
    if (likeId == '__pending__') return;
    final isLiked = likeId != null;

    if (isLiked) {
      state = {...current, storeId: null};
      try {
        await DioClient.instance.delete(ApiEndpoints.likeDelete(likeId));
      } catch (_) {
        state = current;
      }
    } else {
      state = {...current, storeId: '__pending__'};
      try {
        final res = await DioClient.instance.post(
          ApiEndpoints.likes,
          data: {'type': 'store', 'targetId': storeId},
        );
        final newId =
            (res.data['_id'] ?? res.data['id'] ?? res.data['likeId'])
                    as String? ??
                '__liked__';
        state = {...state, storeId: newId};
      } catch (_) {
        state = current;
      }
    }
  }

  void clear() {
    state = {};
    _loaded = false;
  }
}

final likedStoresProvider =
    StateNotifierProvider<LikedStoresNotifier, Map<String, String?>>((ref) {
  final notifier = LikedStoresNotifier();

  ref.listen<AuthState>(authProvider, (prev, next) {
    if (next.isAuthenticated) {
      notifier.loadIfNeeded();
    } else {
      notifier.clear();
    }
  });

  if (ref.read(authProvider).isAuthenticated) {
    Future.microtask(() => notifier.loadIfNeeded());
  }

  return notifier;
});

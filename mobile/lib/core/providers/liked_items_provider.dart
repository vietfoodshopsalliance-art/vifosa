// lib/core/providers/liked_items_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../models/menu_item.dart';
import '../network/api_endpoints.dart';
import '../network/dio_client.dart';

// State: itemId → likeId (null = not liked, non-null = liked, key absent = unknown)
class LikedItemsNotifier extends StateNotifier<Map<String, String?>> {
  LikedItemsNotifier() : super({});

  bool _loaded = false;

  Future<void> loadIfNeeded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final res = await DioClient.instance.get(ApiEndpoints.favoriteItems);
      final raw = res.data is Map
          ? (res.data['items'] ?? res.data['data'] ?? [])
          : res.data;
      final Map<String, String?> map = {};
      for (final e in raw as List) {
        final item = MenuItem.fromJson(e as Map<String, dynamic>);
        if (item.id.isNotEmpty) map[item.id] = item.likeId;
      }
      state = map;
    } catch (_) {
      _loaded = false;
    }
  }

  Future<void> toggle(String itemId) async {
    final current = Map<String, String?>.from(state);
    final likeId = current[itemId];
    if (likeId == '__pending__') return; // đang xử lý, bỏ qua
    final isLiked = likeId != null;

    if (isLiked) {
      state = {...current, itemId: null};
      try {
        await DioClient.instance.delete(ApiEndpoints.likeDelete(likeId));
      } catch (_) {
        state = current;
      }
    } else {
      state = {...current, itemId: '__pending__'};
      try {
        final res = await DioClient.instance.post(
          ApiEndpoints.likes,
          data: {'type': 'item', 'targetId': itemId},
        );
        final newId =
            (res.data['_id'] ?? res.data['id'] ?? res.data['likeId'])
                    as String? ??
                '__liked__';
        state = {...state, itemId: newId};
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

final likedItemsProvider =
    StateNotifierProvider<LikedItemsNotifier, Map<String, String?>>((ref) {
  final notifier = LikedItemsNotifier();

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

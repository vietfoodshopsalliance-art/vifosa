// lib/features/store_dashboard/menu/store_menu_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/store_menu_item.dart';

class MenuState {
  final List<StoreCategory> categories;
  const MenuState({this.categories = const []});
}

class MenuNotifier extends StateNotifier<AsyncValue<MenuState>> {
  final String storeId;

  MenuNotifier(this.storeId) : super(const AsyncValue.loading()) {
    fetchMenu();
  }

  Future<void> fetchMenu() async {
    state = const AsyncValue.loading();
    try {
      final res = await DioClient.instance.get('/stores/$storeId/menu');
      final rawCats = (res.data is Map ? res.data['categories'] : res.data) as List? ?? [];
      final categories = rawCats
          .map((e) => StoreCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(MenuState(categories: categories));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addCategory(String name) async {
    await DioClient.instance.post('/stores/$storeId/categories', data: {'name': name});
    await fetchMenu();
  }

  Future<void> updateCategory(String catId, String name) async {
    await DioClient.instance.patch('/stores/$storeId/categories/$catId', data: {'name': name});
    await fetchMenu();
  }

  Future<void> deleteCategory(String catId) async {
    await DioClient.instance.delete('/stores/$storeId/categories/$catId');
    await fetchMenu();
  }

  Future<void> toggleItemVisibility(StoreMenuItem item) async {
    final next = item.status == 'active' ? 'paused' : 'active';
    await DioClient.instance.patch('/stores/$storeId/items/${item.id}/status', data: {'status': next});
    await fetchMenu();
  }
}

final storeMenuProvider =
    StateNotifierProvider.family<MenuNotifier, AsyncValue<MenuState>, String>(
  (ref, storeId) => MenuNotifier(storeId),
);

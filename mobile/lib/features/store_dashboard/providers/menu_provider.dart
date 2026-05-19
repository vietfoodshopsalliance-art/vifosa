// mobile/lib/features/store_dashboard/providers/menu_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_models.dart';
import '../repositories/menu_repository.dart';
import '../../../core/providers/dio_provider.dart'; // đã có từ module 01/02

// ── Repository provider ─────────────────────────────────────────────────────

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(ref.watch(dioProvider));
});

// ── Full menu (dashboard view — tất cả status) ──────────────────────────────

final dashboardMenuProvider =
    FutureProvider.family<List<MenuCategory>, String>((ref, storeId) async {
  return ref.watch(menuRepositoryProvider).getFullMenu(storeId, forCustomer: false);
});

// ── Customer menu (chỉ active + stock > 0) ──────────────────────────────────

final customerMenuProvider =
    FutureProvider.family<List<MenuCategory>, String>((ref, storeId) async {
  return ref.watch(menuRepositoryProvider).getFullMenu(storeId, forCustomer: true);
});

// ── Notifier: thao tác write (create/update/delete) ─────────────────────────

class MenuNotifier extends AsyncNotifier<void> {
  MenuRepository get _repo => ref.read(menuRepositoryProvider);

  @override
  Future<void> build() async {}

  Future<void> createCategory(String storeId, String name) async {
    await _repo.createCategory(storeId, name);
    ref.invalidate(dashboardMenuProvider(storeId));
  }

  Future<void> reorderCategories(
      String storeId, List<Map<String, dynamic>> items) async {
    await _repo.reorderCategories(storeId, items);
    ref.invalidate(dashboardMenuProvider(storeId));
  }

  Future<void> deleteCategory(String storeId, String catId) async {
    await _repo.deleteCategory(storeId, catId);
    ref.invalidate(dashboardMenuProvider(storeId));
  }

  Future<void> createItem(String storeId, Map<String, dynamic> body) async {
    await _repo.createItem(storeId, body);
    ref.invalidate(dashboardMenuProvider(storeId));
  }

  Future<void> updateItem(
      String storeId, String itemId, Map<String, dynamic> body) async {
    await _repo.updateItem(storeId, itemId, body);
    ref.invalidate(dashboardMenuProvider(storeId));
  }

  Future<void> deleteItem(String storeId, String itemId) async {
    await _repo.deleteItem(storeId, itemId);
    ref.invalidate(dashboardMenuProvider(storeId));
  }

  Future<void> updateStock(String storeId, String itemId, int? stock) async {
    await _repo.updateStock(storeId, itemId, stock);
    ref.invalidate(dashboardMenuProvider(storeId));
  }

  Future<void> toggleStatus(String storeId, String itemId, String currentStatus) async {
    final next = currentStatus == 'active' ? 'paused' : 'active';
    await _repo.updateStatus(storeId, itemId, next);
    ref.invalidate(dashboardMenuProvider(storeId));
  }
}

final menuNotifierProvider = AsyncNotifierProvider<MenuNotifier, void>(MenuNotifier.new);

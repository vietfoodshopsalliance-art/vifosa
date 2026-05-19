// mobile/lib/features/store_dashboard/repositories/menu_repository.dart

import 'package:dio/dio.dart';
import '../models/menu_models.dart';

class MenuRepository {
  final Dio _dio;

  MenuRepository(this._dio);

  // ── CATEGORIES ──────────────────────────────────────────────────────────

  Future<List<MenuCategory>> getCategories(String storeId) async {
    final res = await _dio.get('/stores/$storeId/categories');
    return (res.data as List)
        .map((e) => MenuCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MenuCategory> createCategory(String storeId, String name) async {
    final res = await _dio.post('/stores/$storeId/categories', data: {'name': name});
    return MenuCategory.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> updateCategory(String storeId, String catId, {String? name, int? displayOrder}) async {
    await _dio.patch('/stores/$storeId/categories/$catId', data: {
      if (name != null) 'name': name,
      if (displayOrder != null) 'displayOrder': displayOrder,
    });
  }

  Future<void> deleteCategory(String storeId, String catId) async {
    await _dio.delete('/stores/$storeId/categories/$catId');
  }

  /// items: [{id, displayOrder}]
  Future<void> reorderCategories(
      String storeId, List<Map<String, dynamic>> items) async {
    await _dio.patch('/stores/$storeId/categories/reorder', data: {'items': items});
  }

  // ── MENU ────────────────────────────────────────────────────────────────

  /// forCustomer = true → chỉ lấy active + stock > 0 (dùng ở StoreDetailPage)
  Future<List<MenuCategory>> getFullMenu(String storeId,
      {bool forCustomer = false}) async {
    final res = await _dio.get(
      '/stores/$storeId/menu',
      queryParameters: {'forCustomer': forCustomer.toString()},
    );
    final data = res.data as Map<String, dynamic>;
    return (data['categories'] as List)
        .map((e) => MenuCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── ITEMS ────────────────────────────────────────────────────────────────

  Future<MenuItem> createItem(String storeId, Map<String, dynamic> body) async {
    final res = await _dio.post('/stores/$storeId/items', data: body);
    return MenuItem.fromJson(res.data as Map<String, dynamic>);
  }

  Future<MenuItem> updateItem(
      String storeId, String itemId, Map<String, dynamic> body) async {
    final res = await _dio.patch('/stores/$storeId/items/$itemId', data: body);
    return MenuItem.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteItem(String storeId, String itemId) async {
    await _dio.delete('/stores/$storeId/items/$itemId');
  }

  /// urls: danh sách Cloudinary URL đã upload từ client
  Future<List<String>> addImages(
      String storeId, String itemId, List<String> urls) async {
    final res = await _dio.post(
      '/stores/$storeId/items/$itemId/images',
      data: {'urls': urls},
    );
    return List<String>.from((res.data as Map)['images'] as List);
  }

  Future<List<String>> deleteImage(
      String storeId, String itemId, int imageIndex) async {
    final res = await _dio.delete(
      '/stores/$storeId/items/$itemId/images/$imageIndex',
    );
    return List<String>.from((res.data as Map)['images'] as List);
  }

  Future<void> updateStock(String storeId, String itemId, int? stock) async {
    await _dio.patch(
      '/stores/$storeId/items/$itemId/stock',
      data: {'stock': stock},
    );
  }

  Future<void> updateStatus(String storeId, String itemId, String status) async {
    await _dio.patch(
      '/stores/$storeId/items/$itemId/status',
      data: {'status': status},
    );
  }
}
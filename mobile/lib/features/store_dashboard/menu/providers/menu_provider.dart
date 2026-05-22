// lib/features/store_dashboard/menu/providers/menu_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class MenuCategory {
  final String id;
  final String name;
  final int displayOrder;

  const MenuCategory({
    required this.id,
    required this.name,
    required this.displayOrder,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) => MenuCategory(
        id: json['_id'] as String,
        name: json['name'] as String,
        displayOrder: json['displayOrder'] as int? ?? 0,
      );

  MenuCategory copyWith({String? name, int? displayOrder}) => MenuCategory(
        id: id,
        name: name ?? this.name,
        displayOrder: displayOrder ?? this.displayOrder,
      );
}

class SoldCount {
  final int allTime;
  final int last7d;
  final int last30d;
  final int last365d;

  const SoldCount({
    required this.allTime,
    required this.last7d,
    required this.last30d,
    required this.last365d,
  });

  factory SoldCount.fromJson(Map<String, dynamic> json) => SoldCount(
        allTime: json['allTime'] as int? ?? 0,
        last7d: json['last7d'] as int? ?? 0,
        last30d: json['last30d'] as int? ?? 0,
        last365d: json['last365d'] as int? ?? 0,
      );
}

class MenuItem {
  final String id;
  final String storeId;
  final String categoryId;
  final String name;
  final String? description;
  final int price;
  final List<String> images;
  final int? stock;
  final String status; // active | closed | paused
  final SoldCount? soldCount;
  final bool isDeleted;

  const MenuItem({
    required this.id,
    required this.storeId,
    required this.categoryId,
    required this.name,
    this.description,
    required this.price,
    required this.images,
    this.stock,
    required this.status,
    this.soldCount,
    this.isDeleted = false,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['_id'] as String,
        storeId: json['storeId'] as String,
        categoryId: json['categoryId'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        price: json['price'] as int,
        images: List<String>.from(json['images'] ?? []),
        stock: json['stock'] as int?,
        status: json['status'] as String? ?? 'active',
        soldCount: json['soldCount'] != null
            ? SoldCount.fromJson(json['soldCount'])
            : null,
        isDeleted: json['isDeleted'] as bool? ?? false,
      );
}

class MenuItemPayload {
  final String name;
  final String description;
  final int price;
  final String categoryId;
  final String status;
  final int? stock;

  const MenuItemPayload({
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.status,
    this.stock,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'price': price,
        'categoryId': categoryId,
        'status': status,
        if (stock != null) 'stock': stock,
      };
}

// ─── State ────────────────────────────────────────────────────────────────────

class MenuState {
  final List<MenuCategory> categories;
  final Map<String, List<MenuItem>> itemsByCategory;
  final bool isLoading;
  final String? error;

  const MenuState({
    this.categories = const [],
    this.itemsByCategory = const {},
    this.isLoading = false,
    this.error,
  });

  MenuState copyWith({
    List<MenuCategory>? categories,
    Map<String, List<MenuItem>>? itemsByCategory,
    bool? isLoading,
    String? error,
  }) =>
      MenuState(
        categories: categories ?? this.categories,
        itemsByCategory: itemsByCategory ?? this.itemsByCategory,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MenuNotifier extends StateNotifier<MenuState> {
  final String storeId;
  final ApiClient _api;

  MenuNotifier(this.storeId, this._api) : super(const MenuState());

  Future<void> fetchMenu() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.get('/stores/$storeId/menu');
      final rawCats = List<Map<String, dynamic>>.from(data['categories'] ?? []);

      final categories = <MenuCategory>[];
      final itemsByCategory = <String, List<MenuItem>>{};

      for (final catJson in rawCats) {
        final cat = MenuCategory.fromJson(catJson);
        categories.add(cat);

        final rawItems =
            List<Map<String, dynamic>>.from(catJson['items'] ?? []);
        itemsByCategory[cat.id] =
            rawItems.map((j) => MenuItem.fromJson({...j, 'storeId': storeId, 'categoryId': cat.id})).toList();
      }

      state = state.copyWith(
        categories: categories,
        itemsByCategory: itemsByCategory,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải menu. Kiểm tra kết nối.',
      );
    }
  }

  // ── Categories ───────────────────────────────────────────────────────────────

  Future<bool> addCategory(String name) async {
    try {
      final data = await _api.post('/stores/$storeId/categories', body: {
        'name': name,
      });
      final newCat = MenuCategory.fromJson(data);
      state = state.copyWith(
        categories: [...state.categories, newCat],
        itemsByCategory: {...state.itemsByCategory, newCat.id: []},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateCategory(String catId, String name) async {
    try {
      await _api.patch('/stores/$storeId/categories/$catId',
          body: {'name': name});
      state = state.copyWith(
        categories: state.categories
            .map((c) => c.id == catId ? c.copyWith(name: name) : c)
            .toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCategory(String catId) async {
    try {
      await _api.delete('/stores/$storeId/categories/$catId');
      final newCats = state.categories.where((c) => c.id != catId).toList();
      final newItems = Map<String, List<MenuItem>>.from(state.itemsByCategory)
        ..remove(catId);
      state = state.copyWith(categories: newCats, itemsByCategory: newItems);
      return true;
    } catch (e) {
      return false;
    }
  }

  void reorderCategories(int oldIndex, int newIndex) {
    final cats = List<MenuCategory>.from(state.categories);
    final moved = cats.removeAt(oldIndex);
    cats.insert(newIndex, moved);

    // Optimistic update
    state = state.copyWith(categories: cats);

    // Persist to API
    final reorderPayload = cats
        .asMap()
        .entries
        .map((e) => {'_id': e.value.id, 'displayOrder': e.key + 1})
        .toList();
    _api
        .patch('/stores/$storeId/categories/reorder',
            body: {'categories': reorderPayload})
        .then<void>((_) {}, onError: (_) => fetchMenu()); // rollback on fail
  }

  // ── Items ────────────────────────────────────────────────────────────────────

  Future<bool> addItem(MenuItemPayload payload) async {
    try {
      final data =
          await _api.post('/stores/$storeId/items', body: payload.toJson());
      final newItem = MenuItem.fromJson({...data, 'storeId': storeId});
      final catItems =
          List<MenuItem>.from(state.itemsByCategory[newItem.categoryId] ?? []);
      catItems.add(newItem);
      state = state.copyWith(
        itemsByCategory: {
          ...state.itemsByCategory,
          newItem.categoryId: catItems,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateItem(String itemId, MenuItemPayload payload) async {
    try {
      final data = await _api.patch('/stores/$storeId/items/$itemId',
          body: payload.toJson());
      final updated = MenuItem.fromJson({...data, 'storeId': storeId});
      final newItemsMap = <String, List<MenuItem>>{};
      for (final entry in state.itemsByCategory.entries) {
        newItemsMap[entry.key] = entry.value
            .map((i) => i.id == itemId ? updated : i)
            .toList();
      }
      state = state.copyWith(itemsByCategory: newItemsMap);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteItem(String itemId) async {
    try {
      await _api.delete('/stores/$storeId/items/$itemId');
      final newItemsMap = <String, List<MenuItem>>{};
      for (final entry in state.itemsByCategory.entries) {
        newItemsMap[entry.key] =
            entry.value.where((i) => i.id != itemId).toList();
      }
      state = state.copyWith(itemsByCategory: newItemsMap);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateStock(String itemId, int? stock) async {
    try {
      await _api.patch('/stores/$storeId/items/$itemId/stock',
          body: {'stock': stock});
      _patchItem(itemId, (item) => _itemWithStock(item, stock));
    } catch (_) {}
  }

  Future<void> updateItemStatus(String itemId, String status) async {
    // Optimistic update
    _patchItem(itemId, (item) => _itemWithStatus(item, status));
    try {
      await _api.patch('/stores/$storeId/items/$itemId/status',
          body: {'status': status});
    } catch (_) {
      // rollback
      await fetchMenu();
    }
  }

  void _patchItem(String itemId, MenuItem Function(MenuItem) transform) {
    final newItemsMap = <String, List<MenuItem>>{};
    for (final entry in state.itemsByCategory.entries) {
      newItemsMap[entry.key] =
          entry.value.map((i) => i.id == itemId ? transform(i) : i).toList();
    }
    state = state.copyWith(itemsByCategory: newItemsMap);
  }

  MenuItem _itemWithStock(MenuItem item, int? stock) => MenuItem(
        id: item.id,
        storeId: item.storeId,
        categoryId: item.categoryId,
        name: item.name,
        description: item.description,
        price: item.price,
        images: item.images,
        stock: stock,
        status: item.status,
        soldCount: item.soldCount,
      );

  MenuItem _itemWithStatus(MenuItem item, String status) => MenuItem(
        id: item.id,
        storeId: item.storeId,
        categoryId: item.categoryId,
        name: item.name,
        description: item.description,
        price: item.price,
        images: item.images,
        stock: item.stock,
        status: status,
        soldCount: item.soldCount,
      );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final menuProvider =
    StateNotifierProvider.family<MenuNotifier, MenuState, String>(
  (ref, storeId) => MenuNotifier(storeId, ref.read(apiClientProvider)),
);

// ─────────────────────────────────────────────────────────────────────────────
// lib/features/store/providers/store_detail_provider.dart
// ─────────────────────────────────────────────────────────────────────────────

// Stub — khai báo provider cho StoreDetailPage
// (chi tiết phụ thuộc module 01/02, giữ interface nhất quán với màn hình)

class StoreModel {
  final String id;
  final String name;
  final String? coverImage;
  final double? rating;
  final double? distanceKm;
  final String? openHours;
  final bool? isOpen;

  const StoreModel({
    required this.id,
    required this.name,
    this.coverImage,
    this.rating,
    this.distanceKm,
    this.openHours,
    this.isOpen,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) => StoreModel(
        id: json['_id'] as String,
        name: json['name'] as String,
        coverImage: json['coverImage'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        openHours: json['openHours'] as String?,
        isOpen: json['isOpen'] as bool?,
      );
}

class StoreDetailState {
  final StoreModel? store;
  final List<MenuCategory> categories;
  final Map<String, List<MenuItem>> itemsByCategory;
  final double? distanceKm;
  final bool isLoading;
  final String? error;

  const StoreDetailState({
    this.store,
    this.categories = const [],
    this.itemsByCategory = const {},
    this.distanceKm,
    this.isLoading = false,
    this.error,
  });

  StoreDetailState copyWith({
    StoreModel? store,
    List<MenuCategory>? categories,
    Map<String, List<MenuItem>>? itemsByCategory,
    double? distanceKm,
    bool? isLoading,
    String? error,
  }) =>
      StoreDetailState(
        store: store ?? this.store,
        categories: categories ?? this.categories,
        itemsByCategory: itemsByCategory ?? this.itemsByCategory,
        distanceKm: distanceKm ?? this.distanceKm,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class StoreDetailNotifier extends StateNotifier<StoreDetailState> {
  final String storeId;
  final ApiClient _api;

  StoreDetailNotifier(this.storeId, this._api)
      : super(const StoreDetailState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Fetch store info + menu trong 1 lần
      final results = await Future.wait([
        _api.get('/stores/$storeId'),
        _api.get('/stores/$storeId/menu'),
      ]);

      final storeJson = results[0];
      final menuJson = results[1];

      final store = StoreModel.fromJson(storeJson);
      final rawCats =
          List<Map<String, dynamic>>.from(menuJson['categories'] ?? []);

      final categories = <MenuCategory>[];
      final itemsByCategory = <String, List<MenuItem>>{};

      for (final catJson in rawCats) {
        final cat = MenuCategory.fromJson(catJson);
        categories.add(cat);
        final rawItems =
            List<Map<String, dynamic>>.from(catJson['items'] ?? []);
        itemsByCategory[cat.id] = rawItems
            .map((j) => MenuItem.fromJson(
                {...j, 'storeId': storeId, 'categoryId': cat.id}))
            .toList();
      }

      state = state.copyWith(
        store: store,
        categories: categories,
        itemsByCategory: itemsByCategory,
        distanceKm: store.distanceKm,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải thông tin quán.',
      );
    }
  }
}

final storeDetailProvider = StateNotifierProvider.family<StoreDetailNotifier,
    StoreDetailState, String>(
  (ref, storeId) =>
      StoreDetailNotifier(storeId, ref.read(apiClientProvider)),
);

// ─────────────────────────────────────────────────────────────────────────────
// lib/features/store_dashboard/menu/providers/item_form_provider.dart
// ─────────────────────────────────────────────────────────────────────────────

class ItemFormState {
  final List<String> images; // Cloudinary URLs hiện tại
  final bool isUploading;

  const ItemFormState({this.images = const [], this.isUploading = false});

  ItemFormState copyWith({List<String>? images, bool? isUploading}) =>
      ItemFormState(
        images: images ?? this.images,
        isUploading: isUploading ?? this.isUploading,
      );
}

class ItemFormNotifier extends StateNotifier<ItemFormState> {
  final String? itemId;
  final ApiClient _api;
  // Pending files khi chưa có itemId (tạo mới)
  final List<dynamic> _pendingFiles = [];

  ItemFormNotifier(this.itemId, this._api, List<String> initialImages)
      : super(ItemFormState(images: initialImages));

  void addPendingImage(dynamic file) {
    _pendingFiles.add(file);
    // Hiện preview local nếu muốn
  }

  Future<void> uploadImage(dynamic file) async {
    if (itemId == null) {
      addPendingImage(file);
      return;
    }
    state = state.copyWith(isUploading: true);
    try {
      // Upload trực tiếp lên Cloudinary từ client, lấy URL
      // rồi POST URL đó lên backend
      // (Cloudinary upload logic nằm trong CloudinaryService)
      final url = await _uploadToCloudinary(file);
      await _api.post(
        '/stores/items/$itemId/images', // storeId sẽ được inject qua header auth
        body: {'url': url},
      );
      state = state.copyWith(
        images: [...state.images, url],
        isUploading: false,
      );
    } catch (_) {
      state = state.copyWith(isUploading: false);
    }
  }

  Future<void> deleteImage(int index) async {
    if (itemId == null) return;
    try {
      await _api.delete('/stores/items/$itemId/images/$index');
      final newImages = List<String>.from(state.images)..removeAt(index);
      state = state.copyWith(images: newImages);
    } catch (_) {}
  }

  Future<String> _uploadToCloudinary(dynamic file) async {
    // Stub — implement trong CloudinaryService
    // Menggunakan Cloudinary unsigned upload preset
    throw UnimplementedError('CloudinaryService.upload()');
  }
}

final itemFormProvider =
    StateNotifierProvider.family<ItemFormNotifier, ItemFormState, String?>(
  (ref, itemId) => ItemFormNotifier(
    itemId,
    ref.read(apiClientProvider),
    [], // initialImages — truyền từ màn hình nếu editing
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// lib/features/store/providers/store_like_provider.dart  (stub cho module 08)
// ─────────────────────────────────────────────────────────────────────────────

final storeLikeProvider =
    StateNotifierProvider.family<_StoreLikeNotifier, bool, String>(
  (ref, storeId) => _StoreLikeNotifier(storeId, ref.read(apiClientProvider)),
);

class _StoreLikeNotifier extends StateNotifier<bool> {
  final String storeId;
  final ApiClient _api;
  _StoreLikeNotifier(this.storeId, this._api) : super(false);

  Future<void> toggle() async {
    // Module 08 — Social
    state = !state;
  }
}


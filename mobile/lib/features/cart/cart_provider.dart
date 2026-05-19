// lib/features/cart/cart_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core//network/dio_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/network/api_endpoints.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class CartItem {
  final String itemId;
  final String name;
  final double price;
  final String imageUrl;
  int quantity;
  final int? stock; // null = unlimited

  CartItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.quantity,
    this.stock,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        itemId: json['itemId'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        imageUrl: json['imageUrl'] as String? ?? '',
        quantity: json['quantity'] as int,
        stock: json['stock'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'name': name,
        'price': price,
        'imageUrl': imageUrl,
        'quantity': quantity,
        if (stock != null) 'stock': stock,
      };

  CartItem copyWith({int? quantity}) => CartItem(
        itemId: itemId,
        name: name,
        price: price,
        imageUrl: imageUrl,
        quantity: quantity ?? this.quantity,
        stock: stock,
      );
}

class CartState {
  final String? storeId;
  final String? storeName;
  final List<CartItem> items;
  final String note;
  final bool isLoading;
  final String? error;

  const CartState({
    this.storeId,
    this.storeName,
    this.items = const [],
    this.note = '',
    this.isLoading = false,
    this.error,
  });

  double get subtotal => items.fold(0, (sum, i) => sum + i.price * i.quantity);
  int get totalItems => items.fold(0, (sum, i) => sum + i.quantity);

  CartState copyWith({
    String? storeId,
    String? storeName,
    List<CartItem>? items,
    String? note,
    bool? isLoading,
    String? error,
  }) =>
      CartState(
        storeId: storeId ?? this.storeId,
        storeName: storeName ?? this.storeName,
        items: items ?? this.items,
        note: note ?? this.note,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  Map<String, dynamic> toJson() => {
        'storeId': storeId,
        'storeName': storeName,
        'items': items.map((e) => e.toJson()).toList(),
        'note': note,
      };

  factory CartState.fromJson(Map<String, dynamic> json) => CartState(
        storeId: json['storeId'] as String?,
        storeName: json['storeName'] as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        note: json['note'] as String? ?? '',
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class CartNotifier extends StateNotifier<CartState> {
  final Ref _ref;
  static const _hiveKey = 'cart';

  CartNotifier(this._ref) : super(const CartState()) {
    _init();
  }

  bool get _isLoggedIn => _ref.read(authProvider) != null;

  Future<void> _init() async {
    if (_isLoggedIn) {
      await fetchFromServer();
    } else {
      _loadFromHive();
    }
  }

  // ── Server sync (logged-in) ──────────────────────────────────────────────

  Future<void> fetchFromServer() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await DioClient.instance.get(ApiEndpoints.cart);
      final data = res.data as Map<String, dynamic>;
      state = CartState.fromJson(data);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addItem(CartItem item, String storeId, String storeName) async {
    if (_isLoggedIn) {
      try {
        await DioClient.instance.post(ApiEndpoints.cart, data: {
          'itemId': item.itemId,
          'quantity': item.quantity,
          'storeId': storeId,
        });
        await fetchFromServer();
      } catch (e) {
        state = state.copyWith(error: e.toString());
      }
    } else {
      _addItemLocal(item, storeId, storeName);
    }
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    if (_isLoggedIn) {
      try {
        await DioClient.instance.put(
          '${ApiEndpoints.cart}/$itemId',
          data: {'quantity': quantity},
        );
        await fetchFromServer();
      } catch (e) {
        state = state.copyWith(error: e.toString());
      }
    } else {
      _updateQuantityLocal(itemId, quantity);
    }
  }

  Future<void> removeItem(String itemId) async {
    if (_isLoggedIn) {
      try {
        await DioClient.instance.delete('${ApiEndpoints.cart}/$itemId');
        await fetchFromServer();
      } catch (e) {
        state = state.copyWith(error: e.toString());
      }
    } else {
      _removeItemLocal(itemId);
    }
  }

  Future<void> clearCart() async {
    if (_isLoggedIn) {
      try {
        await DioClient.instance.delete(ApiEndpoints.cart);
        state = const CartState();
      } catch (e) {
        state = state.copyWith(error: e.toString());
      }
    } else {
      _clearLocal();
    }
  }

  void updateNote(String note) {
    state = state.copyWith(note: note);
    if (!_isLoggedIn) _saveToHive();
  }

  // ── Hive local (guest) ───────────────────────────────────────────────────

  void _loadFromHive() {
    try {
      final box = Hive.box('cart');
      final raw = box.get(_hiveKey);
      if (raw != null) {
        state = CartState.fromJson(Map<String, dynamic>.from(raw as Map));
      }
    } catch (_) {}
  }

  void _saveToHive() {
    try {
      final box = Hive.box('cart');
      box.put(_hiveKey, state.toJson());
    } catch (_) {}
  }

  void _addItemLocal(CartItem item, String storeId, String storeName) {
    final existing = state.items.indexWhere((e) => e.itemId == item.itemId);
    List<CartItem> updated;
    if (existing >= 0) {
      updated = [...state.items];
      updated[existing] =
          updated[existing].copyWith(quantity: updated[existing].quantity + item.quantity);
    } else {
      updated = [...state.items, item];
    }
    state = state.copyWith(
      storeId: storeId,
      storeName: storeName,
      items: updated,
    );
    _saveToHive();
  }

  void _updateQuantityLocal(String itemId, int quantity) {
    final updated = state.items.map((e) {
      if (e.itemId == itemId) return e.copyWith(quantity: quantity);
      return e;
    }).toList();
    state = state.copyWith(items: updated);
    _saveToHive();
  }

  void _removeItemLocal(String itemId) {
    final updated = state.items.where((e) => e.itemId != itemId).toList();
    state = state.copyWith(items: updated);
    _saveToHive();
  }

  void _clearLocal() {
    state = const CartState();
    _saveToHive();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(ref),
);

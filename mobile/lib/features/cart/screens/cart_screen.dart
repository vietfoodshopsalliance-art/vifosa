// lib/features/cart/screens/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Formatter
// ─────────────────────────────────────────────────────────────────────────────

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class CartItem {
  final String itemId;
  final String name;
  final double price;
  final String? imageUrl;
  final String storeId;
  final String storeName;
  final int? stock; // null = unlimited
  int quantity;

  CartItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.storeId,
    required this.storeName,
    required this.quantity,
    this.imageUrl,
    this.stock,
  });

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'name': name,
        'price': price,
        'imageUrl': imageUrl,
        'storeId': storeId,
        'storeName': storeName,
        'quantity': quantity,
        'stock': stock,
      };

  factory CartItem.fromJson(Map<dynamic, dynamic> j) => CartItem(
        itemId: j['itemId'] as String,
        name: j['name'] as String,
        price: (j['price'] as num).toDouble(),
        imageUrl: j['imageUrl'] as String?,
        storeId: j['storeId'] as String,
        storeName: j['storeName'] as String,
        quantity: j['quantity'] as int,
        stock: j['stock'] as int?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class CartState {
  final String? storeId;
  final String? storeName;
  final List<CartItem> items;
  final String note;

  const CartState({
    this.storeId,
    this.storeName,
    this.items = const [],
    this.note = '',
  });

  double get subtotal => items.fold(0, (sum, i) => sum + i.price * i.quantity);
  int get totalItems => items.fold(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    String? storeId,
    String? storeName,
    List<CartItem>? items,
    String? note,
  }) =>
      CartState(
        storeId: storeId ?? this.storeId,
        storeName: storeName ?? this.storeName,
        items: items ?? this.items,
        note: note ?? this.note,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class CartNotifier extends StateNotifier<CartState> {
  final Ref _ref;
  static const _boxKey = 'cart';
  static const _hiveItemsKey = 'items';
  static const _hiveNoteKey = 'note';
  static const _hiveStoreIdKey = 'storeId';
  static const _hiveStoreNameKey = 'storeName';

  CartNotifier(this._ref) : super(const CartState()) {
    _load();
  }

  bool get _isLoggedIn => _ref.read(authProvider).user != null;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    await _loadFromHive();
  }

  Future<void> _loadFromHive() async {
    final box = await Hive.openBox(_boxKey);
    final rawItems = box.get(_hiveItemsKey, defaultValue: <dynamic>[]) as List;
    state = CartState(
      storeId: box.get(_hiveStoreIdKey) as String?,
      storeName: box.get(_hiveStoreNameKey) as String?,
      items: rawItems.map((e) => CartItem.fromJson(Map.from(e as Map))).toList(),
      note: box.get(_hiveNoteKey, defaultValue: '') as String,
    );
  }

  // ── Persist ───────────────────────────────────────────────────────────────

  Future<void> _persistHive() async {
    final box = await Hive.openBox(_boxKey);
    await box.put(_hiveItemsKey, state.items.map((e) => e.toJson()).toList());
    await box.put(_hiveNoteKey, state.note);
    await box.put(_hiveStoreIdKey, state.storeId);
    await box.put(_hiveStoreNameKey, state.storeName);
  }

  Future<void> _afterMutation() async {
    await _persistHive();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Thêm món. Gọi từ StoreDetailScreen.
  /// [replaceStore] = true khi user xác nhận xoá giỏ cũ từ quán khác.
  void addItem(CartItem item, {bool replaceStore = false}) {
    if (state.storeId != null &&
        state.storeId != item.storeId &&
        !replaceStore) {
      // Caller phải xử lý dialog rồi gọi lại với replaceStore: true
      return;
    }

    List<CartItem> updated;
    if (replaceStore && state.storeId != item.storeId) {
      updated = [item];
    } else {
      final idx = state.items.indexWhere((e) => e.itemId == item.itemId);
      if (idx >= 0) {
        updated = [...state.items];
        final existing = updated[idx];
        final newQty = existing.quantity + item.quantity;
        // Respect stock limit
        final capped = existing.stock != null
            ? newQty.clamp(1, existing.stock!)
            : newQty;
        updated[idx] = CartItem(
          itemId: existing.itemId,
          name: existing.name,
          price: existing.price,
          imageUrl: existing.imageUrl,
          storeId: existing.storeId,
          storeName: existing.storeName,
          quantity: capped,
          stock: existing.stock,
        );
      } else {
        updated = [...state.items, item];
      }
    }

    state = state.copyWith(
      storeId: item.storeId,
      storeName: item.storeName,
      items: updated,
    );
    _afterMutation();
  }

  void updateQty(String itemId, int qty) {
    if (qty <= 0) {
      removeItem(itemId);
      return;
    }
    final updated = state.items.map((e) {
      if (e.itemId != itemId) return e;
      final capped = e.stock != null ? qty.clamp(1, e.stock!) : qty;
      return CartItem(
        itemId: e.itemId,
        name: e.name,
        price: e.price,
        imageUrl: e.imageUrl,
        storeId: e.storeId,
        storeName: e.storeName,
        quantity: capped,
        stock: e.stock,
      );
    }).toList();
    state = state.copyWith(items: updated);
    _afterMutation();
  }

  void removeItem(String itemId) {
    final updated = state.items.where((e) => e.itemId != itemId).toList();
    state = state.copyWith(
      items: updated,
      storeId: updated.isEmpty ? null : state.storeId,
      storeName: updated.isEmpty ? null : state.storeName,
    );
    _afterMutation();
  }

  void updateNote(String note) {
    state = state.copyWith(note: note);
    _afterMutation();
  }

  void clear() {
    state = const CartState();
    _afterMutation();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(ref);
});

// ─────────────────────────────────────────────────────────────────────────────
// CartScreen
// ─────────────────────────────────────────────────────────────────────────────

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  late final TextEditingController _noteCtrl;
  double? _shipFee;
  bool _shipFeeLoading = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(
      text: ref.read(cartProvider).note,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchShipFee());
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // Lấy GPS từ địa chỉ mặc định của user (giống checkout_screen._prefillFromUser)
  Future<({double lat, double lng})?> _getDefaultAddressGps() async {
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.dio.get(ApiEndpoints.myAddresses);
      final data = res.data;
      List<dynamic> list = data is List
          ? data
          : ((data as Map)['addresses'] ?? data['data'] ?? data['items'] ?? []) as List;
      if (list.isEmpty) return null;

      Map<String, dynamic>? addr;
      for (final a in list) {
        if ((a as Map)['isDefault'] == true) { addr = Map<String, dynamic>.from(a); break; }
      }
      addr ??= Map<String, dynamic>.from(list.first as Map);

      final coords = ((addr['address'] as Map?)?['location'] as Map?)?['coordinates'] as List?;
      if (coords == null || coords.length < 2) return null;
      final lng = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      if (lat == 0.0 && lng == 0.0) return null;
      return (lat: lat, lng: lng);
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchShipFee() async {
    final storeId = ref.read(cartProvider).storeId;
    if (storeId == null || storeId.isEmpty) return;

    final isLoggedIn = ref.read(authProvider).user != null;
    if (!isLoggedIn) return; // khách vãng lai: hiển thị "Tính khi đặt hàng"

    final gps = await _getDefaultAddressGps();
    if (gps == null || !mounted) return; // không có địa chỉ mặc định

    setState(() => _shipFeeLoading = true);
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.dio.post(
        ApiEndpoints.storeShipFee(storeId),
        data: {'deliveryLat': gps.lat, 'deliveryLng': gps.lng, 'deliveryMethod': 'store_delivery'},
      );
      if (mounted) setState(() => _shipFee = (res.data['shipFee'] as num).toDouble());
    } catch (e) {
      debugPrint('Cart: ship fee error — $e');
      if (mounted) setState(() => _shipFee = null);
    } finally {
      if (mounted) setState(() => _shipFeeLoading = false);
    }
  }

  void _onNoteChanged(String val) {
    ref.read(cartProvider.notifier).updateNote(val);
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Xoá giỏ hàng'),
        content: const Text('Bạn có chắc muốn xoá tất cả sản phẩm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              Navigator.pop(dialogCtx);
            },
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _onCheckout() {
    final isLoggedIn = ref.read(authProvider).user != null;
    if (isLoggedIn) {
      context.push('/checkout');
      return;
    }
    // Khách vãng lai → bottom sheet chọn flow
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bạn muốn đặt hàng với tư cách:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  context.push('/login');
                },
                child: const Text('Đăng nhập / Đăng ký'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  context.push('/checkout');
                },
                child: const Text('Đặt không cần tài khoản'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
  leading: IconButton(
    icon: const Icon(Icons.home_outlined),
    onPressed: () => context.go('/home'),
  ),
  title: const Text('Giỏ hàng'),
  actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: _confirmClear,
              child:
                  const Text('Xoá tất cả', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: cart.isEmpty ? _buildEmpty(context) : _buildCart(context, cart, notifier, theme),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Giỏ hàng trống',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hãy thêm món ăn để bắt đầu',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Về trang chủ'),
          ),
        ],
      ),
    );
  }

  // ── Cart content ─────────────────────────────────────────────────────────

  Widget _buildCart(
    BuildContext context,
    CartState cart,
    CartNotifier notifier,
    ThemeData theme,
  ) {
    final total = _shipFee != null ? cart.subtotal + _shipFee! : cart.subtotal;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Store name header — nhấn để vào trang quán
              if (cart.storeName != null && cart.storeId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.push('/store/${cart.storeId}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.store_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            cart.storeName!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.add_circle_outline, size: 15),
                          const SizedBox(width: 2),
                          const Text('Thêm món', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),

              // Items
              ...cart.items
                  .map((item) => _CartItemTile(item: item, notifier: notifier)),

              const SizedBox(height: 12),

              // Note
              TextField(
                controller: _noteCtrl,
                onChanged: _onNoteChanged,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú cho quán (tuỳ chọn)',
                  border: OutlineInputBorder(),
                  hintText: 'VD: Ít đá, không hành...',
                ),
              ),
            ],
          ),
        ),

        // Bottom summary + checkout
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                _summaryRow('Tạm tính:', _vnd.format(cart.subtotal), theme, bold: false),
                const SizedBox(height: 4),
                // Phí ship
                if (_shipFeeLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Phí ship:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        SizedBox(width: 80, height: 12, child: LinearProgressIndicator()),
                      ],
                    ),
                  )
                else if (_shipFee != null)
                  _summaryRow('Phí ship:', _vnd.format(_shipFee!), theme, bold: false, color: Colors.grey)
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Phí ship:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        Text('Tính khi đặt hàng', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                const Divider(height: 16),
                _summaryRow('Tổng cộng:', _vnd.format(total), theme, bold: true),
                const SizedBox(height: 10),
                AppButton(
                  label: 'Đặt hàng (${cart.totalItems} món)',
                  onPressed: _onCheckout,
                  isLoading: false,
                  variant: ButtonVariant.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, ThemeData theme, {
    bool bold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: bold ? 15 : 14, color: color ?? Colors.grey.shade700)),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 17 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: bold ? theme.colorScheme.primary : (color ?? Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CartItemTile
// ─────────────────────────────────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final CartNotifier notifier;

  const _CartItemTile({required this.item, required this.notifier});

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Xoá món'),
        content: Text('Xoá "${item.name}" khỏi giỏ hàng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              notifier.removeItem(item.itemId);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atStockLimit =
        item.stock != null && item.quantity >= item.stock!;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),

            const SizedBox(width: 12),

            // Info + controls
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    _vnd.format(item.price),
                    style: TextStyle(
                        color: theme.colorScheme.primary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Decrease / remove
                      IconButton(
                        icon: Icon(
                          item.quantity == 1
                              ? Icons.delete_outline
                              : Icons.remove_circle_outline,
                          color:
                              item.quantity == 1 ? Colors.red : null,
                        ),
                        onPressed: () {
                          if (item.quantity == 1) {
                            _confirmRemove(context);
                          } else {
                            notifier.updateQty(
                                item.itemId, item.quantity - 1);
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),

                      // Quantity
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${item.quantity}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),

                      // Increase
                      Tooltip(
                        message: atStockLimit ? 'Đã đủ hàng' : '',
                        child: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: atStockLimit
                              ? null
                              : () => notifier.updateQty(
                                  item.itemId, item.quantity + 1),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ),

                      const Spacer(),

                      // Line total
                      Text(
                        _vnd.format(item.price * item.quantity),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 60,
        height: 60,
        color: Colors.grey.shade200,
        child: const Icon(Icons.fastfood_outlined,
            color: Colors.grey, size: 28),
      );
}

// lib/features/cart/screens/cart_screen.dart
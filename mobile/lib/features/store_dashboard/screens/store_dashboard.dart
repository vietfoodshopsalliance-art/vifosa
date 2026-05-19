// lib/features/store_dashboard/screens/store_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/theme/theme.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class StoreSummaryModel {
  final String id;
  final String name;
  final String? coverUrl;
  final String status; // open | pre_order | closed
  final int todayOrders;
  final double todayRevenue;
  final double rating;
  final int reviewCount;

  const StoreSummaryModel({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.status,
    required this.todayOrders,
    required this.todayRevenue,
    required this.rating,
    required this.reviewCount,
  });

  factory StoreSummaryModel.fromJson(Map<String, dynamic> j) =>
      StoreSummaryModel(
        id: j['_id'] ?? '',
        name: j['name'] ?? '',
        coverUrl: j['coverImage'],
        status: j['status'] ?? 'closed',
        todayOrders: j['todayOrders'] ?? 0,
        todayRevenue: (j['todayRevenue'] ?? 0).toDouble(),
        rating: (j['rating'] ?? 0).toDouble(),
        reviewCount: j['reviewCount'] ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final storeDashboardProvider =
    StateNotifierProvider<StoreDashboardNotifier,
        AsyncValue<List<StoreSummaryModel>>>(
  (ref) => StoreDashboardNotifier(ref),
);

class StoreDashboardNotifier
    extends StateNotifier<AsyncValue<List<StoreSummaryModel>>> {
  final Ref _ref;
  StoreDashboardNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await DioClient().dio.get(
        ApiEndpoints.stores,
        queryParameters: {'owner': 'me'},
      );
      final data = res.data as Map<String, dynamic>;
      final list = (data['stores'] as List? ?? [])
          .map((e) => StoreSummaryModel.fromJson(e))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _load();
  }

  Future<void> toggleEmergencyClose(String storeId, bool isOpen) async {
    try {
      await DioClient().dio.post(ApiEndpoints.emergencyClose(storeId));
      await _load();
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class StoreDashboardScreen extends ConsumerWidget {
  const StoreDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final storesAsync = ref.watch(storeDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý cửa hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(storeDashboardProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to create store screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tính năng tạo quán mới sắp ra mắt')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm quán'),
        backgroundColor: AppTheme.primary,
      ),
      body: storesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('$e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(storeDashboardProvider.notifier).refresh(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (stores) => stores.isEmpty
            ? _EmptyStoreView()
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(storeDashboardProvider.notifier).refresh(),
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: stores.length,
                  itemBuilder: (context, i) => _StoreManageCard(
                    store: stores[i],
                    onManageOrders: () =>
                        context.push('/store-dashboard/${stores[i].id}/orders'),
                    onManageMenu: () =>
                        context.push('/store-dashboard/${stores[i].id}/menu'),
                    onSettings: () => context
                        .push('/store-dashboard/${stores[i].id}/settings'),
                    onReviews: () => context
                        .push('/store-dashboard/${stores[i].id}/reviews'),
                    onToggleClose: () => ref
                        .read(storeDashboardProvider.notifier)
                        .toggleEmergencyClose(
                            stores[i].id, stores[i].status == 'open'),
                  ),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Store Management Card
// ---------------------------------------------------------------------------

class _StoreManageCard extends StatelessWidget {
  final StoreSummaryModel store;
  final VoidCallback onManageOrders;
  final VoidCallback onManageMenu;
  final VoidCallback onSettings;
  final VoidCallback onReviews;
  final VoidCallback onToggleClose;

  const _StoreManageCard({
    required this.store,
    required this.onManageOrders,
    required this.onManageMenu,
    required this.onSettings,
    required this.onReviews,
    required this.onToggleClose,
  });

  Color get _statusColor {
    switch (store.status) {
      case 'open':
        return AppTheme.success;
      case 'pre_order':
        return AppTheme.warning;
      default:
        return AppTheme.danger;
    }
  }

  String get _statusLabel {
    switch (store.status) {
      case 'open':
        return 'Đang mở';
      case 'pre_order':
        return 'Đặt trước';
      default:
        return 'Đã đóng';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        children: [
          // Store header
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: store.coverUrl != null
                  ? Image.network(
                      store.coverUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 52,
                      height: 52,
                      color: AppTheme.primary.withOpacity(0.15),
                      child: Icon(Icons.store, color: AppTheme.primary),
                    ),
            ),
            title: Text(store.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: StatusBadge(label: _statusLabel, color: _statusColor),
            trailing: IconButton(
              icon: Icon(
                store.status == 'open'
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                color: store.status == 'open' ? Colors.red : Colors.green,
              ),
              tooltip: store.status == 'open' ? 'Đóng khẩn cấp' : 'Mở lại',
              onPressed: () => _confirmToggle(context),
            ),
          ),

          // Stats row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.receipt_long,
                  label: 'Đơn hôm nay',
                  value: '${store.todayOrders}',
                ),
                const SizedBox(width: 16),
                _StatChip(
                  icon: Icons.monetization_on_outlined,
                  label: 'Doanh thu',
                  value: _fmtCurrency(store.todayRevenue),
                ),
                const SizedBox(width: 16),
                _StatChip(
                  icon: Icons.star_rate,
                  label: 'Đánh giá',
                  value: store.rating.toStringAsFixed(1),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Quick action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.list_alt,
                  label: 'Đơn hàng',
                  onTap: onManageOrders,
                  badge: store.todayOrders > 0 ? '${store.todayOrders}' : null,
                ),
                _ActionButton(
                  icon: Icons.restaurant_menu,
                  label: 'Menu',
                  onTap: onManageMenu,
                ),
                _ActionButton(
                  icon: Icons.reviews,
                  label: 'Đánh giá',
                  onTap: onReviews,
                  badge: store.reviewCount > 0
                      ? '${store.reviewCount}'
                      : null,
                ),
                _ActionButton(
                  icon: Icons.settings,
                  label: 'Cài đặt',
                  onTap: onSettings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmToggle(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          store.status == 'open' ? 'Đóng cửa khẩn cấp?' : 'Mở cửa hàng?',
        ),
        content: Text(
          store.status == 'open'
              ? 'Quán sẽ dừng nhận đơn ngay lập tức. Tiếp tục?'
              : 'Quán sẽ hiển thị lại và nhận đơn. Tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onToggleClose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: store.status == 'open' ? Colors.red : Colors.green,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  String _fmtCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '${amount.toStringAsFixed(0)}đ';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 22, color: Colors.grey.shade700),
                  if (badge != null)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(badge!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStoreView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store_mall_directory_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Bạn chưa có cửa hàng nào',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Tạo cửa hàng để bắt đầu bán hàng trên Vifosa',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

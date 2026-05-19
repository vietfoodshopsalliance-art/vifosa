// lib/features/store_dashboard/store_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_endpoints.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final _myStoresProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.read(dioClientProvider);
  final res = await dio.get(ApiEndpoints.myStores);
  return res.data as List<dynamic>;
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class StorePickerScreen extends ConsumerWidget {
  const StorePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(_myStoresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý quán'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(_myStoresProvider),
          ),
        ],
      ),
      body: storesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('Không thể tải danh sách quán\n$e',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(_myStoresProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (stores) {
          // Auto-navigate nếu chỉ 1 quán
          if (stores.length == 1) {
            final storeId = stores[0]['id'] as String;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/store-dashboard/$storeId/orders');
            });
            return const Center(child: CircularProgressIndicator());
          }

          // 0 quán
          if (stores.isEmpty) {
            return _EmptyStoreView(
              onCreateTap: () => context.push('/store-dashboard/create'),
            );
          }

          // Nhiều quán
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: stores.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == stores.length) {
                return _CreateStoreTile(
                  onTap: () => context.push('/store-dashboard/create'),
                );
              }
              final store = stores[index] as Map<String, dynamic>;
              return _StoreTile(
                store: store,
                onTap: () {
                  context.go('/store-dashboard/${store['id']}/orders');
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _StoreTile extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback onTap;

  const _StoreTile({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOpen = store['isOpen'] as bool? ?? false;
    final emergencyClosed = store['emergencyClosed'] as bool? ?? false;
    final pendingCount = store['pendingOrderCount'] as int? ?? 0;
    final avatarUrl = store['avatarUrl'] as String?;
    final name = store['name'] as String? ?? '';

    final statusOpen = isOpen && !emergencyClosed;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null ? const Icon(Icons.store, size: 28) : null,
      ),
      title: Text(name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          _StatusBadge(isOpen: statusOpen),
        ],
      ),
      trailing: pendingCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$pendingCount đơn chờ',
                style:
                    const TextStyle(color: Colors.white, fontSize: 12),
              ),
            )
          : const Icon(Icons.chevron_right),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isOpen;
  const _StatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOpen
            ? Colors.green.withOpacity(0.12)
            : Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOpen ? Colors.green : Colors.orange,
          width: 0.8,
        ),
      ),
      child: Text(
        isOpen ? 'Đang mở' : 'Tạm đóng',
        style: TextStyle(
          color: isOpen ? Colors.green.shade700 : Colors.orange.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _CreateStoreTile extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateStoreTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Icon(Icons.add,
            color: Theme.of(context).colorScheme.primary, size: 28),
      ),
      title: const Text('Tạo quán mới',
          style: TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _EmptyStoreView extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyStoreView({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_outlined,
                size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Bạn chưa có quán nào',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Tạo quán đầu tiên để bắt đầu nhận đơn',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Tạo quán đầu tiên'),
            ),
          ],
        ),
      ),
    );
  }
}

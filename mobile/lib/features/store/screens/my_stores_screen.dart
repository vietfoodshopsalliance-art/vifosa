// lib/features/store/screens/my_stores_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/store_providers.dart';
import '../models/store_model.dart';
import '../../store_dashboard/screens/store_dashboard_screen.dart';
import '../../store_dashboard/create_store/create_store_screen.dart';

class MyStoresScreen extends ConsumerWidget {
  const MyStoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(myStoresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quán của tôi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tạo quán mới',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateStoreScreen()),
            ),
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
              const SizedBox(height: 12),
              Text('Không tải được danh sách quán', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(myStoresProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (stores) {
          if (stores.isEmpty) {
            return _EmptyStores(
              onCreateTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateStoreScreen()),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myStoresProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: stores.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) => _StoreCard(store: stores[index]),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card quán
// ---------------------------------------------------------------------------

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});
  final StoreModel store;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _StoreAvatar(store: store),
      title: Text(store.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            store.address.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          _StatusBadge(store: store),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StoreDashboardScreen(storeId: store.id)),
      ),
    );
  }
}

class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar({required this.store});
  final StoreModel store;

  @override
  Widget build(BuildContext context) {
    if (store.avatarUrl != null) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(store.avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.orange.withOpacity(0.15),
      child: Text(
        store.name.isNotEmpty ? store.name[0].toUpperCase() : 'Q',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge trạng thái quán (theo spec mục 0.8)
// A. Đang mở  B. Ngoài giờ  C. Đóng khẩn cấp  D. Admin khoá
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.store});
  final StoreModel store;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _resolve();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  (String, Color) _resolve() {
    if (store.isLockedByAdmin) return ('Admin khoá', Colors.red);
    if (store.emergencyClosed) return ('Đóng khẩn cấp', Colors.red);
    if (store.isOpen) return ('Đang mở', Colors.green);
    return ('Ngoài giờ', Colors.grey);
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyStores extends StatelessWidget {
  const _EmptyStores({required this.onCreateTap});
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 72, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Bạn chưa có quán nào',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tạo quán đầu tiên để bắt đầu bán hàng trên Vifosa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Tạo quán ngay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
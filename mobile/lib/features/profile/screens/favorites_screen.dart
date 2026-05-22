// lib/features/favorites/favorites_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/store.dart';
import '../../../core/models/menu_item.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/store_card.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------
final _favItemsProvider = FutureProvider<List<MenuItem>>((ref) async {
  final res = await DioClient.instance.get(ApiEndpoints.favoriteItems);
  final list = res.data is Map ? (res.data['items'] ?? res.data['data'] ?? []) : res.data;
  return (list as List)
      .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _favStoresProvider = FutureProvider<List<Store>>((ref) async {
  final res = await DioClient.instance.get(ApiEndpoints.favoriteStores);
  final list = res.data is Map ? (res.data['stores'] ?? res.data['data'] ?? []) : res.data;
  return (list as List)
      .map((e) => Store.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yêu thích'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Món ❤️'),
            Tab(text: 'Quán ❤️'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FavItemsTab(),
          _FavStoresTab(),
        ],
      ),
    );
  }
}

// ── Fav Items Tab ─────────────────────────────────────────────────────────────
class _FavItemsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(_favItemsProvider);

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyFavorites(message: 'Bạn chưa yêu thích món nào');
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, i) => _FavItemTile(
            item: items[i],
            onUnlike: () async {
              await _unlike(ref, items[i].likeId);
              ref.invalidate(_favItemsProvider);
            },
          ),
        );
      },
    );
  }

  Future<void> _unlike(WidgetRef ref, String? likeId) async {
    if (likeId == null) return;
    await DioClient.instance.delete(ApiEndpoints.likeDelete(likeId));
  }
}

// ── Fav Item Tile ─────────────────────────────────────────────────────────────
class _FavItemTile extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onUnlike;

  const _FavItemTile({required this.item, required this.onUnlike});

  String _formatPrice(double price) {
    return '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}đ';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: Colors.red,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onUnlike(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Ảnh
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl ?? '',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                    color: Colors.grey.shade200, width: 64, height: 64),
                errorWidget: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    width: 64,
                    height: 64,
                    child: const Icon(Icons.fastfood, color: Colors.grey)),
              ),
            ),
            const SizedBox(width: 12),
            // Thông tin
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: () {
                      if (item.storeId.isNotEmpty) context.push('/store/${item.storeId}');
                    },
                    child: Text(
                      item.storeName ?? '',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPrice(item.price),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            // Unlike button
            IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              onPressed: onUnlike,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fav Stores Tab ────────────────────────────────────────────────────────────
class _FavStoresTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(_favStoresProvider);

    return storesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (stores) {
        if (stores.isEmpty) {
          return const _EmptyFavorites(
              message: 'Bạn chưa yêu thích quán nào');
        }
        return ListView.builder(
          itemCount: stores.length,
          itemBuilder: (context, i) => _DismissibleStoreCard(
            store: stores[i],
            onUnlike: () async {
              await DioClient.instance
                  .delete(ApiEndpoints.likeDelete(stores[i].likeId ?? ''));
              ref.invalidate(_favStoresProvider);
            },
          ),
        );
      },
    );
  }
}

// ── Dismissible Store Card ────────────────────────────────────────────────────
class _DismissibleStoreCard extends StatelessWidget {
  final Store store;
  final VoidCallback onUnlike;

  const _DismissibleStoreCard({required this.store, required this.onUnlike});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(store.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: Colors.red,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onUnlike(),
      child: Stack(
        children: [
          StoreCard(store: store, 
            onTap: () => context.push('/store/${store.id}')
          ),
          // Unlike button overlay
          Positioned(
            right: 24,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: onUnlike,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyFavorites extends StatelessWidget {
  final String message;

  const _EmptyFavorites({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(message,
              style:
                  const TextStyle(color: Colors.grey, fontSize: 15)),
        ],
      ),
    );
  }
}

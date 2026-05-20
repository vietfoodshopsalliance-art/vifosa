// lib/features/store_detail/screens/store_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/item_card.dart';

final storeDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final res = await DioClient.instance.get(ApiEndpoints.storeDetail(id));
  return Map<String, dynamic>.from(res.data);
});

final storeMenuProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final res = await DioClient.instance.get(ApiEndpoints.storeMenu(id));
  return List<Map<String, dynamic>>.from(res.data['categories'] ?? res.data);
});

class StoreDetailScreen extends ConsumerWidget {
  final String storeId;
  const StoreDetailScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(storeDetailProvider(storeId));
    final menuAsync = ref.watch(storeMenuProvider(storeId));
    final theme = Theme.of(context);

    return Scaffold(
      body: detailAsync.when(
        data: (store) => CustomScrollView(
          slivers: [
            // Cover image app bar
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: store['coverImage'] != null && (store['coverImage'] as String).isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: store['coverImage'],
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        child: const Icon(Icons.store, size: 72, color: Colors.white),
                      ),
              ),
              actions: [
                // Favorite
                IconButton(
                  icon: const Icon(Icons.favorite_border, color: Colors.white),
                  onPressed: () => _toggleFavorite(ref, storeId),
                ),
              ],
            ),

            // Store info
SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            store['name'] ?? '',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        StatusBadge(
                          label: _statusLabel(store['status'] ?? 'closed'),
                          backgroundColor: _statusColor(store['status'] ?? 'closed'),
                          textColor: Colors.white,
                        ),
                      ],  // ← thêm: đóng children của Row
                    ),    // ← thêm: đóng Row
                    const SizedBox(height: 8),
                    if (store['description'] != null)
                      Text(
                        store['description'],
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          (store['averageRating'] ?? 0).toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${store['reviewCount'] ?? 0} đánh giá)',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const Spacer(),
                        const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 2),
                        Text(
                          store['distanceKm'] != null
                              ? '${(store['distanceKm'] as num).toStringAsFixed(1)} km'
                              : '',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                    if (store['address'] != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              store['address'],
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 24),
                    GestureDetector(
                      onTap: () => _showReviews(context, storeId),
                      child: const Row(
                        children: [
                          Icon(Icons.rate_review_outlined, size: 18),
                          SizedBox(width: 6),
                          Text('Xem đánh giá'),
                          Spacer(),
                          Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Menu
            menuAsync.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Chưa có món', style: TextStyle(color: Colors.grey))),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final cat = categories[i];
                      final items = List<Map<String, dynamic>>.from(cat['items'] ?? []);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              cat['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...items.map((item) => ItemCard(
                            item: item,
                            storeId: storeId,
                            storeStatus: store['status'] ?? 'closed',
                          )),
                        ],
                      );
                    },
                    childCount: categories.length,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, __) => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Không thể tải menu')),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Không thể tải thông tin cửa hàng'),
              TextButton(
                onPressed: () => ref.invalidate(storeDetailProvider(storeId)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      // Floating cart button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/cart'),
        icon: const Icon(Icons.shopping_cart),
        label: const Text('Xem giỏ hàng'),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open': return 'Đang mở';
      case 'pre_order': return 'Đặt trước';
      default: return 'Đóng cửa';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open': return const Color(0xFF4CAF50);
      case 'pre_order': return const Color(0xFFFFC107);
      default: return const Color(0xFFF44336);
    }
  }

  void _toggleFavorite(WidgetRef ref, String id) {
    DioClient.instance.post(ApiEndpoints.favoriteStores, data: {'storeId': id}).catchError((_) {});
  }

  void _showReviews(BuildContext context, String id) {
    // Navigate to reviews — handled by GoRouter
  }
}

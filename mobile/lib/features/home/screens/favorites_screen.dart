// lib/features/home/screens/favorites_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/store_card.dart';
import '../../../core/models/store.dart';

final favoritesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await DioClient.instance.get(ApiEndpoints.favorites);
  final data = res.data is Map ? (res.data['data'] ?? res.data) : res.data;
  final list = data is Map ? (data['stores'] ?? data['items'] ?? []) : data;
  return List<Map<String, dynamic>>.from(list as List);
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favAsync = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Yêu thích')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(favoritesProvider),
        child: favAsync.when(
          data: (stores) => stores.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Chưa có cửa hàng yêu thích', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  itemCount: stores.length,
                  itemBuilder: (_, i) {
                    final s = stores[i];
                    return StoreCard(
                      store: Store.fromJson(s),
                      onTap: () => context.push('/store/${s['_id'] ?? s['id'] ?? ''}'),
                    );
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(favoritesProvider),
              child: const Text('Thử lại'),
            ),
          ),
        ),
      ),
    );
  }
}

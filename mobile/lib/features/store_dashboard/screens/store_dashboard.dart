// lib/features/store_dashboard/screens/store_dashboard.dart
//
// Entry point for /store-dashboard — loads the owner's stores then
// immediately redirects to the first store's orders screen.
// The full 3-tab operating dashboard lives in store_orders.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final _myStoresProvider = FutureProvider.autoDispose<List<_StoreSummary>>((ref) async {
  final res = await DioClient.instance.get(ApiEndpoints.myStores);
  final raw = res.data;
  final list = raw is List ? raw : (raw as Map)['stores'] as List? ?? [];
  return list
      .map((e) => _StoreSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});

class _StoreSummary {
  final String id;
  final String name;

  const _StoreSummary({required this.id, required this.name});

  factory _StoreSummary.fromJson(Map<String, dynamic> j) => _StoreSummary(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        name: j['name'] as String? ?? '',
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class StoreDashboardScreen extends ConsumerWidget {
  const StoreDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(_myStoresProvider);

    return storesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Quản lý cửa hàng')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('$e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(_myStoresProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      data: (stores) {
        if (stores.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Quản lý cửa hàng')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => context.push('/store/create'),
              icon: const Icon(Icons.add),
              label: const Text('Tạo quán'),
            ),
            body: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.store_mall_directory_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Bạn chưa có cửa hàng nào',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text(
                    'Tạo cửa hàng để bắt đầu bán hàng trên Vifosa',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Auto-redirect to first store's operating dashboard
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.replace('/store-dashboard/${stores.first.id}/orders');
          }
        });

        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

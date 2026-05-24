//C:\Users\Admin\develop\vifosa\mobile\lib\features\store\screens\store_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/store_providers.dart';
import '../models/store_model.dart';

class StoreDashboardScreen extends ConsumerWidget {
  final String storeId;
  const StoreDashboardScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(storeDetailProvider(storeId));

    return storeAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
      data: (store) => Scaffold(
        appBar: AppBar(
          title: Text(store.name),
          actions: [
            IconButton(
              icon: Icon(
                store.emergencyClosed ? Icons.store_mall_directory : Icons.store,
                color: store.emergencyClosed ? Colors.orange : Colors.green,
              ),
              tooltip: store.emergencyClosed ? 'Đang đóng khẩn cấp' : 'Đang hoạt động',
              onPressed: () => _toggleEmergency(context, ref, store),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _StatusBanner(store: store),
            const SizedBox(height: 20),
            _MetricRow(store: store),
            const SizedBox(height: 20),
            const Text('Menu & Orders sẽ có ở module 03 & 05.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleEmergency(
      BuildContext context, WidgetRef ref, StoreModel store) async {
    await ref
        .read(storeNotifierProvider.notifier)
        .updateStore(store.id, {'emergencyClosed': !store.emergencyClosed});
    ref.invalidate(storeDetailProvider(storeId));
  }
}

class _StatusBanner extends StatelessWidget {
  final StoreModel store;
  const _StatusBanner({required this.store});

  @override
  Widget build(BuildContext context) {
    final status = store.status;
    final config = {
      StoreStatus.open: ('Đang mở cửa', Colors.green, Icons.check_circle),
      StoreStatus.preOrder: ('Ngoài giờ mở — Đặt trước', Colors.blue, Icons.access_time),
      StoreStatus.emergencyClosed: ('Tạm đóng khẩn cấp', Colors.orange, Icons.warning),
      StoreStatus.suspended: ('Tài khoản bị khoá', Colors.red, Icons.block),
    }[status]!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: config.$2.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.$2.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(config.$3, color: config.$2),
        const SizedBox(width: 10),
        Text(config.$1, style: TextStyle(color: config.$2, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final StoreModel store;
  const _MetricRow({required this.store});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _Card('Đơn tháng này', '${store.stats.completedOrdersThisMonth}'),
      const SizedBox(width: 12),
      _Card('Đánh giá TB', store.stats.avgRating.toStringAsFixed(1)),
      const SizedBox(width: 12),
      _Card('Tổng đánh giá', '${store.stats.totalReviews}'),
    ]);
  }
}

class _Card extends StatelessWidget {
  final String label;
  final String value;
  const _Card(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

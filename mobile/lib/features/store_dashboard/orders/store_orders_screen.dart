// lib/features/store_dashboard/orders/store_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'store_orders_provider.dart';
import '../models/store_order.dart';
import 'widgets/order_card_store.dart';
import 'widgets/reject_dialog.dart';

final _currency = NumberFormat('#,##0', 'vi_VN');

class StoreOrdersScreen extends ConsumerWidget {
  final String storeId;
  const StoreOrdersScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(storeOrdersProvider(storeId));

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Không thể tải đơn hàng\n$e',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.read(storeOrdersProvider(storeId).notifier).fetchOrders(),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
      data: (state) => _OrdersTabs(storeId: storeId, state: state),
    );
  }
}

class _OrdersTabs extends ConsumerStatefulWidget {
  final String storeId;
  final StoreOrdersState state;
  const _OrdersTabs({required this.storeId, required this.state});

  @override
  ConsumerState<_OrdersTabs> createState() => _OrdersTabsState();
}

class _OrdersTabsState extends ConsumerState<_OrdersTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final pendingCount = s.pendingOrders.length;

    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            _BadgeTab(
                label: 'Đơn mới',
                count: pendingCount,
                badgeColor: Colors.red),
            _BadgeTab(label: 'Chuẩn bị', count: s.preparingOrders.length),
            _BadgeTab(label: 'Đang giao', count: s.deliveringOrders.length),
            _BadgeTab(label: 'Cần thu', count: s.needsCollectionOrders.length),
            _BadgeTab(label: 'Hoàn tất', count: s.deliveredPaidOrders.length),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _PendingTab(storeId: widget.storeId, orders: s.pendingOrders),
              _PreparingTab(storeId: widget.storeId, orders: s.preparingOrders),
              _DeliveringTab(storeId: widget.storeId, orders: s.deliveringOrders),
              _CollectionTab(storeId: widget.storeId, orders: s.needsCollectionOrders),
              _CompletedTab(orders: s.deliveredPaidOrders),
            ],
          ),
        ),
      ],
    );
  }
}

class _BadgeTab extends StatelessWidget {
  final String label;
  final int count;
  final Color badgeColor;

  const _BadgeTab({
    required this.label,
    required this.count,
    this.badgeColor = Colors.blueGrey,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Tab 1: Đơn mới ───────────────────────────────────────────────────────────

class _PendingTab extends ConsumerWidget {
  final String storeId;
  final List<StoreOrder> orders;
  const _PendingTab({required this.storeId, required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return const _EmptyTab(icon: Icons.inbox_outlined, label: 'Không có đơn mới');
    }
    final notifier = ref.read(storeOrdersProvider(storeId).notifier);

    return RefreshIndicator(
      onRefresh: notifier.fetchOrders,
      child: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, i) {
          final order = orders[i];
          return OrderCardStore(
            order: order,
            showTimer: true,
            actionRow: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade300)),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => RejectDialog(
                        onConfirm: (reason) =>
                            notifier.rejectOrder(order.id, reason),
                      ),
                    ),
                    child: const Text('Từ chối'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => notifier.acceptOrder(order.id),
                    child: const Text('Nhận đơn'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Tab 2: Chuẩn bị ─────────────────────────────────────────────────────────

class _PreparingTab extends ConsumerWidget {
  final String storeId;
  final List<StoreOrder> orders;
  const _PreparingTab({required this.storeId, required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return const _EmptyTab(
          icon: Icons.restaurant_outlined, label: 'Không có đơn đang chuẩn bị');
    }
    final notifier = ref.read(storeOrdersProvider(storeId).notifier);

    return RefreshIndicator(
      onRefresh: notifier.fetchOrders,
      child: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, i) {
          final order = orders[i];

          final List<Widget> actions = [];

          if (order.paymentStatus == 'reported_paid') {
            actions.add(
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange),
                  label: const Text('Tiền chưa vào TK',
                      style: TextStyle(color: Colors.orange)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange)),
                  onPressed: () =>
                      notifier.reportMoneyNotReceived(order.id),
                ),
              ),
            );
            actions.add(const SizedBox(height: 8));
          }

          if (order.deliveryMethod == 'A') {
            actions.add(Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => notifier.markDelivering(order.id),
                    child: const Text('Bàn giao shipper'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => notifier.markDelivered(order.id),
                    child: const Text('Khách đã lấy'),
                  ),
                ),
              ],
            ));
          } else if (order.deliveryMethod == 'B') {
            actions.add(SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => notifier.markDelivered(order.id),
                child: const Text('Khách đã lấy'),
              ),
            ));
          } else if (order.deliveryMethod == 'C') {
            actions.add(SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => notifier.markDelivered(order.id),
                child: const Text('Đã bàn giao shipper'),
              ),
            ));
          }

          return OrderCardStore(
            order: order,
            compact: true,
            actionRow: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: actions,
            ),
          );
        },
      ),
    );
  }
}

// ─── Tab 3: Đang giao ────────────────────────────────────────────────────────

class _DeliveringTab extends ConsumerWidget {
  final String storeId;
  final List<StoreOrder> orders;
  const _DeliveringTab({required this.storeId, required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return const _EmptyTab(
          icon: Icons.delivery_dining_outlined, label: 'Không có đơn đang giao');
    }
    final notifier = ref.read(storeOrdersProvider(storeId).notifier);

    return RefreshIndicator(
      onRefresh: notifier.fetchOrders,
      child: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, i) {
          final order = orders[i];
          return OrderCardStore(
            order: order,
            compact: true,
            actionRow: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => notifier.markDelivered(order.id),
                child: const Text('Đã giao hàng'),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Tab 4: Cần thu tiền ──────────────────────────────────────────────────────

class _CollectionTab extends ConsumerWidget {
  final String storeId;
  final List<StoreOrder> orders;
  const _CollectionTab({required this.storeId, required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return const _EmptyTab(
          icon: Icons.payments_outlined, label: 'Không có đơn cần thu tiền');
    }
    final notifier = ref.read(storeOrdersProvider(storeId).notifier);

    return RefreshIndicator(
      onRefresh: notifier.fetchOrders,
      child: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, i) {
          final order = orders[i];
          return OrderCardStore(
            order: order,
            compact: true,
            extraContent: Row(
              children: [
                const Text('Còn phải thu: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${_currency.format(order.remainingAmount)} đ',
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            actionRow: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    _showConfirmMoneySheet(context, order, notifier),
                child: const Text('Đã nhận tiền'),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showConfirmMoneySheet(
    BuildContext context,
    StoreOrder order,
    StoreOrdersNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConfirmMoneySheet(order: order, notifier: notifier),
    );
  }
}

class _ConfirmMoneySheet extends StatefulWidget {
  final StoreOrder order;
  final StoreOrdersNotifier notifier;
  const _ConfirmMoneySheet(
      {required this.order, required this.notifier});

  @override
  State<_ConfirmMoneySheet> createState() => _ConfirmMoneySheetState();
}

class _ConfirmMoneySheetState extends State<_ConfirmMoneySheet> {
  late final TextEditingController _ctrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.order.remainingAmount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Xác nhận nhận tiền',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Số tiền nhận được (đ)',
              border: OutlineInputBorder(),
              suffixText: 'đ',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading
                ? null
                : () async {
                    final amount =
                        double.tryParse(_ctrl.text.replaceAll(',', '')) ??
                            widget.order.remainingAmount;
                    setState(() => _loading = true);
                    try {
                      await widget.notifier
                          .confirmMoneyReceived(widget.order.id, amount);
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi: $e')));
                      }
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
            child: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 5: Hoàn tất ──────────────────────────────────────────────────────────

class _CompletedTab extends StatelessWidget {
  final List<StoreOrder> orders;
  const _CompletedTab({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyTab(
          icon: Icons.check_circle_outline, label: 'Chưa có đơn hoàn tất');
    }
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, i) => OrderCardStore(
        order: orders[i],
        compact: true,
        greyed: true,
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
        ],
      ),
    );
  }
}

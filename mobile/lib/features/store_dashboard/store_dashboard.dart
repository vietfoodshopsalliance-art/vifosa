// C:\Users\Admin\develop\vifosa\mobile\lib\features\store_dashboard\store_dashboard.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

// ─── STORE DASHBOARD ROOT ─────────────────────────────────────────────────────
class StoreDashboard extends StatefulWidget {
  const StoreDashboard({super.key});

  @override
  State<StoreDashboard> createState() => _StoreDashboardState();
}

class _StoreDashboardState extends State<StoreDashboard> {
  int _tab = 0;

  final _pages = const [
    StoreOrdersPage(),
    StoreMenuPage(),
    StoreSettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Đơn hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined),
            activeIcon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store_outlined),
            activeIcon: Icon(Icons.store),
            label: 'Quán',
          ),
        ],
      ),
    );
  }
}

// ─── ORDERS PAGE ─────────────────────────────────────────────────────────────
class StoreOrdersPage extends StatefulWidget {
  const StoreOrdersPage({super.key});

  @override
  State<StoreOrdersPage> createState() => _StoreOrdersPageState();
}

class _StoreOrdersPageState extends State<StoreOrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final _tabs = [
    ('Đơn mới', 3),
    ('Chuẩn bị', 1),
    ('Đang giao', 0),
    ('Còn thu', 2),
    ('Hoàn thành', 0),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColors.bg,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Quản lý đơn'),
            const Spacer(),
            // Emergency close toggle
            Row(
              children: [
                const Text('Đang mở', style: TextStyle(fontSize: 13, color: VColors.success)),
                const SizedBox(width: VS.sm),
                Switch(
                  value: true,
                  onChanged: (_) => _showEmergencyDialog(context),
                  activeThumbColor: VColors.success,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: VColors.primary,
          unselectedLabelColor: VColors.n400,
          indicatorColor: VColors.primary,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: _tabs.map((t) {
            final (label, count) = t;
            return Tab(
              child: Row(
                children: [
                  Text(label),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 18, height: 18,
                      decoration: const BoxDecoration(
                        color: VColors.primary, shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('$count', style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white,
                        )),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _OrderList(status: 'pending_store'),
          _OrderList(status: 'preparing'),
          _OrderList(status: 'delivering'),
          _OrderList(status: 'delivered_partial'),
          _OrderList(status: 'completed'),
        ],
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VS.radiusLg)),
        title: const Text('Đóng cửa khẩn cấp?', style: VTextStyles.h3),
        content: const Text(
          'Quán sẽ bị ẩn khỏi feed và không nhận đơn mới. '
          'Đơn đang xử lý vẫn tiếp tục bình thường.',
          style: VTextStyles.body1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: VColors.error),
            child: const Text('Đóng cửa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final String status;
  const _OrderList({required this.status});

  @override
  Widget build(BuildContext context) {
    final orders = _mockOrders.where((o) => o.status == status).toList();
    if (orders.isEmpty) {
      return VEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Không có đơn',
        subtitle: 'Chưa có đơn hàng trong mục này',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(VS.base),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: VS.md),
      itemBuilder: (_, i) => StoreOrderCard(order: orders[i]),
    );
  }
}

// ─── STORE ORDER CARD ─────────────────────────────────────────────────────────
class StoreOrderCard extends StatelessWidget {
  final StoreOrderModel order;
  const StoreOrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return VCard(
      padding: EdgeInsets.zero,
      onTap: () => _showOrderDetail(context),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(VS.md),
            child: Row(
              children: [
                // Order code
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${order.code.substring(0, order.code.length - 3)}-',
                        style: const TextStyle(
                          fontSize: 14, color: VColors.n400, fontFamily: 'monospace',
                        ),
                      ),
                      TextSpan(
                        text: order.code.substring(order.code.length - 3),
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: VColors.n800, fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (order.status == 'pending_store')
                  VCountdown(remaining: order.timeRemaining, urgent: order.timeRemaining.inMinutes < 5),
              ],
            ),
          ),

          const Divider(height: 1),

          // Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VS.md, vertical: VS.sm),
            child: Column(
              children: order.items.map((item) => Row(
                children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: VColors.n100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text('${item.qty}', style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700, color: VColors.n600,
                      )),
                    ),
                  ),
                  const SizedBox(width: VS.sm),
                  Expanded(child: Text(item.name, style: VTextStyles.label1)),
                  VPrice(amount: item.price * item.qty),
                ],
              )).toList(),
            ),
          ),

          const Divider(height: 1),

          // Footer
          Padding(
            padding: const EdgeInsets.all(VS.md),
            child: Row(
              children: [
                Icon(
                  order.delivery == 'A' ? Icons.delivery_dining_outlined
                    : order.delivery == 'B' ? Icons.store_outlined
                    : Icons.directions_bike_outlined,
                  size: 16, color: VColors.n400,
                ),
                const SizedBox(width: 4),
                Text(
                  order.delivery == 'A' ? 'Giao tận nơi'
                    : order.delivery == 'B' ? 'Tự đến lấy' : 'Shipper riêng',
                  style: VTextStyles.body2,
                ),
                const SizedBox(width: VS.md),
                Container(
                  width: 1, height: 12, color: VColors.n200,
                ),
                const SizedBox(width: VS.md),
                Icon(
                  order.payment == 'transfer' ? Icons.account_balance_outlined : Icons.payments_outlined,
                  size: 16, color: VColors.n400,
                ),
                const SizedBox(width: 4),
                Text(
                  order.payment == 'transfer' ? 'CK trước' : 'COD',
                  style: VTextStyles.body2,
                ),
                const Spacer(),
                VPrice(amount: order.total),
              ],
            ),
          ),

          // Action buttons
          if (order.status == 'pending_store')
            _PendingActions(order: order)
          else if (order.status == 'preparing')
            _PreparingActions(order: order)
          else if (order.status == 'delivering')
            _DeliveringActions(order: order),
        ],
      ),
    );
  }

  void _showOrderDetail(BuildContext context) {
    Navigator.pushNamed(context, '/store-order-detail');
  }
}

// ─── ORDER ACTION BARS ────────────────────────────────────────────────────────
class _PendingActions extends StatelessWidget {
  final StoreOrderModel order;
  const _PendingActions({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(VS.md, 0, VS.md, VS.md),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showRejectDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: VColors.error,
                side: const BorderSide(color: VColors.error),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Từ chối', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: VS.md),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: VColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('✓ Nhận đơn',
                style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VS.radiusLg)),
        title: const Text('Từ chối đơn hàng', style: VTextStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vui lòng nhập lý do từ chối:', style: VTextStyles.body1),
            const SizedBox(height: VS.md),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'VD: Hết nguyên liệu, quán đã đóng cửa...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: VColors.error),
            child: const Text('Từ chối đơn', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _PreparingActions extends StatelessWidget {
  final StoreOrderModel order;
  const _PreparingActions({required this.order});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(VS.md, 0, VS.md, VS.md),
      child: Column(
        children: [
          if (order.payment == 'transfer')
            Padding(
              padding: const EdgeInsets.only(bottom: VS.sm),
              child: OutlinedButton.icon(
                onPressed: () => _reportNotReceived(context),
                icon: const Icon(Icons.warning_amber_outlined, size: 16),
                label: const Text('Tiền chưa vào TK'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: VColors.warning,
                  side: const BorderSide(color: VColors.warning),
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ),
          Row(
            children: [
              if (order.delivery == 'A') ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VColors.info,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('🛵 Bàn giao shipper',
                      style: TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      order.delivery == 'B' ? '✓ Khách đã lấy' : '✓ Đã bàn giao',
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _reportNotReceived(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VS.radiusLg)),
        title: const Text('Tiền chưa vào TK?', style: VTextStyles.h3),
        content: const Text(
          'Khách sẽ nhận thông báo và có 10 phút để xác nhận lại. '
          'Nếu không phản hồi, đơn sẽ bị huỷ tự động.',
          style: VTextStyles.body1,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: VColors.warning),
            child: const Text('Xác nhận', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _DeliveringActions extends StatelessWidget {
  final StoreOrderModel order;
  const _DeliveringActions({required this.order});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(VS.md, 0, VS.md, VS.md),
    child: ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: VColors.success,
        minimumSize: const Size(double.infinity, 44),
      ),
      child: const Text('✓ Đã giao hàng',
        style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
    ),
  );
}

// ─── MENU PAGE ────────────────────────────────────────────────────────────────
class StoreMenuPage extends StatefulWidget {
  const StoreMenuPage({super.key});

  @override
  State<StoreMenuPage> createState() => _StoreMenuPageState();
}

class _StoreMenuPageState extends State<StoreMenuPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColors.bg,
      appBar: AppBar(
        title: const Text('Quản lý Menu'),
        actions: [
          TextButton.icon(
            onPressed: () => _showAddItem(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Thêm món'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(VS.base),
        children: [
          _MenuCategorySection(
            category: 'Món chính',
            items: _mockMenuItems,
            onEditItem: (_) => _showAddItem(context),
            onToggleItem: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  void _showAddItem(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VS.radiusXl)),
      ),
      builder: (_) => const AddMenuItemSheet(),
    );
  }
}

class _MenuCategorySection extends StatelessWidget {
  final String category;
  final List<StoreMenuItemModel> items;
  final ValueChanged<StoreMenuItemModel> onEditItem;
  final ValueChanged<StoreMenuItemModel> onToggleItem;

  const _MenuCategorySection({
    required this.category, required this.items,
    required this.onEditItem, required this.onToggleItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(category, style: VTextStyles.h3),
            const Spacer(),
            TextButton(onPressed: () {}, child: const Text('Sửa danh mục')),
          ],
        ),
        const SizedBox(height: VS.sm),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: VS.sm),
          child: _MenuItemRow(item: item, onEdit: () => onEditItem(item),
            onToggle: () => onToggleItem(item)),
        )),
      ],
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final StoreMenuItemModel item;
  final VoidCallback onEdit, onToggle;

  const _MenuItemRow({required this.item, required this.onEdit, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VColors.surface,
        borderRadius: BorderRadius.circular(VS.radiusMd),
        border: Border.all(color: VColors.n100),
        boxShadow: VShadows.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(
              color: VColors.n100,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(VS.radiusMd)),
            ),
            child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: VS.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: VTextStyles.label1),
                VPrice(amount: item.price),
                if (item.stock != null)
                  Text('Còn ${item.stock} phần',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: item.stock! <= 3 ? VColors.error : VColors.success,
                    )),
              ],
            ),
          ),
          Row(
            children: [
              Switch(
                value: item.isActive,
                onChanged: (_) => onToggle(),
                activeThumbColor: VColors.success,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: VColors.n500),
                onPressed: onEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── ADD MENU ITEM SHEET ──────────────────────────────────────────────────────
class AddMenuItemSheet extends StatefulWidget {
  const AddMenuItemSheet({super.key});

  @override
  State<AddMenuItemSheet> createState() => _AddMenuItemSheetState();
}

class _AddMenuItemSheetState extends State<AddMenuItemSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  bool _manageStock = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const VSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thêm món mới', style: VTextStyles.h2),
                const SizedBox(height: VS.xl),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Tên món *'),
                ),
                const SizedBox(height: VS.md),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                ),
                const SizedBox(height: VS.md),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giá *',
                    suffixText: 'đ',
                  ),
                ),
                const SizedBox(height: VS.md),
                Row(
                  children: [
                    Checkbox(
                      value: _manageStock,
                      onChanged: (v) => setState(() => _manageStock = v ?? false),
                      activeColor: VColors.primary,
                    ),
                    const Text('Quản lý tồn kho', style: VTextStyles.label1),
                  ],
                ),
                if (_manageStock) ...[
                  TextFormField(
                    controller: _stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số lượng tồn kho',
                      hintText: 'VD: 50',
                    ),
                  ),
                  const SizedBox(height: VS.sm),
                  const Text(
                    'Khi tồn kho = 0, món sẽ tự ẩn khỏi menu',
                    style: TextStyle(fontSize: 11, color: VColors.n400),
                  ),
                ],
                const SizedBox(height: VS.xl),
                VButton(
                  label: 'Lưu món',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── STORE SETTINGS PAGE ─────────────────────────────────────────────────────
class StoreSettingsPage extends StatefulWidget {
  const StoreSettingsPage({super.key});

  @override
  State<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends State<StoreSettingsPage> {
  bool _cod = true, _transfer = true, _halfhalf = false, _momo = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColors.bg,
      appBar: AppBar(title: const Text('Cài đặt quán')),
      body: ListView(
        children: [
          // Store info section
          Container(
            color: VColors.surface,
            padding: const EdgeInsets.all(VS.base),
            child: Row(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: VColors.n100,
                    borderRadius: BorderRadius.circular(VS.radiusMd),
                  ),
                  child: const Center(child: Text('🍜', style: TextStyle(fontSize: 32))),
                ),
                const SizedBox(width: VS.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Phở Hà Nội 1954', style: VTextStyles.h3),
                      Text('Đang hoạt động', style: TextStyle(
                        fontSize: 13, color: VColors.success, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('Sửa')),
              ],
            ),
          ),
          const VSectionDivider(),

          // Opening hours
          _SettingsSection(
            title: 'Giờ mở cửa',
            children: [
              ...[
                'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật',
              ].asMap().entries.map((e) => _HoursRow(
                day: e.value, openTime: '07:00', closeTime: '22:00', isOpen: e.key != 0,
              )),
            ],
          ),
          const VSectionDivider(),

          // Payment methods
          _SettingsSection(
            title: 'Phương thức thanh toán',
            children: [
              _SwitchRow(label: 'Chuyển khoản trước', value: _transfer,
                onChanged: (v) => setState(() => _transfer = v)),
              _SwitchRow(label: 'COD (Thu khi giao)', value: _cod,
                onChanged: (v) => setState(() => _cod = v)),
              _SwitchRow(label: '50/50 (Nửa trước, nửa sau)', value: _halfhalf,
                onChanged: (v) => setState(() => _halfhalf = v)),
              _SwitchRow(label: 'Momo', value: _momo,
                onChanged: (v) => setState(() => _momo = v)),
            ],
          ),
          const VSectionDivider(),

          // Ship fee formula
          const _SettingsSection(
            title: 'Công thức phí ship',
            subtitle: 'Công thức: (A + B × km) × (1 + C%)',
            children: [
              _FormulaInput(label: 'A — Phí cố định (đ)', value: '12000'),
              _FormulaInput(label: 'B — Giá/km (đ)', value: '5000'),
              _FormulaInput(label: 'C — % cao điểm', value: '0'),
            ],
          ),
          const VSectionDivider(),

          // Auto settings
          const _SettingsSection(
            title: 'Tự động hoá',
            children: [
              _FormulaInput(label: 'Tự huỷ nếu không nhận (phút)', value: '15'),
              _FormulaInput(label: 'Tự nhận đơn sau (phút, 0 = tắt)', value: '0'),
            ],
          ),
          const VSectionDivider(),

          // Bank account
          _SettingsSection(
            title: 'Tài khoản ngân hàng',
            children: [
              const _InfoRowStatic('Ngân hàng', 'Vietcombank'),
              const _InfoRowStatic('Số TK', '0123456789'),
              const _InfoRowStatic('Chủ TK', 'NGUYEN VAN A'),
              const SizedBox(height: VS.sm),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Cập nhật TK ngân hàng'),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SettingsSection({required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VColors.surface,
      padding: const EdgeInsets.all(VS.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: VTextStyles.h3),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: VTextStyles.body2),
          ],
          const SizedBox(height: VS.md),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: VTextStyles.label1)),
        Switch(value: value, onChanged: onChanged, activeThumbColor: VColors.primary),
      ],
    ),
  );
}

class _HoursRow extends StatelessWidget {
  final String day, openTime, closeTime;
  final bool isOpen;

  const _HoursRow({
    required this.day, required this.openTime,
    required this.closeTime, required this.isOpen,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(width: 56, child: Text(day, style: VTextStyles.label1)),
        if (!isOpen)
          const Expanded(child: Text('Đóng cửa', style: VTextStyles.body2))
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: VColors.n50, borderRadius: BorderRadius.circular(VS.radiusSm),
              border: Border.all(color: VColors.n200),
            ),
            child: Text(openTime, style: VTextStyles.label2),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('–', style: VTextStyles.body2)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: VColors.n50, borderRadius: BorderRadius.circular(VS.radiusSm),
              border: Border.all(color: VColors.n200),
            ),
            child: Text(closeTime, style: VTextStyles.label2),
          ),
        ],
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 16, color: VColors.n400),
          onPressed: () {},
          constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
          padding: EdgeInsets.zero,
        ),
      ],
    ),
  );
}

class _FormulaInput extends StatelessWidget {
  final String label, value;
  const _FormulaInput({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: VS.sm),
    child: Row(
      children: [
        Expanded(child: Text(label, style: VTextStyles.label1)),
        SizedBox(
          width: 90,
          child: TextFormField(
            initialValue: value,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
          ),
        ),
      ],
    ),
  );
}

class _InfoRowStatic extends StatelessWidget {
  final String label, value;
  const _InfoRowStatic(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: VTextStyles.body2)),
        Text(value, style: VTextStyles.label1),
      ],
    ),
  );
}

// ─── MOCK DATA ────────────────────────────────────────────────────────────────
class StoreOrderModel {
  final String code, status, delivery, payment;
  final List<_OrderItem> items;
  final int total;
  final Duration timeRemaining;

  const StoreOrderModel({
    required this.code, required this.status, required this.delivery,
    required this.payment, required this.items, required this.total,
    this.timeRemaining = const Duration(minutes: 12),
  });
}

class _OrderItem {
  final String name;
  final int price, qty;
  const _OrderItem(this.name, this.price, this.qty);
}

class StoreMenuItemModel {
  final String id, name, emoji;
  final int price;
  final int? stock;
  final bool isActive;

  const StoreMenuItemModel({
    required this.id, required this.name, required this.emoji,
    required this.price, this.stock, this.isActive = true,
  });
}

final _mockOrders = [
  const StoreOrderModel(
    code: 'AB251107-456', status: 'pending_store',
    delivery: 'A', payment: 'transfer',
    items: [_OrderItem('Phở bò tái', 65000, 1), _OrderItem('Trà đá', 10000, 2)],
    total: 102000, timeRemaining: Duration(minutes: 8),
  ),
  const StoreOrderModel(
    code: 'CD251107-123', status: 'pending_store',
    delivery: 'B', payment: 'cod',
    items: [_OrderItem('Phở gà', 55000, 2)],
    total: 110000, timeRemaining: Duration(minutes: 3),
  ),
  const StoreOrderModel(
    code: 'EF251107-789', status: 'preparing',
    delivery: 'A', payment: 'transfer',
    items: [_OrderItem('Phở bò chín', 65000, 1)],
    total: 82000, timeRemaining: Duration(minutes: 20),
  ),
];

final _mockMenuItems = [
  const StoreMenuItemModel(id: '1', name: 'Phở bò tái', emoji: '🍜', price: 65000, isActive: true),
  const StoreMenuItemModel(id: '2', name: 'Phở bò chín', emoji: '🍜', price: 65000, stock: 10, isActive: true),
  const StoreMenuItemModel(id: '3', name: 'Phở gà', emoji: '🍗', price: 55000, stock: 0, isActive: false),
  const StoreMenuItemModel(id: '4', name: 'Trà đá', emoji: '🧊', price: 10000, isActive: true),
];

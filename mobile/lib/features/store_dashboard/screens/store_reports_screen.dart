// lib/features/store_dashboard/screens/store_reports_screen.dart
//
// Báo cáo doanh thu — lọc theo ngày hoặc khoảng ngày, tìm theo mã đơn.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../models/store_order.dart';

final _currency = NumberFormat('#,##0', 'vi_VN');
final _dateFmt   = DateFormat('dd/MM/yyyy');
final _timeFmt   = DateFormat('HH:mm dd/MM');

class StoreReportsScreen extends StatefulWidget {
  final String storeId;
  const StoreReportsScreen({super.key, required this.storeId});

  @override
  State<StoreReportsScreen> createState() => _StoreReportsScreenState();
}

class _StoreReportsScreenState extends State<StoreReportsScreen> {
  // ─── Date selection ───────────────────────────────────────────────────────
  bool _isRangeMode = false;
  DateTime _singleDate = DateTime.now();
  DateTime _dateFrom   = DateTime.now();
  DateTime _dateTo     = DateTime.now();

  // ─── Filters ──────────────────────────────────────────────────────────────
  String _statusFilter = 'all';   // 'all' | 'completed' | 'cancelled'
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ─── Data ─────────────────────────────────────────────────────────────────
  List<StoreOrder> _orders = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  DateTime get _effectiveFrom => _isRangeMode ? _dateFrom : _singleDate;
  DateTime get _effectiveTo   => _isRangeMode ? _dateTo   : _singleDate;

  String _toIsoStart(DateTime d) =>
      DateTime(d.year, d.month, d.day).toIso8601String();
  String _toIsoEnd(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999).toIso8601String();

  // ─── Fetch ────────────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await DioClient.instance.get(
        ApiEndpoints.myStoreOrders(widget.storeId),
        queryParameters: {
          'tab':      'history',
          'limit':    '200',
          'dateFrom': _toIsoStart(_effectiveFrom),
          'dateTo':   _toIsoEnd(_effectiveTo),
        },
      );
      final data = res.data is Map ? res.data as Map<String, dynamic> : <String, dynamic>{};
      final list = data['orders'] as List? ?? (res.data as List? ?? []);
      setState(() {
        _orders = list
            .map((e) => StoreOrder.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  // ─── Computed stats ───────────────────────────────────────────────────────

  List<StoreOrder> get _filtered {
    var list = _orders;
    if (_statusFilter == 'completed') {
      list = list.where((o) => o.mainStatus == 'completed').toList();
    } else if (_statusFilter == 'cancelled') {
      list = list.where((o) => o.mainStatus == 'cancelled').toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((o) => o.code.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  int    get _totalOrders    => _orders.length;
  int    get _completedCount => _orders.where((o) => o.mainStatus == 'completed').length;
  int    get _cancelledCount => _orders.where((o) => o.mainStatus == 'cancelled').length;
  double get _revenue        => _orders
      .where((o) => o.mainStatus == 'completed')
      .fold(0.0, (s, o) => s + o.total);

  // ─── Date picker ──────────────────────────────────────────────────────────

  Future<void> _pickSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _singleDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _singleDate = picked);
      _fetch();
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom,
      firstDate: DateTime(2023),
      lastDate: _dateTo,
    );
    if (picked != null) {
      setState(() => _dateFrom = picked);
      _fetch();
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo,
      firstDate: _dateFrom,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateTo = picked);
      _fetch();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetch,
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Date selector ──────────────────────────────────────────────
          _buildDateSelector(),

          // ─── Stats ──────────────────────────────────────────────────────
          _buildStats(),

          // ─── Filter chips ────────────────────────────────────────────────
          _buildFilterChips(),

          // ─── Search ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Tìm theo mã đơn...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        })
                    : null,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),

          // ─── List ────────────────────────────────────────────────────────
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Chế độ:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() => _isRangeMode = false);
                  _fetch();
                },
                child: _ModeChip(label: 'Một ngày', active: !_isRangeMode),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  setState(() => _isRangeMode = true);
                  _fetch();
                },
                child: _ModeChip(label: 'Khoảng ngày', active: _isRangeMode),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_isRangeMode)
            GestureDetector(
              onTap: _pickSingleDate,
              child: _DateBox(
                label: 'Ngày',
                value: _dateFmt.format(_singleDate),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickFromDate,
                    child: _DateBox(
                      label: 'Từ ngày',
                      value: _dateFmt.format(_dateFrom),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickToDate,
                    child: _DateBox(
                      label: 'Đến ngày',
                      value: _dateFmt.format(_dateTo),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Lỗi: $_error',
            style: const TextStyle(color: Colors.red, fontSize: 13)),
      );
    }
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          _StatItem(
            label: 'Tổng đơn',
            value: '$_totalOrders',
            color: Colors.blueGrey,
          ),
          const _Divider(),
          _StatItem(
            label: 'Hoàn thành',
            value: '$_completedCount',
            color: Colors.green,
          ),
          const _Divider(),
          _StatItem(
            label: 'Đã hủy',
            value: '$_cancelledCount',
            color: Colors.red,
          ),
          const _Divider(),
          _StatItem(
            label: 'Doanh thu',
            value: _fmtRevenue(_revenue),
            color: AppTheme.primary,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _FilterChip(
            label: 'Tất cả',
            active: _statusFilter == 'all',
            onTap: () => setState(() => _statusFilter = 'all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Hoàn thành',
            active: _statusFilter == 'completed',
            onTap: () => setState(() => _statusFilter = 'completed'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Đã hủy',
            active: _statusFilter == 'cancelled',
            onTap: () => setState(() => _statusFilter = 'cancelled'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) return const SizedBox.shrink();
    final orders = _filtered;
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Không có đơn nào trong khoảng này',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: orders.length,
      itemBuilder: (context, i) => _OrderReportCard(order: orders[i]),
    );
  }

  String _fmtRevenue(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M đ';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k đ';
    return '${v.toStringAsFixed(0)}đ';
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  final String label;
  final bool active;
  const _ModeChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppTheme.primary : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          color: active ? Colors.white : Colors.grey.shade700,
        ),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  final String label;
  final String value;
  const _DateBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          Icon(Icons.calendar_today_outlined,
              size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 15 : 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 1,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppTheme.primary : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _OrderReportCard extends StatelessWidget {
  final StoreOrder order;
  const _OrderReportCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isCompleted = order.mainStatus == 'completed';
    final isCancelled = order.mainStatus == 'cancelled';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? Colors.green
                  : isCancelled
                      ? Colors.red
                      : Colors.grey,
            ),
          ),
          const SizedBox(width: 10),
          // Order info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order.code}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  _timeFmt.format(order.createdAt),
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
                if (order.recipientName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    order.recipientName!,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isCompleted)
                Text(
                  '${_currency.format(order.total)} đ',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.green),
                )
              else
                Text(
                  isCancelled ? 'Đã hủy' : order.mainStatus,
                  style: TextStyle(
                      fontSize: 12,
                      color: isCancelled ? Colors.red : Colors.grey),
                ),
              const SizedBox(height: 4),
              Text(
                '${order.items.length} món',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

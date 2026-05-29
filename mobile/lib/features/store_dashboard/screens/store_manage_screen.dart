// lib/features/store_dashboard/screens/store_manage_screen.dart
//
// Màn hình Quản lý — truy cập từ bottom nav Dashboard → tab Quản lý

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';

class StoreManageScreen extends StatelessWidget {
  final String storeId;
  const StoreManageScreen({super.key, required this.storeId});

  Future<void> _confirmDeleteStore(BuildContext context) async {
    // Bước 1: cảnh báo
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa cửa hàng?'),
        content: const Text(
          'Cửa hàng sẽ bị xóa vĩnh viễn. Tất cả dữ liệu menu, đơn hàng liên quan sẽ bị ẩn. '
          'Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa cửa hàng'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Bước 2: xác nhận lần 2
    final doubleConfirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận lần cuối'),
        content: const Text(
            'Bạn có chắc chắn muốn xóa? Không thể khôi phục lại.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tôi chắc chắn, xóa ngay'),
          ),
        ],
      ),
    );
    if (doubleConfirm != true || !context.mounted) return;

    try {
      await DioClient.instance.delete(ApiEndpoints.myStoreById(storeId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa cửa hàng')));
        context.go('/store-dashboard');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _onNavTap(BuildContext context, int i) {
    switch (i) {
      case 0:
        context.go('/store-dashboard/$storeId/orders');
        break;
      case 1:
        context.pushReplacement('/store-dashboard/$storeId/menu');
        break;
      case 2:
        context.pushReplacement('/store-dashboard/$storeId/reviews');
        break;
      case 3:
        context.pushReplacement('/store-dashboard/$storeId/reports');
        break;
      case 4:
        break; // đã ở trang Quản lý
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ManageCard(
            icon: Icons.add_business_outlined,
            title: 'Tạo cửa hàng mới',
            subtitle: 'Mở thêm cửa hàng mới trên hệ thống',
            onTap: () => context.push('/store/create'),
          ),
          const SizedBox(height: 12),
          const _ManageCard(
            icon: Icons.people_outline,
            title: 'Giao quyền cho nhân viên',
            subtitle: 'Phân quyền nhân viên quản lý cửa hàng',
            badge: 'Đang xây dựng',
            onTap: null,
          ),
          const SizedBox(height: 12),
          _ManageCard(
            icon: Icons.volunteer_activism_outlined,
            title: 'Hỗ trợ chúng tôi',
            subtitle: 'Để duy trì phần mềm miễn phí – Chiết khấu quán 0%',
            isHighlight: true,
            onTap: () => context.push('/profile/support-us'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          _ManageCard(
            icon: Icons.delete_forever_outlined,
            title: 'Xóa cửa hàng',
            subtitle: 'Xóa vĩnh viễn cửa hàng này khỏi hệ thống',
            isDanger: true,
            onTap: () => _confirmDeleteStore(context),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 4,
        onTap: (i) => _onNavTap(context, i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu_outlined),
              activeIcon: Icon(Icons.restaurant_menu),
              label: 'Menu'),
          BottomNavigationBarItem(
              icon: Icon(Icons.star_outline),
              activeIcon: Icon(Icons.star),
              label: 'Đánh giá'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Báo cáo'),
          BottomNavigationBarItem(
              icon: Icon(Icons.manage_accounts_outlined),
              activeIcon: Icon(Icons.manage_accounts),
              label: 'Quản lý'),
        ],
      ),
    );
  }
}

class _ManageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final bool isDanger;
  final bool isHighlight;
  final VoidCallback? onTap;

  const _ManageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.isDanger = false,
    this.isHighlight = false,
    this.onTap,
  });

  static const _highlightIcon    = Color(0xFFB87800);
  static const _highlightIconBg  = Color(0xFFFFE49A);
  static const _highlightTileBg  = Color(0xFFFFF8E6);
  static const _highlightBorder  = Color(0xFFFFD060);

  @override
  Widget build(BuildContext context) {
    final resolvedIconBg = isDanger
        ? Colors.red.withValues(alpha: 0.1)
        : isHighlight
            ? _highlightIconBg
            : onTap != null
                ? AppTheme.primary.withValues(alpha: 0.1)
                : Colors.grey.shade100;

    final resolvedIconColor = isDanger
        ? Colors.red
        : isHighlight
            ? _highlightIcon
            : onTap != null
                ? AppTheme.primary
                : Colors.grey;

    final resolvedTitleColor = isDanger
        ? Colors.red
        : isHighlight
            ? _highlightIcon
            : onTap != null
                ? Colors.black87
                : Colors.grey.shade500;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHighlight ? _highlightBorder : Colors.grey.shade200,
          width: isHighlight ? 1.5 : 1,
        ),
      ),
      color: isHighlight ? _highlightTileBg : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: resolvedIconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: resolvedIconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: resolvedTitleColor,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

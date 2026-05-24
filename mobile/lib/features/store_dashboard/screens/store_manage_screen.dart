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
          _ManageCard(
            icon: Icons.people_outline,
            title: 'Giao quyền cho nhân viên',
            subtitle: 'Phân quyền nhân viên quản lý cửa hàng',
            badge: 'Đang xây dựng',
            onTap: null,
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
    );
  }
}

class _ManageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final bool isDanger;
  final VoidCallback? onTap;

  const _ManageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.isDanger = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
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
                  color: isDanger
                      ? Colors.red.withValues(alpha: 0.1)
                      : onTap != null
                          ? AppTheme.primary.withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isDanger
                      ? Colors.red
                      : onTap != null
                          ? AppTheme.primary
                          : Colors.grey,
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
                            color: isDanger
                                ? Colors.red
                                : onTap != null
                                    ? Colors.black87
                                    : Colors.grey.shade500,
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
                              style: TextStyle(
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

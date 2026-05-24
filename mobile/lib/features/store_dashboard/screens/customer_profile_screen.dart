// lib/features/store_dashboard/screens/customer_profile_screen.dart
//
// Hồ sơ khách hàng — chủ quán xem khi tap vào khách trong đơn hàng.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';

// ─── Bottom sheet: danh sách đánh giá khách ──────────────────────────────────

void showCustomerReviewsSheet(
  BuildContext context, {
  required String storeId,
  required String customerId,
  required String customerName,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _CustomerReviewsSheet(
      storeId: storeId,
      customerId: customerId,
      customerName: customerName,
    ),
  );
}

class _CustomerReviewsSheet extends StatefulWidget {
  final String storeId;
  final String customerId;
  final String customerName;

  const _CustomerReviewsSheet({
    required this.storeId,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<_CustomerReviewsSheet> createState() => _CustomerReviewsSheetState();
}

class _CustomerReviewsSheetState extends State<_CustomerReviewsSheet> {
  List<Map<String, dynamic>>? _reviews;
  int _total = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await DioClient.instance.get(
        ApiEndpoints.storeCustomerReviews(widget.storeId, widget.customerId),
      );
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _reviews = (data['reviews'] as List).cast<Map<String, dynamic>>();
        _total   = (data['total'] as num?)?.toInt() ?? _reviews!.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SizedBox(
      height: mq.size.height * 0.7,
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đánh giá về ${widget.customerName}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!_isLoading && _reviews != null)
                  Text(
                    '$_total lượt',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Lỗi: $_error',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            OutlinedButton(
                                onPressed: _fetch,
                                child: const Text('Thử lại')),
                          ],
                        ),
                      )
                    : _reviews!.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_border,
                                    size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Chưa có đánh giá nào',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _reviews!.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) =>
                                _ReviewTile(review: _reviews![i]),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final from     = review['fromUserId'] as Map<String, dynamic>?;
    final fromName = from?['nickname'] as String? ?? 'Quán';
    final fromAvatar = from?['avatar'] as String?;
    final stars    = (review['stars'] as num?)?.toInt() ?? 0;
    final comment  = review['comment'] as String? ?? '';
    final isAnon   = review['isAnonymous'] as bool? ?? false;
    final order    = review['orderId'] as Map<String, dynamic>?;
    final orderCode = order?['code'] as String?;
    final dt = DateTime.tryParse(review['createdAt'] as String? ?? '') ?? DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage:
                !isAnon && fromAvatar != null ? NetworkImage(fromAvatar) : null,
            child: (isAnon || fromAvatar == null)
                ? const Icon(Icons.storefront, size: 18)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isAnon ? 'Ẩn danh' : fromName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      '${dt.day}/${dt.month}/${dt.year}',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 14,
                        color: i < stars ? Colors.amber : Colors.grey.shade300,
                      ),
                    ),
                    if (orderCode != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Đơn $orderCode',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(comment, style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerProfileScreen extends StatefulWidget {
  final String storeId;
  final String customerId;

  const CustomerProfileScreen({
    super.key,
    required this.storeId,
    required this.customerId,
  });

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await DioClient.instance.get(
        ApiEndpoints.storeCustomerProfile(widget.storeId, widget.customerId),
      );
      setState(() {
        _data = res.data as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ khách')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Lỗi: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _fetch, child: const Text('Thử lại')),
                    ],
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    final nickname = d['nickname'] as String? ?? 'Người dùng';
    final avatar   = d['avatar']   as String?;
    final phone    = d['phone']    as String?;
    final address  = d['address']  as Map<String, dynamic>?;
    final rating   = d['customerRating']      as num?;
    final ratingCount = d['customerRatingCount'] as int? ?? 0;
    final completed = d['completedOrdersWithStore'] as int? ?? 0;
    final cancelled = d['cancelledOrdersWithStore'] as int? ?? 0;
    final likedStores = (d['likedStores'] as List?)?.cast<Map<String, dynamic>>();
    final likedItems  = (d['likedItems']  as List?)?.cast<Map<String, dynamic>>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ─── Avatar + Name ─────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage:
                    avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                nickname,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ─── Stats cards ───────────────────────────────────────────────────
        Row(
          children: [
            _StatCard(
              icon: Icons.star_rounded,
              iconColor: Colors.amber,
              label: 'Điểm khách',
              value: rating != null
                  ? '${rating.toStringAsFixed(1)} ($ratingCount đánh giá)'
                  : 'Chưa có',
              onTap: ratingCount > 0
                  ? () => showCustomerReviewsSheet(
                        context,
                        storeId: widget.storeId,
                        customerId: widget.customerId,
                        customerName: nickname,
                      )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline,
                iconColor: Colors.green,
                label: 'Đơn hoàn thành',
                value: '$completed',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: Icons.cancel_outlined,
                iconColor: Colors.red,
                label: 'Đơn đã hủy',
                value: '$cancelled',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ─── Contact ───────────────────────────────────────────────────────
        if (phone != null || address != null) ...[
          _SectionTitle('Liên hệ'),
          if (phone != null)
            _InfoRow(icon: Icons.phone_outlined, text: phone),
          if (address != null) ...[
            _InfoRow(
              icon: Icons.location_on_outlined,
              text: address['text'] as String? ?? '',
            ),
            if ((address['receiver'] as Map?)?.isNotEmpty == true) ...[
              _InfoRow(
                icon: Icons.person_outline,
                text:
                    '${(address['receiver'] as Map?)?['name'] ?? ''}'
                    '${(address['receiver'] as Map?)?['phone'] != null ? '  •  ${(address['receiver'] as Map?)!['phone']}' : ''}',
              ),
            ],
          ],
          const SizedBox(height: 16),
        ],

        // ─── Liked stores ─────────────────────────────────────────────────
        if (likedStores != null && likedStores.isNotEmpty) ...[
          _SectionTitle('Quán yêu thích'),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: likedStores.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = likedStores[i];
                final av = s['avatar'] as String?;
                return Column(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage:
                          av != null ? NetworkImage(av) : null,
                      child: av == null
                          ? const Icon(Icons.store, size: 20)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60,
                      child: Text(
                        s['name'] as String? ?? '',
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ─── Liked items ──────────────────────────────────────────────────
        if (likedItems != null && likedItems.isNotEmpty) ...[
          _SectionTitle('Món yêu thích'),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: likedItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final item = likedItems[i];
                final img  = item['image'] as String?;
                final price = item['price'] as num?;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: img != null
                          ? Image.network(img,
                              width: 56, height: 56, fit: BoxFit.cover)
                          : Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.fastfood, size: 28,
                                  color: Colors.grey)),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 64,
                      child: Text(
                        item['name'] as String? ?? '',
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (price != null)
                      Text(
                        '${NumberFormat('#,##0', 'vi_VN').format(price)}đ',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],

        // ─── Privacy note ─────────────────────────────────────────────────
        if (likedStores == null && likedItems == null && phone == null && address == null)
          Center(
            child: Text(
              'Khách chưa công khai thông tin chi tiết',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: onTap != null
                  ? Colors.amber.shade200
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right,
                    size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Colors.black87),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

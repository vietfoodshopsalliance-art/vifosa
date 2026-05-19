// lib/features/store_detail/widgets/info_tab.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/store.dart';

class InfoTab extends StatelessWidget {
  final Store store;

  const InfoTab({super.key, required this.store});

  static const _dayLabels = {
    'mon': 'Thứ 2',
    'tue': 'Thứ 3',
    'wed': 'Thứ 4',
    'thu': 'Thứ 5',
    'fri': 'Thứ 6',
    'sat': 'Thứ 7',
    'sun': 'Chủ nhật',
  };

  Future<void> _openMaps(String address) async {
    final query = Uri.encodeComponent(address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Địa chỉ ──────────────────────────────────────────────────
          _InfoRow(
            icon: Icons.location_on_outlined,
            child: Row(
              children: [
                Expanded(
                  child: Text(store.addressText,
                      style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openMaps(store.addressText),
                  icon: const Icon(Icons.map_outlined, size: 14),
                  label: const Text('Mở Maps', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── SĐT (nếu public) ─────────────────────────────────────────
          if (store.phone?.isNotEmpty == true) ...[
            _InfoRow(
              icon: Icons.phone_outlined,
              child: GestureDetector(
                onTap: () => _callPhone(store.phone!),
                child: Text(
                  store.phone!,
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Giờ mở ───────────────────────────────────────────────────
          _InfoRow(
            icon: Icons.access_time_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _dayLabels.entries.map((e) {
                final hours = store.openHours[e.key];
                final isClosed = hours == null || !hours.isOpen;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isClosed
                                ? FontWeight.normal
                                : FontWeight.w500,
                            color: isClosed ? Colors.grey : null,
                          ),
                        ),
                      ),
                      Text(
                        isClosed
                            ? 'Đóng cả ngày'
                            : '${hours!.open} - ${hours.close}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isClosed ? Colors.grey : null,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // ── Ảnh thêm ─────────────────────────────────────────────────
          if (store.extraImages?.isNotEmpty == true) ...[
            const Text(
              'Ảnh thêm',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: store.extraImages!.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: store.extraImages![i],
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Widget child;

  const _InfoRow({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}
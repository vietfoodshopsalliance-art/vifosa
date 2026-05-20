// lib/features/store_detail/widgets/info_tab.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/store.dart';

class InfoTab extends StatelessWidget {
  final Store store;

  const InfoTab({super.key, required this.store});

  Future<void> _openMaps(String address) async {
    final query = Uri.encodeComponent(address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

          // ── Giờ mở ───────────────────────────────────────────────────
          _InfoRow(
            icon: Icons.access_time_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(7, (index) {
                // dayOfWeek: 0=Sun, 1=Mon..6=Sat; show Mon-Sun order
                final dow = index + 1 <= 6 ? index + 1 : 0;
                final dayName = const [
                  'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'
                ][index];
                final h = store.openingHours.where((h) => h.dayOfWeek == dow).firstOrNull;
                final isClosed = h == null || h.isClosed;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isClosed ? FontWeight.normal : FontWeight.w500,
                            color: isClosed ? Colors.grey : null,
                          ),
                        ),
                      ),
                      Text(
                        isClosed ? 'Đóng cả ngày' : '${h!.open} - ${h.close}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isClosed ? Colors.grey : null,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
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
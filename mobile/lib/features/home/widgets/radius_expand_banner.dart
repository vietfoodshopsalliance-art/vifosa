// lib/features/home/widgets/radius_expand_banner.dart
// Banner "Mở rộng tìm kiếm" — chỉ hiện khi không đủ kết quả

import 'package:flutter/material.dart';

class RadiusExpandBanner extends StatelessWidget {
  final double currentRadius;
  final VoidCallback onExpand10;
  final VoidCallback onExpand25;

  const RadiusExpandBanner({
    super.key,
    required this.currentRadius,
    required this.onExpand10,
    required this.onExpand25,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              size: 18, color: Color(0xFFF57C00)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Ít quán trong khu vực. Mở rộng bán kính:',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF7B4A00),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Nút 10km (ẩn nếu radius đã >= 10)
          if (currentRadius < 10)
            _ExpandButton(label: '10km', onTap: onExpand10),
          if (currentRadius < 10) const SizedBox(width: 6),
          // Nút 25km (ẩn nếu radius đã >= 25)
          if (currentRadius < 25)
            _ExpandButton(label: '25km', onTap: onExpand25),
        ],
      ),
    );
  }
}

class _ExpandButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ExpandButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF57C00),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

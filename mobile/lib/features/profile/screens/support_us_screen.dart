// lib/features/profile/screens/support_us_screen.dart

import 'package:flutter/material.dart';

const _bg      = Color(0xFFF7F2E8);
const _card    = Colors.white;
const _txtMain = Color(0xFF1A1200);
const _txtSub  = Color(0xFF8A7862);
const _iconBg  = Color(0xFFF2EDE0);
const _divider = Color(0xFFF0E8D8);
const _accent  = Color(0xFFF4B400);

class SupportUsScreen extends StatelessWidget {
  const SupportUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
        iconTheme: const IconThemeData(color: _txtMain),
        title: const Text(
          'Hỗ trợ chúng tôi',
          style: TextStyle(
            color: _txtMain,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.volunteer_activism, color: _accent, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hãy hỗ trợ chúng tôi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _txtMain,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Để duy trì phần mềm miễn phí, chiết khấu quán 0%',
                        style: TextStyle(fontSize: 13, color: _txtSub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Actions card
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  _SupportTile(
                    icon: Icons.star_outline,
                    label: 'Đánh giá, góp ý',
                    onTap: () => _showComingSoon(context),
                  ),
                  const Divider(height: 1, thickness: 0.5, indent: 60, color: _divider),
                  _SupportTile(
                    icon: Icons.people_outline,
                    label: 'Giới thiệu bạn bè',
                    onTap: () => _showComingSoon(context),
                  ),
                  const Divider(height: 1, thickness: 0.5, indent: 60, color: _divider),
                  _SupportTile(
                    icon: Icons.play_circle_outline,
                    label: 'Xem quảng cáo 30s',
                    onTap: () => _showComingSoon(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tính năng đang xây dựng, sắp ra mắt!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SupportTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF6B5230)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _txtMain,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                'Đang build',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

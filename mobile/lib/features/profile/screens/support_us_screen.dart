// lib/features/profile/screens/support_us_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/providers/auth_provider.dart';

const _bg      = Color(0xFFF7F2E8);
const _card    = Colors.white;
const _txtMain = Color(0xFF1A1200);
const _txtSub  = Color(0xFF8A7862);
const _iconBg  = Color(0xFFF2EDE0);
const _divider = Color(0xFFF0E8D8);
const _accent  = Color(0xFFF4B400);

// Test ID của Google khi debug — real ID khi release
const _adUnitId = kDebugMode
    ? 'ca-app-pub-3940256099942544/5354046379'
    : 'ca-app-pub-6615086832239602/7262026462';

class SupportUsScreen extends ConsumerStatefulWidget {
  const SupportUsScreen({super.key});

  @override
  ConsumerState<SupportUsScreen> createState() => _SupportUsScreenState();
}

class _SupportUsScreenState extends ConsumerState<SupportUsScreen> {
  RewardedAd? _ad;
  bool _adLoading = !kDebugMode; // debug: luôn sẵn sàng; release: chờ load
  bool _rewarding = false;

  @override
  void initState() {
    super.initState();
    if (!kDebugMode) _loadAd();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _loadAd() {
    setState(() => _adLoading = true);
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) { ad.dispose(); return; }
          setState(() { _ad = ad; _adLoading = false; });
        },
        onAdFailedToLoad: (error) {
          if (!mounted) return;
          setState(() { _ad = null; _adLoading = false; });
        },
      ),
    );
  }

  // ── Reward grant (shared) ────────────────────────────────────────────────────

  Future<void> _grantReward() async {
    try {
      await DioClient.instance.post('/me/ad-reward');
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn nhận được 1 EXP! Cảm ơn đã ủng hộ Viet Shops!'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Có lỗi xảy ra, vui lòng thử lại')),
        );
      }
    }
  }

  // ── Debug: giả lập 5 giây xem quảng cáo ─────────────────────────────────────

  Future<void> _debugSimulate() async {
    setState(() => _rewarding = true);
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) { setState(() => _rewarding = false); return; }
    await _grantReward();
    if (mounted) setState(() => _rewarding = false);
  }

  // ── Release: hiện real rewarded ad ───────────────────────────────────────────

  Future<void> _showAd() async {
    if (_ad == null) return;
    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (mounted) setState(() => _ad = null);
        _loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (mounted) setState(() => _ad = null);
        _loadAd();
      },
    );
    await _ad!.show(
      onUserEarnedReward: (ad, reward) async {
        setState(() => _rewarding = true);
        await _grantReward();
        if (mounted) setState(() => _rewarding = false);
      },
    );
  }

  // ── Entry point ───────────────────────────────────────────────────────────────

  Future<void> _onTapAd() async {
    if (_rewarding) return;
    if (kDebugMode) {
      await _debugSimulate();
    } else {
      await _showAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final exp = (ref.watch(authProvider).user?['exp'] as num?)?.toInt() ?? 0;
    final adReady = kDebugMode || _ad != null;

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

          const SizedBox(height: 12),

          // EXP badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                const Icon(Icons.military_tech, color: _accent, size: 22),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$exp EXP tích lũy',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _txtMain,
                      ),
                    ),
                    const Text(
                      'Cám ơn bạn đã hỗ trợ chúng tôi!',
                      style: TextStyle(fontSize: 12, color: _txtSub),
                    ),
                  ],
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
                  _WatchAdTile(
                    isLoading: _adLoading,
                    isRewarding: _rewarding,
                    adReady: adReady,
                    onTap: _onTapAd,
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

// ── Watch Ad Tile ─────────────────────────────────────────────────────────────

class _WatchAdTile extends StatelessWidget {
  final bool isLoading;
  final bool isRewarding;
  final bool adReady;
  final VoidCallback onTap;

  const _WatchAdTile({
    required this.isLoading,
    required this.isRewarding,
    required this.adReady,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final busy = isLoading || isRewarding;

    String label;
    Widget? trailing;

    if (isRewarding) {
      label = 'Đang ghi nhận...';
      trailing = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
      );
    } else if (isLoading) {
      label = 'Đang tải quảng cáo...';
      trailing = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
      );
    } else if (adReady) {
      label = 'Xem quảng cáo 30s';
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.military_tech, color: Colors.white, size: 13),
            SizedBox(width: 4),
            Text(
              '+1 EXP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    } else {
      label = 'Xem quảng cáo 30s';
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          'Không có quảng cáo',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      );
    }

    return InkWell(
      onTap: (!busy && adReady) ? onTap : null,
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
              child: Icon(
                Icons.play_circle_outline,
                size: 20,
                color: (!busy && adReady)
                    ? const Color(0xFF6B5230)
                    : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: (!busy && adReady) ? _txtMain : Colors.grey.shade400,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}

// ── Support Tile (generic) ────────────────────────────────────────────────────

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

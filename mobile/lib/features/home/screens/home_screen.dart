// lib/features/home/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/store_card.dart';
import '../providers/home_feed_provider.dart';
import '../widgets/store_card_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(homeFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(homeFeedProvider);
    final radius = ref.watch(homeFeedRadiusProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: RefreshIndicator(
        color: const Color(0xFFE53935),
        onRefresh: () => ref.read(homeFeedProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            _buildAppBar(context),
            _buildRadiusSelector(radius),
            if (feed.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
              )
            else if (feed.error != null && feed.data == null)
              SliverFillRemaining(child: _ErrorView(onRetry: () => ref.read(homeFeedProvider.notifier).refresh()))
            else if (feed.data != null)
              ..._buildSections(feed.data!)
            else
              const SliverToBoxAdapter(child: SizedBox.shrink()),
            if (feed.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE53935),
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Row(
        children: [
          Icon(Icons.restaurant_menu, color: Color(0xFFE53935), size: 22),
          SizedBox(width: 8),
          Text(
            'Vifosa',
            style: TextStyle(
              color: Color(0xFFE53935),
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black87),
          onPressed: () {}, // TODO: navigate to search
        ),
      ],
    );
  }

  SliverToBoxAdapter _buildRadiusSelector(int current) {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, size: 16, color: Colors.black54),
            const SizedBox(width: 4),
            const Text('Bán kính:', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(width: 8),
            ...[5, 10, 25].map((r) => _RadiusChip(
              radius: r,
              selected: current == r,
              onTap: () => ref.read(homeFeedRadiusProvider.notifier).state = r,
            )),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSections(HomeFeedData data) {
    return [
      if (data.newStores.isNotEmpty)
        _HorizontalSection(title: '🆕 Quán mới', stores: data.newStores),
      if (data.trendingStores.isNotEmpty)
        _HorizontalSection(title: '🔥 Bán chạy', stores: data.trendingStores),
      if (data.recentPurchases.isNotEmpty)
        _HorizontalSection(title: '🛍 Đã mua gần đây', stores: data.recentPurchases),
      if (data.favorites.isNotEmpty)
        _HorizontalSection(title: '❤️ Yêu thích', stores: data.favorites),
      if (data.nearbyStores.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text(
              'Gần đây',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => StoreCardVertical(store: data.nearbyStores[i]),
            childCount: data.nearbyStores.length,
          ),
        ),
      ],
      if (data.newStores.isEmpty &&
          data.trendingStores.isEmpty &&
          data.nearbyStores.isEmpty)
        const SliverFillRemaining(child: _EmptyFeed()),
    ];
  }
}

// ── Radius chip ───────────────────────────────────────────────────────────────

class _RadiusChip extends StatelessWidget {
  final int radius;
  final bool selected;
  final VoidCallback onTap;

  const _RadiusChip({
    required this.radius,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? const Color(0xFFE53935) : const Color(0xFFF0F0F0),
        ),
        child: Text(
          '${radius}km',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}

// ── Horizontal scroll section ─────────────────────────────────────────────────

class _HorizontalSection extends StatelessWidget {
  final String title;
  final List<StoreCard> stores;

  const _HorizontalSection({required this.title, required this.stores});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: stores.length,
              itemBuilder: (_, i) => StoreCardHorizontal(store: stores[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store_mall_directory_outlined, size: 64, color: Colors.black26),
          SizedBox(height: 12),
          Text('Không có quán nào trong khu vực này.',
              style: TextStyle(color: Colors.black45)),
          SizedBox(height: 4),
          Text('Thử mở rộng bán kính tìm kiếm.',
              style: TextStyle(fontSize: 12, color: Colors.black38)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_outlined, size: 64, color: Colors.black26),
          const SizedBox(height: 12),
          const Text('Không tải được dữ liệu.'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

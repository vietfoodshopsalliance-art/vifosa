// lib/features/search/screens/search_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/store.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/store_card.dart';

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  // Mỗi phần tử: { store: Map, matchedItems: List }
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (value.trim() != _query) {
        _query = value.trim();
        if (_query.isNotEmpty) {
          _doSearch(_query);
        } else {
          setState(() { _results = []; _hasSearched = false; });
        }
      }
    });
  }

  Future<void> _doSearch(String q) async {
    setState(() => _loading = true);
    try {
      final res = await DioClient.instance.get(
        ApiEndpoints.search,
        queryParameters: {'q': q},
      );
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _results = List<Map<String, dynamic>>.from(data['stores'] ?? []);
        _hasSearched = true;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() => _hasSearched = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go('/home'),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Tìm cửa hàng, món ăn...',
            border: InputBorder.none,
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() { _results = []; _hasSearched = false; _query = ''; });
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (!_hasSearched) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('Nhập tên cửa hàng hoặc món ăn để tìm kiếm',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sentiment_dissatisfied, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Không tìm thấy kết quả cho "$_query"',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final result = _results[i];
        final storeMap = result['store'] as Map<String, dynamic>? ?? {};
        final matchedItems = List<Map<String, dynamic>>.from(result['matchedItems'] ?? []);
        final storeId = storeMap['_id'] as String? ?? storeMap['id'] as String? ?? '';
        if (storeId.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StoreCard(
              store: Store.fromJson(storeMap),
              onTap: () => context.push('/store/$storeId'),
            ),
            if (matchedItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: matchedItems.map((item) => _MatchedItemRow(item: item)).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MatchedItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MatchedItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final name  = item['name'] as String? ?? '';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.restaurant_menu, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
          Text(_vnd.format(price),
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// lib/features/search/screens/search_screen.dart
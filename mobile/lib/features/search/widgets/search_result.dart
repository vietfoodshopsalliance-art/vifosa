// lib/features/search/widgets/search_result.dart

import '../../../core/models/store.dart';
import '../../../core/models/menu_item.dart';

class SearchResult {
  final List<Store> stores;
  final List<MenuItem> menuItems;

  const SearchResult({
    required this.stores,
    required this.menuItems,
  });

  factory SearchResult.empty() =>
      const SearchResult(stores: [], menuItems: []);

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        stores: (json['stores'] as List<dynamic>? ?? [])
            .map((e) => Store.fromJson(e as Map<String, dynamic>))
            .toList(),
        menuItems: (json['menuItems'] as List<dynamic>? ?? [])
            .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get isEmpty => stores.isEmpty && menuItems.isEmpty;
}

// lib/features/search/widgets/search_result.dart
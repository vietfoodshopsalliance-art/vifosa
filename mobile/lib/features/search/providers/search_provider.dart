// lib/features/search/providers/search_provider.dart
// Quản lý state Search: query, sort, period, radius, kết quả, recent searches

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_service.dart';
import '../../home/providers/home_feed_provider.dart'
    show StoreCardModel, StoreStatus, StoreAddress, StoreStats;

// ── Models ─────────────────────────────────────────────────────────

class MatchedItem {
  final String id;
  final String name;
  final int price;
  final String? image;

  const MatchedItem({
    required this.id,
    required this.name,
    required this.price,
    this.image,
  });

  factory MatchedItem.fromJson(Map<String, dynamic> j) => MatchedItem(
        id: j['_id'] as String,
        name: j['name'] as String,
        price: (j['price'] as num).toInt(),
        image: j['image'] as String?,
      );
}

class SearchResultItem {
  final StoreCardModel store;
  final List<MatchedItem> matchedItems;

  const SearchResultItem({
    required this.store,
    required this.matchedItems,
  });

  factory SearchResultItem.fromJson(Map<String, dynamic> j) =>
      SearchResultItem(
        store: StoreCardModel.fromJson(
            j['store'] as Map<String, dynamic>),
        matchedItems: (j['matchedItems'] as List? ?? [])
            .map((e) => MatchedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── Enums ──────────────────────────────────────────────────────────

enum SearchSort { rating, distance, name, popular }
enum SearchPeriod { alltime, d7, d30, d365 }

extension SearchSortExt on SearchSort {
  String get apiValue {
    switch (this) {
      case SearchSort.rating:
        return 'rating';
      case SearchSort.distance:
        return 'distance';
      case SearchSort.name:
        return 'name';
      case SearchSort.popular:
        return 'popular';
    }
  }
}

extension SearchPeriodExt on SearchPeriod {
  String get apiValue {
    switch (this) {
      case SearchPeriod.alltime:
        return 'alltime';
      case SearchPeriod.d7:
        return '7d';
      case SearchPeriod.d30:
        return '30d';
      case SearchPeriod.d365:
        return '365d';
    }
  }
}

// ── State ──────────────────────────────────────────────────────────

class SearchState {
  final String query;
  final List<SearchResultItem> results;
  final int total;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final String? error;
  final SearchSort sort;
  final SearchPeriod period;
  final double? radiusKm;
  final List<String> recentSearches; // lưu local, max 10

  const SearchState({
    this.query = '',
    this.results = const [],
    this.total = 0,
    this.page = 1,
    this.hasMore = false,
    this.isLoading = false,
    this.error,
    this.sort = SearchSort.rating,
    this.period = SearchPeriod.d30,
    this.radiusKm,
    this.recentSearches = const [],
  });

  SearchState copyWith({
    String? query,
    List<SearchResultItem>? results,
    int? total,
    int? page,
    bool? hasMore,
    bool? isLoading,
    String? error,
    SearchSort? sort,
    SearchPeriod? period,
    double? radiusKm,
    List<String>? recentSearches,
    bool clearError = false,
  }) =>
      SearchState(
        query: query ?? this.query,
        results: results ?? this.results,
        total: total ?? this.total,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        sort: sort ?? this.sort,
        period: period ?? this.period,
        radiusKm: radiusKm ?? this.radiusKm,
        recentSearches: recentSearches ?? this.recentSearches,
      );
}

// ── Notifier ───────────────────────────────────────────────────────

class SearchNotifier extends StateNotifier<SearchState> {
  final ApiService _api;
  Timer? _debounce;

  // GPS coords (thay bằng LocationService thật)
  final double _lat = 10.762622;
  final double _lng = 106.660172;

  static const _recentKey = 'recent_searches';
  static const _maxRecent = 10;

  SearchNotifier(this._api) : super(const SearchState()) {
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // Gọi khi text field thay đổi — không tự search ngay
  void onQueryChanged(String q) {
    state = state.copyWith(query: q, clearError: true);
  }

  void clearQuery() {
    state = state.copyWith(
      query: '',
      results: [],
      total: 0,
      hasMore: false,
      clearError: true,
    );
  }

  // Gọi khi user submit (enter / tap chip)
  Future<void> search(String query, {bool resetPage = true}) async {
    if (query.trim().isEmpty) return;
    state = state.copyWith(
      query: query,
      isLoading: true,
      clearError: true,
      results: resetPage ? [] : state.results,
      page: resetPage ? 1 : state.page,
    );

    try {
      // FIX: đổi queryParams: thay vì query: để khớp với ApiService
      final data = await _api.get('/search', queryParams: {
        'q': query,
        'lat': _lat.toString(),
        'lng': _lng.toString(),
        if (state.radiusKm != null)
          'radius': state.radiusKm!.toInt().toString(),
        'sort': state.sort.apiValue,
        'period': state.period.apiValue,
        'page': (resetPage ? 1 : state.page).toString(),
        'limit': '20',
      });

      final results = (data['stores'] as List? ?? [])
          .map((e) =>
              SearchResultItem.fromJson(e as Map<String, dynamic>))
          .toList();

      final allResults =
          resetPage ? results : [...state.results, ...results];

      state = state.copyWith(
        results: allResults,
        total: data['total'] as int? ?? 0,
        page: (resetPage ? 1 : state.page) + 1,
        hasMore: data['hasMore'] as bool? ?? false,
        isLoading: false,
      );

      // Lưu vào recent searches
      await _addRecentSearch(query);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tìm kiếm. Vui lòng thử lại.',
      );
    }
  }

  Future<void> loadMore() {
    if (state.isLoading || !state.hasMore) return Future.value();
    return search(state.query, resetPage: false);
  }

  void setSort(SearchSort sort) {
    state = state.copyWith(sort: sort);
    if (state.query.isNotEmpty) search(state.query);
  }

  void setPeriod(SearchPeriod period) {
    state = state.copyWith(period: period);
    if (state.query.isNotEmpty) search(state.query);
  }

  void setRadius(double? km) {
    state = state.copyWith(radiusKm: km);
    if (state.query.isNotEmpty) search(state.query);
  }

  // ── Recent searches (SharedPreferences) ────────────────────────

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentKey) ?? [];
    state = state.copyWith(recentSearches: list);
  }

  Future<void> _addRecentSearch(String query) async {
    final current = List<String>.from(state.recentSearches);
    current.remove(query); // dedup
    current.insert(0, query);
    if (current.length > _maxRecent) current.removeLast();

    state = state.copyWith(recentSearches: current);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, current);
  }

  Future<void> removeRecentSearch(String query) async {
    final current = List<String>.from(state.recentSearches)..remove(query);
    state = state.copyWith(recentSearches: current);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, current);
  }

  Future<void> clearRecentSearches() async {
    state = state.copyWith(recentSearches: []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
  }
}

// ── Provider ───────────────────────────────────────────────────────

final searchProvider =
    StateNotifierProvider.autoDispose<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.read(apiServiceProvider));
});
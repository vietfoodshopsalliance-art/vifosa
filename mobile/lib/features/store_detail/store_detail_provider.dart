// lib/features/store_detail/store_detail_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/store.dart';
import '../../core/models/category.dart';
import '../../core/models/review.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_endpoints.dart';

// ---------------------------------------------------------------------------
// Store detail — trả Store model (dùng bởi menu_tab, widgets, v.v.)
// ---------------------------------------------------------------------------
final storeDetailProvider =
    FutureProvider.autoDispose.family<Store, String>((ref, storeId) async {
  final res = await DioClient.instance.get(ApiEndpoints.storeDetail(storeId));
  return Store.fromJson(res.data as Map<String, dynamic>);
});

// ---------------------------------------------------------------------------
// Store menu — gom items theo categoryId từ API {categories,items} riêng
// ---------------------------------------------------------------------------
final storeMenuProvider =
    FutureProvider.autoDispose.family<List<Category>, String>((ref, storeId) async {
  final res = await DioClient.instance.get(ApiEndpoints.storeMenu(storeId));
  final cats  = List<Map<String, dynamic>>.from(res.data['categories'] ?? []);
  final items = List<Map<String, dynamic>>.from(res.data['items']      ?? []);
  final byCategory = <String, List<Map<String, dynamic>>>{};
  for (final item in items) {
    final cid = (item['categoryId'] ?? '').toString();
    byCategory.putIfAbsent(cid, () => []).add(item);
  }
  return cats.map((cat) {
    final cid = (cat['_id'] ?? cat['id'] ?? '').toString();
    return Category.fromJson({...cat, 'items': byCategory[cid] ?? <Map<String, dynamic>>[]});
  }).toList();
});

// ---------------------------------------------------------------------------
// Like store toggle
// ---------------------------------------------------------------------------
final storeLikeProvider =
    StateNotifierProvider.family<StoreLikeNotifier, AsyncValue<bool>, String>(
        (ref, storeId) {
  // Lấy initialValue từ storeDetail khi đã load
  final detail = ref.watch(storeDetailProvider(storeId));
  return StoreLikeNotifier(
    storeId: storeId,
    initial: detail.valueOrNull?.likeId != null,
  );
});

class StoreLikeNotifier extends StateNotifier<AsyncValue<bool>> {
  final String storeId;
  String? _likeId;

  StoreLikeNotifier({required this.storeId, required bool initial})
      : super(AsyncValue.data(initial));

  Future<void> toggle() async {
    final current = state.valueOrNull ?? false;
    state = const AsyncValue.loading();
    try {
      if (!current) {
        final res = await DioClient.instance.post(
          ApiEndpoints.likes,
          data: {'type': 'store', 'targetId': storeId},
        );
        _likeId = res.data['id']?.toString();
        state = const AsyncValue.data(true);
      } else {
        if (_likeId != null) {
          await DioClient.instance.delete(ApiEndpoints.likeDelete(_likeId!));
        }
        state = const AsyncValue.data(false);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ---------------------------------------------------------------------------
// Reviews
// ---------------------------------------------------------------------------
class ReviewsState {
  final List<Review> reviews;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final int? ratingFilter; // null = all
  final String? error;

  const ReviewsState({
    this.reviews = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.ratingFilter,
    this.error,
  });

  ReviewsState copyWith({
    List<Review>? reviews,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    int? ratingFilter,
    bool clearRatingFilter = false,
    String? error,
  }) {
    return ReviewsState(
      reviews: reviews ?? this.reviews,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      ratingFilter: clearRatingFilter ? null : (ratingFilter ?? this.ratingFilter),
      error: error,
    );
  }
}

class ReviewsNotifier extends StateNotifier<ReviewsState> {
  final String storeId;

  ReviewsNotifier(this.storeId) : super(const ReviewsState()) {
    fetchFirstPage();
  }

  Future<void> fetchFirstPage({int? rating}) async {
    state = ReviewsState(
      ratingFilter: rating,
      isLoading: true,
    );
    await _fetch(page: 1);
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    await _fetch(page: state.currentPage + 1);
  }

  Future<void> _fetch({required int page}) async {
    try {
      final res = await DioClient.instance.get(
        ApiEndpoints.storeReviews(storeId),
        queryParameters: {
          if (state.ratingFilter != null) 'rating': state.ratingFilter,
          'page': page,
          'limit': 20,
        },
      );
      final newList = (res.data['reviews'] as List)
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList();
      final hasMore = newList.length == 20;
      final merged = page == 1 ? newList : [...state.reviews, ...newList];
      state = state.copyWith(
        reviews: merged,
        isLoading: false,
        hasMore: hasMore,
        currentPage: page,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final storeReviewsProvider = StateNotifierProvider.family<ReviewsNotifier,
    ReviewsState, String>(
  (ref, storeId) => ReviewsNotifier(storeId),
);
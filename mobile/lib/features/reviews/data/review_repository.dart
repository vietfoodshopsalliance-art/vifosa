// mobile/lib/features/reviews/data/review_repository.dart

import 'package:dio/dio.dart';
import 'review_model.dart';

class ReviewRepository {
  final Dio dio;
  ReviewRepository(this.dio);

  // ── Tạo review ─────────────────────────────────────────────────────────
  Future<Review> createReview({
    required String orderId,
    required String toEntityType,
    required int stars,
    String comment = '',
    List<String> images = const [],
    bool isAnonymous = false,
  }) async {
    final res = await dio.post('/reviews', data: {
      'orderId': orderId,
      'toEntityType': toEntityType,
      'stars': stars,
      'comment': comment,
      'images': images,
      'isAnonymous': isAnonymous,
    });
    return Review.fromJson(res.data);
  }

  // ── Sửa review ─────────────────────────────────────────────────────────
  Future<Review> editReview(
    String reviewId, {
    int? stars,
    String? comment,
    List<String>? images,
    bool? isAnonymous,
  }) async {
    final res = await dio.patch('/reviews/$reviewId', data: {
      if (stars != null) 'stars': stars,
      if (comment != null) 'comment': comment,
      if (images != null) 'images': images,
      if (isAnonymous != null) 'isAnonymous': isAnonymous,
    });
    return Review.fromJson(res.data);
  }

  // ── Xoá review ─────────────────────────────────────────────────────────
  Future<void> deleteReview(String reviewId) async {
    await dio.delete('/reviews/$reviewId');
  }

  // ── Phản hồi quán ──────────────────────────────────────────────────────
  Future<Review> createReply(String reviewId, String text) async {
    final res = await dio.post('/reviews/$reviewId/reply', data: {'text': text});
    return Review.fromJson(res.data);
  }

  Future<Review> editReply(String reviewId, String text) async {
    final res = await dio.patch('/reviews/$reviewId/reply', data: {'text': text});
    return Review.fromJson(res.data);
  }

  // ── Đọc reviews ────────────────────────────────────────────────────────
  Future<StoreReviewsResult> getStoreReviews(
    String storeId, {
    int page = 1,
    String sort = 'newest',
  }) async {
    final res = await dio.get(
      '/stores/$storeId/reviews',
      queryParameters: {'page': page, 'sort': sort},
    );
    return StoreReviewsResult.fromJson(res.data);
  }

  Future<List<Review>> getOrderReviews(String orderId) async {
    final res = await dio.get('/orders/$orderId/reviews');
    return (res.data as List).map((e) => Review.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getMyReviews({int page = 1}) async {
    final res = await dio.get('/me/reviews', queryParameters: {'page': page});
    return res.data;
  }

  Future<List<dynamic>> getPendingReviews() async {
    final res = await dio.get('/me/reviews/pending');
    return res.data as List;
  }
}
// lib/features/reviews/data/review_repository.dart

import 'package:dio/dio.dart';
import '../../../core/models/review.dart';
import '../../../core/network/api_endpoints.dart';
import 'review_model.dart';

class ReviewRepository {
  final Dio dio;
  ReviewRepository(this.dio);

  // ── Khách tạo review cho quán ─────────────────────────────────────────────
  Future<void> createReview({
    required String orderId,
    required int stars,
    String comment = '',
    List<String> images = const [],
    bool isAnonymous = false,
  }) async {
    await dio.post(
      ApiEndpoints.orderReview(orderId),
      data: {
        'stars': stars,
        'comment': comment,
        'images': images,
        'isAnonymous': isAnonymous,
      },
    );
  }

  // ── Chủ quán tạo review cho khách ────────────────────────────────────────
  Future<void> createCustomerReview({
    required String orderId,
    required int stars,
    String comment = '',
    List<String> images = const [],
    bool isAnonymous = false,
  }) async {
    await dio.post(
      ApiEndpoints.orderCustomerReview(orderId),
      data: {
        'stars': stars,
        'comment': comment,
        'images': images,
        'isAnonymous': isAnonymous,
      },
    );
  }

  // ── Khách phản hồi đánh giá của chủ quán ─────────────────────────────────
  Future<void> replyToReceivedReview({
    required String reviewId,
    required String text,
  }) async {
    await dio.patch(
      ApiEndpoints.customerReviewReply(reviewId),
      data: {'text': text},
    );
  }

  // ── Sửa review (PATCH /reviews/:id) ──────────────────────────────────────
  Future<MyReview> editReview(
    String reviewId, {
    int? stars,
    String? comment,
    List<String>? images,
    bool? isAnonymous,
  }) async {
    final res = await dio.patch(
      ApiEndpoints.reviewById(reviewId),
      data: {
        if (stars != null) 'stars': stars,
        if (comment != null) 'comment': comment,
        if (images != null) 'images': images,
        if (isAnonymous != null) 'isAnonymous': isAnonymous,
      },
    );
    return MyReview.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Xoá review ────────────────────────────────────────────────────────────
  Future<void> deleteReview(String reviewId) async {
    await dio.delete(ApiEndpoints.reviewById(reviewId));
  }

  // ── Reviews của quán (GET /stores/:id/reviews) ────────────────────────────
  Future<List<Review>> getStoreReviews(
    String storeId, {
    int page = 1,
    int? rating,
  }) async {
    final res = await dio.get(
      ApiEndpoints.storeReviews(storeId),
      queryParameters: {
        'page': page,
        if (rating != null) 'rating': rating,
      },
    );
    return (res.data['reviews'] as List)
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Reviews tôi đã viết cho quán (GET /me/reviews-given) ─────────────────
  Future<List<MyReview>> getMyReviews({int page = 1}) async {
    final res = await dio.get(
      ApiEndpoints.myReviews,
      queryParameters: {'page': page},
    );
    return (res.data['reviews'] as List)
        .map((e) => MyReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Reviews nhận về từ quán (GET /me/reviews) ────────────────────────────
  Future<({List<ReceivedReview> reviews, double? avgStars, int total})>
      getMyReviewsReceived({int page = 1}) async {
    final res = await dio.get(
      ApiEndpoints.myReviewsReceived,
      queryParameters: {'page': page},
    );
    final data = res.data as Map<String, dynamic>;
    final list = (data['reviews'] as List)
        .map((e) => ReceivedReview.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      reviews: list,
      avgStars: (data['avgStars'] as num?)?.toDouble(),
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Cả 2 review của 1 order (GET /orders/:id/reviews) ────────────────────
  Future<Map<String, dynamic>> getOrderReviews(String orderId) async {
    final res = await dio.get(ApiEndpoints.orderReviews(orderId));
    return res.data as Map<String, dynamic>;
  }
}

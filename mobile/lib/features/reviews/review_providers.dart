// lib/features/reviews/review_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import 'data/review_repository.dart';
import 'data/review_model.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(dioClientProvider).dio);
});

final myReviewsProvider = FutureProvider<List<MyReview>>((ref) {
  return ref.watch(reviewRepositoryProvider).getMyReviews();
});

final myReviewsReceivedProvider = FutureProvider<
    ({List<ReceivedReview> reviews, double? avgStars, int total})>((ref) {
  return ref.watch(reviewRepositoryProvider).getMyReviewsReceived();
});

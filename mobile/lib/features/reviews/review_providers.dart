// mobile/lib/features/reviews/review_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/review_repository.dart';
import 'data/review_model.dart';

// Giả sử dioProvider đã được khai báo ở core/providers
// import '../../core/providers.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  // final dio = ref.watch(dioProvider);
  // return ReviewRepository(dio);
  throw UnimplementedError('Inject dioProvider');
});

// ── Store reviews (paginated) ───────────────────────────────────────────────
final storeReviewsProvider = FutureProvider.family<StoreReviewsResult, String>((ref, storeId) async {
  return ref.watch(reviewRepositoryProvider).getStoreReviews(storeId);
});

// ── Pending reviews cho current user ──────────────────────────────────────
final pendingReviewsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.watch(reviewRepositoryProvider).getPendingReviews();
});

// ── My reviews ────────────────────────────────────────────────────────────
final myReviewsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(reviewRepositoryProvider).getMyReviews();
});
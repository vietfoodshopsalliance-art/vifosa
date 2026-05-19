// mobile/lib/core/constants/api_endpoints.dart

class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const login      = '/api/auth/login';
  static const register   = '/api/auth/register';
  static const refresh    = '/api/auth/refresh';
  static const logout     = '/api/auth/logout';

  // ── Me ────────────────────────────────────────────────────────────────────
  static const me         = '/api/me';
  static const fcmToken   = '/api/me/fcm-token';
  static const password   = '/api/me/password';

  // ── Home / Search ─────────────────────────────────────────────────────────
  static const stores     = '/api/v1/stores';
  static const search     = '/api/v1/search';

  // ── Cart / Orders ─────────────────────────────────────────────────────────
  static const cart       = '/api/cart';
  static const orders     = '/api/orders';

  // ── Social ────────────────────────────────────────────────────────────────
  static const posts      = '/api/posts';
  static const likes      = '/api/likes';
  static const favorites  = '/api/favorites';

  // ── Misc ──────────────────────────────────────────────────────────────────
  static const notifications     = '/api/notifications';
  static const supportTickets    = '/api/support-tickets';
  static const uploads           = '/api/uploads';

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String store(String id)        => '/api/stores/$id';
  static String storeMenu(String id)    => '/api/stores/$id/menu';
  static String order(String id)        => '/api/orders/$id';
  static String postComments(String id) => '/api/posts/$id/comments';
  static String storeReviews(String id) => '/api/stores/$id/reviews';
}
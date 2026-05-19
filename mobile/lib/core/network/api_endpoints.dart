// lib/core/network/api_endpoints.dart
// Spec v3.1 — tất cả route KHÔNG có prefix /api
// Backend Fastify mount thẳng tại root, ví dụ: POST /auth/login

class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth ──────────────────────────────────────────────
  static const String register     = '/auth/register';
  static const String login        = '/auth/login';
  static const String refresh      = '/auth/refresh';
  static const String logout       = '/auth/logout';
  static const String tosAccept    = '/tos/accept';

  // ── Me (profile của user hiện tại) ───────────────────
  static const String me               = '/me';
  static const String fcmToken         = '/me/fcm-token';
  static const String myProfile        = '/me/profile';
  static const String myPassword       = '/me/password';
  static const String myAddresses      = '/me/addresses';
  static String myAddressById(String id)  => '/me/addresses/$id';
  static const String myNotifPrefs     = '/me/notification-prefs';
  static const String myStores         = '/me/stores';
  static const String changePassword   = '/me/password';

  // ── Stores ────────────────────────────────────────────
  static const String stores                              = '/stores';
  static String storeDetail(String id)                    => '/stores/$id';
  static String storeSettings(String id) => '/stores/$id';
  static String storeMenu(String id)                      => '/stores/$id/menu';
  static String storeCategories(String id)                => '/stores/$id/categories';
  static String storeCategoryById(String sid, String cid) => '/stores/$sid/categories/$cid';
  static String storeItems(String id)                     => '/stores/$id/items';
  static String storeItemById(String sid, String iid)     => '/stores/$sid/items/$iid';
  static String storeItemStatus(String sid, String iid) => '/stores/$sid/items/$iid/status';
  static String storeOrders(String id) => '/store/$id/orders';
  static String storeShipFee(String id) => '/stores/$id/ship-fee';
  static String storeReviews(String id)                   => '/stores/$id/reviews';
  static String storeReviewReply(String sid, String rid)  => '/stores/$sid/reviews/$rid/reply';
  static String storeEmergencyClose(String id)            => '/stores/$id/emergency-close';
  static String storeAvatar(String id)                    => '/stores/$id/avatar';
  static String storeCover(String id)                     => '/stores/$id/cover';
  static String storeDashboardStats(String id)            => '/stores/$id/dashboard/stats';

  // Aliases dùng trong store_menu.dart
  static String categories(String storeId) => '/stores/$storeId/categories';
  static String items(String storeId)      => '/stores/$storeId/items';
  static String storeById(String id)       => '/stores/$id';
  static String deleteStore(String id) => '/stores/$id';
  static String storeStaff(String id) => '/stores/$id/staff';
  static String storeStaffMember(String storeId, String userId) => '/stores/$storeId/staff/$userId';
  static String transferStore(String id) => '/stores/$id/transfer';

  // ── Orders (khách) ────────────────────────────────────
  static const String orders                         = '/orders';
  static String orderDetail(String id)               => '/orders/$id';
  static String confirmPayment(String id)            => '/orders/$id/report-paid';
  static String confirmReceived(String id)           => '/orders/$id/confirm-received';
  static String cancelOrder(String id)               => '/orders/$id/cancel';
  static String orderReview(String id)               => '/orders/$id/review';
  static const String ordersTrack                    = '/orders/track';

  // ── Orders (quán side) — POST /orders/:id/... ─────────
  static String storeAcceptOrder(String oid)              => '/orders/$oid/accept';
  static String storeRejectOrder(String oid)              => '/orders/$oid/reject';
  static String storeHandoverOrder(String oid)            => '/orders/$oid/handover';
  static String storeCompleteDelivery(String oid)         => '/orders/$oid/complete-delivery';
  static String storeConfirmMoney(String oid)             => '/orders/$oid/confirm-money-received';
  static String storeReportPaymentNotReceived(String oid) => '/orders/$oid/report-payment-not-received';
  static String storeReturnOrder(String oid)              => '/orders/$oid/return-to-pending';
  static String setBankReceipt(String oid)                => '/orders/$oid/set-bank-receipt';

  // ── Cart ──────────────────────────────────────────────
  static const String cart          = '/cart';
  static String cartItem(String id) => '/cart/$id';

  // ── Search ────────────────────────────────────────────
  static const String search        = '/search';

  // ── Home feed ─────────────────────────────────────────
  static const String homeFeed      = '/home-feed';

  // ── Likes / Favorites ─────────────────────────────────
  static const String likes          = '/likes';
  static const String favorites      = '/likes';
  static const String favoriteStores = '/me/favorites/stores';
  static const String favoriteItems  = '/me/favorites/items';
  static String likeDelete(String id) => '/likes/$id';

  // ── Reviews ───────────────────────────────────────────
  static const String reviews           = '/reviews';
  static String reviewById(String id)   => '/reviews/$id';
  static String reviewReply(String id)  => '/reviews/$id/reply';

  // ── Notifications ─────────────────────────────────────
  static const String notifications     = '/notifications';
  static String notifRead(String id)    => '/notifications/$id/read';

  // ── Social — Posts ────────────────────────────────────
  static const String posts                                    = '/posts';
  static String postDetail(String id)                          => '/posts/$id';
  static String postLike(String id)                            => '/posts/$id/like';
  static String postComments(String id)                        => '/posts/$id/comments';
  static String blockCommenter(String postId)                  => '/posts/$postId/block-commenter';
  static String commentLike(String postId, String commentId)   => '/posts/$postId/comments/$commentId/like';

  // ── Support ───────────────────────────────────────────
  static const String supportTickets   = '/support';

  // ── Reports ───────────────────────────────────────────
  static const String reports          = '/reports';

  // ── Uploads ───────────────────────────────────────────
  static const String uploads          = '/uploads';

  // ── Notification preferences ─────────────────────────
  static const String notificationPreferences = '/me/notification-prefs';

  // ── Emergency close alias ─────────────────────────────
  static String emergencyClose(String storeId) => storeEmergencyClose(storeId);

  // ── Me addresses alias (dùng trong checkout_provider) ─
  static const String meAddresses = '/me/addresses';
  // Aliases dùng trong store_dashboard_screen.dart (redirect về đúng endpoint)
  static String orderPaymentNotReceived(String sid, String oid) => storeReportPaymentNotReceived(oid);
  static String orderConfirmPayment(String sid, String oid)     => storeConfirmMoney(oid);

  }
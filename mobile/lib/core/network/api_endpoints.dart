// lib/core/network/api_endpoints.dart
// Spec v3.1 — tất cả route KHÔNG có prefix /api
// Backend Fastify mount thẳng tại root, ví dụ: POST /auth/login

class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String register       = '/auth/register';
  static const String login          = '/auth/login';
  static const String refresh        = '/auth/refresh';
  static const String logout         = '/auth/logout';
  static const String logoutAll      = '/auth/logout-all';
  static const String changePassword = '/auth/change-password';
  static const String tosAccept      = '/tos/accept';

  // ── Me ────────────────────────────────────────────────────────────────────
  static const String me                  = '/me';
  static const String meAvatar            = '/me/avatar';
  static const String fcmToken            = '/me/fcm-token';
  static const String myAddresses         = '/me/addresses';
  static String myAddressById(String id)        => '/me/addresses/$id';
  static String myAddressDefault(String id)     => '/me/addresses/$id/default';
  static const String myNotifPrefs        = '/me/notification-prefs';
  static const String myBankAccount       = '/me/bank-account';
  static const String myStores            = '/me/stores';
  static const String myStoreMemberships  = '/me/store-memberships';
  static const String myReviews           = '/me/reviews';
  static const String myReviewsPending    = '/me/reviews/pending';

  // ── Stores ────────────────────────────────────────────────────────────────
  static const String stores                               = '/stores';
  static String storeById(String id)                      => '/stores/$id';
  static String storeDetail(String id)                    => '/stores/$id';
  static String storeMenu(String id)                      => '/stores/$id/menu';
  static String storeCategories(String id)                => '/stores/$id/categories';
  static String storeCategoryById(String sid, String cid) => '/stores/$sid/categories/$cid';
  static String storeCategoryReorder(String id)           => '/stores/$id/categories/reorder';
  static String storeItems(String id)                     => '/stores/$id/items';
  static String storeItemById(String sid, String iid)     => '/stores/$sid/items/$iid';
  static String storeItemStock(String sid, String iid)    => '/stores/$sid/items/$iid/stock';
  static String storeItemStatus(String sid, String iid)   => '/stores/$sid/items/$iid/status';
  static String storeItemImages(String sid, String iid)   => '/stores/$sid/items/$iid/images';
  static String storeItemImageByIndex(String sid, String iid, int idx) =>
      '/stores/$sid/items/$iid/images/$idx';
  static String storeOrders(String id)                    => '/stores/$id/orders';
  static String storeInternalOrders(String id)            => '/stores/$id/orders/internal';
  static String storeShipFee(String id)                   => '/stores/$id/ship-fee';
  static String storeReviews(String id)                   => '/stores/$id/reviews';
  static String storeAvatar(String id)                    => '/stores/$id/avatar';
  static String storeCover(String id)                     => '/stores/$id/cover';
  static String storeTransfer(String id)                  => '/stores/$id/transfer';
  static String storeDashboardStats(String id)            => '/me/stores/$id/stats';
  static String storeSettingsBankAccount(String id)       => '/stores/$id/settings/bank-account';
  static String storeSettingsPaymentMethods(String id)    => '/stores/$id/settings/payment-methods';
  static String storeSettingsEmergencyClose(String id)    => '/stores/$id/settings/emergency-close';

  // ── Store (owner) endpoints ───────────────────────────────────────────────
  static String myStoreById(String id)             => '/me/stores/$id';
  static String myStoreOrders(String id)           => '/me/stores/$id/orders';
  static String myStoreEmergencyClose(String id)   => '/me/stores/$id/emergency-close';

  // ── Store Memberships ─────────────────────────────────────────────────────
  static String storeMembers(String id)                         => '/stores/$id/members';
  static String storeMemberInvite(String id)                    => '/stores/$id/members/invite';
  static String storeMemberById(String sid, String uid)         => '/stores/$sid/members/$uid';
  static String storeMemberPermissions(String sid, String uid)  => '/stores/$sid/members/$uid/permissions';
  static String storeInvitationAccept(String id)                => '/store-invitations/$id/accept';
  static String storeInvitationDecline(String id)               => '/store-invitations/$id/decline';

  // ── Inventory ─────────────────────────────────────────────────────────────
  static String storeInventoryLogs(String id)   => '/stores/$id/inventory/logs';
  static String storeInventoryImport(String id) => '/stores/$id/inventory/import';
  static String storeInventoryAdjust(String id) => '/stores/$id/inventory/adjust';

  // ── Transfer Orders ───────────────────────────────────────────────────────
  static String storeTransfers(String id)  => '/stores/$id/transfers';
  static String transferConfirm(String id) => '/transfers/$id/confirm';
  static String transferCancel(String id)  => '/transfers/$id/cancel';

  // ── Cart ──────────────────────────────────────────────────────────────────
  static const String cart          = '/me/cart';
  static const String cartItems     = '/me/cart/items';
  static String cartItemById(String id) => '/me/cart/items/$id';

  // ── Orders (khách) ────────────────────────────────────────────────────────
  static const String orders                     = '/orders';
  static const String myOrders                   = '/me/orders';
  static const String ordersTrack                = '/orders/track';
  static String orderDetail(String id)           => '/orders/$id';
  static String orderReportPaid(String id)       => '/orders/$id/report-paid';
  static String orderCancel(String id)           => '/orders/$id/cancel';
  static String orderConfirmReceived(String id)  => '/orders/$id/confirm-received';
  static String orderReview(String id)           => '/orders/$id/review';
  static String orderReviews(String id)          => '/orders/$id/reviews';
  static String orderPaymentUpload(String id)    => '/orders/$id/payment/upload-receipt';
  static String orderRefundBankInfo(String id)   => '/orders/$id/refund/bank-info';
  static String orderRefundSubmit(String id)     => '/orders/$id/refund/submit';
  static String orderRefundConfirm(String id)    => '/orders/$id/refund/confirm';
  static String orderRefundDispute(String id)    => '/orders/$id/refund/dispute';
  static String setBankReceipt(String id)        => '/orders/$id/set-bank-receipt';

  // ── Orders (quán side) ────────────────────────────────────────────────────
  static String orderAccept(String id)            => '/orders/$id/accept';
  static String orderReject(String id)            => '/orders/$id/reject';
  static String orderDeliver(String id)           => '/orders/$id/deliver';
  static String orderComplete(String id)          => '/orders/$id/complete';
  // legacy aliases kept for compatibility
  static String orderHandover(String id)          => '/orders/$id/deliver';
  static String orderCompleteDelivery(String id)  => '/orders/$id/complete';
  static String orderConfirmMoney(String id)      => '/orders/$id/confirm-money-received';
  static String orderPaymentNotReceived(String id) => '/orders/$id/report-payment-not-received';
  static String orderReturnToPending(String id)   => '/orders/$id/return-to-pending';

  // ── Reviews ───────────────────────────────────────────────────────────────
  static const String reviews           = '/reviews';
  static String reviewById(String id)   => '/reviews/$id';
  static String reviewReply(String id)  => '/reviews/$id/reply';
  static String reviewImages(String id) => '/reviews/$id/images';

  // ── Likes / Favorites ─────────────────────────────────────────────────────
  static const String likes           = '/likes';
  static String storeLiked(String id) => '/stores/$id/liked';
  static String itemLiked(String id)  => '/items/$id/liked';
  static const String favoriteStores  = '/me/favorites/stores';
  static const String favoriteItems   = '/me/favorites/items';

  // ── Social — Posts ────────────────────────────────────────────────────────
  static const String posts                                    = '/posts';
  static String postDetail(String id)                          => '/posts/$id';
  static String postImages(String id)                          => '/posts/$id/images';
  static String postLiked(String id)                           => '/posts/$id/liked';
  static String postComments(String id)                        => '/posts/$id/comments';
  static String postCommentById(String pid, String cid)        => '/posts/$pid/comments/$cid';
  static String postBlockCommenter(String pid)                 => '/posts/$pid/block-commenter';
  static String postBlockCommenterById(String pid, String uid) => '/posts/$pid/block-commenter/$uid';
  static String postDisableComments(String id)                 => '/posts/$id/disable-comments';
  static String commentLike(String pid, String cid)            => '/posts/$pid/comments/$cid/like';
  static String userPosts(String username)                     => '/users/$username/posts';

  // ── Uploads ───────────────────────────────────────────────────────────────
  static const String uploads = '/uploads';

  // ── Reports ───────────────────────────────────────────────────────────────
  static const String reports = '/reports';

  // ── Support Tickets ───────────────────────────────────────────────────────
  static const String supportTickets   = '/support/tickets';
  static const String mySupportTickets = '/me/support/tickets';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const String notifications            = '/me/notifications';
  static const String notificationsUnreadCount = '/me/notifications/unread-count';
  static const String notifReadAll             = '/me/notifications/read-all';
  static String notifRead(String id)           => '/me/notifications/$id/read';

  // ── Home feed / Search ────────────────────────────────────────────────────
  static const String homeFeed = '/home-feed';
  static const String search   = '/search';

  // ── User profile (public) ────────────────────────────────────────────────
  static String userProfile(String username) => '/users/$username';

  // ── VIP — Customer ───────────────────────────────────────────────────────
  static const String customerVipPlans        = '/vip/customer/plans';
  static const String customerVipSubscribe    = '/vip/customer/subscribe';
  static const String customerVipSubscription = '/vip/customer/my-subscription';
  static const String customerVipRenew        = '/vip/customer/renew';
  static const String customerVipCancel       = '/vip/customer/cancel';

  // ── VIP — Store ──────────────────────────────────────────────────────────
  static const String storeVipPlans              = '/vip/store/plans';
  static String storeVipSubscribe(String id)     => '/stores/$id/vip/subscribe';
  static String storeVipSubscription(String id)  => '/stores/$id/vip/subscription';
  static String storeVipRenew(String id)         => '/stores/$id/vip/renew';
  static String storeVipCancel(String id)        => '/stores/$id/vip/cancel';

  // ── Admin — Users ────────────────────────────────────────────────────────
  static const String adminUsers                           = '/admin/users';
  static String adminUserById(String id)                   => '/admin/users/$id';
  static String adminUserRoles(String id)                  => '/admin/users/$id/roles';
  static String adminUserRoleById(String uid, String role) => '/admin/users/$uid/roles/$role';
  static String adminUserStatus(String id)                 => '/admin/users/$id/status';
  static String adminUserResetPassword(String id)          => '/admin/users/$id/reset-password';
  static String adminUserLogoutAll(String id)              => '/admin/users/$id/logout-all';
  static String adminUserAuditLog(String id)               => '/admin/users/$id/audit-log';

  // ── Admin — Stores ───────────────────────────────────────────────────────
  static const String adminStores              = '/admin/stores';
  static String adminStoreById(String id)      => '/admin/stores/$id';
  static String adminStoreTransfer(String id)  => '/admin/stores/$id/transfer';
  static const String adminStoresBulk          = '/admin/stores/bulk';

  // ── Admin — Reports ──────────────────────────────────────────────────────
  static const String adminReports                    = '/admin/reports';
  static String adminReportById(String id)            => '/admin/reports/$id';
  static String adminReportHideTarget(String id)      => '/admin/reports/$id/hide-target';
  static String adminReportRestoreTarget(String id)   => '/admin/reports/$id/restore-target';

  // ── Admin — Reviews ──────────────────────────────────────────────────────
  static String adminReviewHide(String id) => '/admin/reviews/$id/hide';
  static String adminReviewShow(String id) => '/admin/reviews/$id/show';

  // ── Admin — Support Tickets ──────────────────────────────────────────────
  static const String adminSupportTickets          = '/admin/support/tickets';
  static String adminSupportTicketById(String id)  => '/admin/support/tickets/$id';

  // ── Admin — Analytics ────────────────────────────────────────────────────
  static const String adminAnalyticsOrders           = '/admin/analytics/orders';
  static const String adminAnalyticsTopStores        = '/admin/analytics/top-stores';
  static const String adminAnalyticsTopItems         = '/admin/analytics/top-items';
  static const String adminAnalyticsCancellationRate = '/admin/analytics/cancellation-rate';

  // ── Admin — Settings / VIP ───────────────────────────────────────────────
  static const String adminSettings                  = '/admin/settings';
  static const String adminSettingsVipCustomerPlans  = '/admin/settings/vip_customer_plans';
  static const String adminSettingsVipStorePlans     = '/admin/settings/vip_store_plans';
  static const String adminVipSubscriptions          = '/admin/vip/subscriptions';
  static String adminVipSubscriptionById(String id)  => '/admin/vip/subscriptions/$id';

  // ── Admin — Audit Log ────────────────────────────────────────────────────
  static const String adminAuditLog = '/admin/audit-log';
}

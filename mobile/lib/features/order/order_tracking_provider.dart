// lib/features/order/order_tracking_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_endpoints.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class OrderItem {
  final String itemId;
  final String name;
  final double price;
  final int quantity;

  const OrderItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        itemId: json['itemId'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] as int,
      );
}

class CancelInfo {
  final String reason;
  final String cancelledBy; // customer / store / system / admin
  final String at;

  const CancelInfo(
      {required this.reason, required this.cancelledBy, required this.at});

  factory CancelInfo.fromJson(Map<String, dynamic> json) => CancelInfo(
        reason: json['reason'] as String? ?? '',
        cancelledBy: json['cancelledBy'] as String? ?? '',
        at: json['at'] as String? ?? '',
      );
}

class OrderDetail {
  final String id;
  final String code;
  final String storeId;
  final String storeName;
  final String? storeImageUrl;
  final List<OrderItem> items;
  final String mainStatus;
  final String paymentStatus;
  final String? refundStatus;
  final String paymentMethod;
  final String deliveryMethod;
  final double subtotal;
  final double shipFee;
  final double total;
  final String? pendingAt; // ISO timestamp
  final CancelInfo? cancelInfo;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;
  final String? refundReceiptUrl;
  final String createdAt;
  final String? deliveredAt;

  const OrderDetail({
    required this.id,
    required this.code,
    required this.storeId,
    required this.storeName,
    this.storeImageUrl,
    required this.items,
    required this.mainStatus,
    required this.paymentStatus,
    this.refundStatus,
    required this.paymentMethod,
    required this.deliveryMethod,
    required this.subtotal,
    required this.shipFee,
    required this.total,
    this.pendingAt,
    this.cancelInfo,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountName,
    this.refundReceiptUrl,
    required this.createdAt,
    this.deliveredAt,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final store = json['store'] as Map<String, dynamic>? ?? {};
    final bank = json['bankInfo'] as Map<String, dynamic>?;
    return OrderDetail(
      id: json['_id'] as String,
      code: json['code'] as String,
      storeId: store['_id'] as String? ?? json['storeId'] as String? ?? '',
      storeName: store['name'] as String? ?? '',
      storeImageUrl: store['imageUrl'] as String?,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      mainStatus: json['mainStatus'] as String,
      paymentStatus: json['paymentStatus'] as String,
      refundStatus: json['refundStatus'] as String?,
      paymentMethod: json['paymentMethod'] as String,
      deliveryMethod: json['deliveryMethod'] as String,
      subtotal: (json['subtotal'] as num? ?? 0).toDouble(),
      shipFee: (json['shipFee'] as num? ?? 0).toDouble(),
      total: (json['total'] as num? ?? 0).toDouble(),
      pendingAt: json['pendingAt'] as String?,
      cancelInfo: json['cancelInfo'] != null
          ? CancelInfo.fromJson(json['cancelInfo'] as Map<String, dynamic>)
          : null,
      bankName: bank?['bankName'] as String?,
      bankAccountNumber: bank?['accountNumber'] as String?,
      bankAccountName: bank?['accountName'] as String?,
      refundReceiptUrl: json['refundReceiptUrl'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      deliveredAt: json['deliveredAt'] as String?,
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final orderDetailProvider =
    FutureProvider.autoDispose.family<OrderDetail, String>((ref, orderId) async {
  final res = await DioClient.instance.get('${ApiEndpoints.orders}/$orderId');
  return OrderDetail.fromJson(res.data as Map<String, dynamic>);
});

// For guest tracking with token
final guestOrderProvider = FutureProvider.autoDispose
    .family<OrderDetail, Map<String, String>>((ref, params) async {
  final code = params['code']!;
  final token = params['token'];
  final phone = params['phone'];

  String url;
  if (token != null) {
    url = '${ApiEndpoints.ordersTrack}/$code?t=$token';
  } else {
    url = '${ApiEndpoints.ordersTrack}?code=$code&phone=$phone';
  }
  final res = await DioClient.instance.get(url);
  return OrderDetail.fromJson(res.data as Map<String, dynamic>);
});

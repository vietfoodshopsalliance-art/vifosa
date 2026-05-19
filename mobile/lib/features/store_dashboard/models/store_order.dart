// lib/features/store_dashboard/models/store_order.dart

class OrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;

  const OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'] as String,
        name: json['name'] as String,
        quantity: json['quantity'] as int,
        price: (json['price'] as num).toDouble(),
      );
}

class CancelInfo {
  final String reason;
  final String cancelledBy;
  final DateTime cancelledAt;

  const CancelInfo({
    required this.reason,
    required this.cancelledBy,
    required this.cancelledAt,
  });

  factory CancelInfo.fromJson(Map<String, dynamic> json) => CancelInfo(
        reason: json['reason'] as String,
        cancelledBy: json['cancelledBy'] as String,
        cancelledAt: DateTime.parse(json['cancelledAt'] as String),
      );
}

class StoreOrder {
  final String id;
  final String code;
  final String mainStatus;
  final String paymentStatus;
  final String? refundStatus;
  final String deliveryMethod;
  final List<OrderItem> items;
  final double subtotal;
  final double shipFee;
  final double total;
  final double paidAmount;
  final String deliveryAddressText;
  final String? note;
  final String? recipientName;
  final String? recipientPhone;
  final CancelInfo? cancelInfo;
  final DateTime createdAt;
  final DateTime? pendingAt;

  const StoreOrder({
    required this.id,
    required this.code,
    required this.mainStatus,
    required this.paymentStatus,
    this.refundStatus,
    required this.deliveryMethod,
    required this.items,
    required this.subtotal,
    required this.shipFee,
    required this.total,
    required this.paidAmount,
    required this.deliveryAddressText,
    this.note,
    this.recipientName,
    this.recipientPhone,
    this.cancelInfo,
    required this.createdAt,
    this.pendingAt,
  });

  factory StoreOrder.fromJson(Map<String, dynamic> json) => StoreOrder(
        id: json['id'] as String,
        code: json['code'] as String,
        mainStatus: json['mainStatus'] as String,
        paymentStatus: json['paymentStatus'] as String,
        refundStatus: json['refundStatus'] as String?,
        deliveryMethod: json['deliveryMethod'] as String,
        items: (json['items'] as List)
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: (json['subtotal'] as num).toDouble(),
        shipFee: (json['shipFee'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        paidAmount: (json['paidAmount'] as num).toDouble(),
        deliveryAddressText: json['deliveryAddressText'] as String,
        note: json['note'] as String?,
        recipientName: json['recipientName'] as String?,
        recipientPhone: json['recipientPhone'] as String?,
        cancelInfo: json['cancelInfo'] != null
            ? CancelInfo.fromJson(json['cancelInfo'] as Map<String, dynamic>)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        pendingAt: json['pendingAt'] != null
            ? DateTime.parse(json['pendingAt'] as String)
            : null,
      );

  double get remainingAmount => total - paidAmount;

  bool get needsCollection =>
      mainStatus == 'delivered' &&
      (paymentStatus == 'partial' || paymentStatus == 'cod_pending');
}
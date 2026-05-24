// lib/features/store_dashboard/models/store_order.dart

class OrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final String? note;

  const OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    this.note,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: (json['itemId'] ?? json['id'] ?? '').toString(),
        name: json['nameSnapshot'] as String? ?? json['name'] as String? ?? '',
        quantity: (json['qty'] ?? json['quantity'] ?? 1) as int,
        price: ((json['priceSnapshot'] ?? json['price'] ?? 0) as num).toDouble(),
        note: json['note'] as String?,
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
        reason: json['reason'] as String? ?? '',
        cancelledBy: (json['by'] ?? json['cancelledBy'] ?? '').toString(),
        cancelledAt: DateTime.tryParse(
                (json['at'] ?? json['cancelledAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}

class StoreOrder {
  final String id;
  final String code;
  final String? customerId;
  final String mainStatus;
  final String paymentStatus;
  final String? refundStatus;
  final String paymentMethod;   // bank_transfer | cod | fifty_fifty
  final String deliveryMethod;  // store_delivery | self_pickup | customer_shipper
  final List<OrderItem> items;
  final double subtotal;
  final double shipFee;
  final double total;
  final double paidAmount;
  final String deliveryAddressText;
  final String? note;
  final String? recipientName;
  final String? recipientPhone;
  final bool isPreOrder;
  final String? bankTransferReceiptUrl;
  final List<String> foodPhotos;
  final CancelInfo? cancelInfo;
  final DateTime createdAt;
  final DateTime? pendingAt;
  final DateTime? acceptedAt;

  const StoreOrder({
    required this.id,
    required this.code,
    this.customerId,
    required this.mainStatus,
    required this.paymentStatus,
    this.refundStatus,
    required this.paymentMethod,
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
    this.isPreOrder = false,
    this.bankTransferReceiptUrl,
    this.foodPhotos = const [],
    this.cancelInfo,
    required this.createdAt,
    this.pendingAt,
    this.acceptedAt,
  });

  factory StoreOrder.fromJson(Map<String, dynamic> json) {
    DateTime? pendingAt;
    DateTime? acceptedAt;
    final history = json['statusHistory'] as List?;
    if (history != null) {
      for (final h in history) {
        final hm = h as Map<String, dynamic>;
        final s = hm['status'] as String?;
        final t = DateTime.tryParse((hm['at'] ?? '').toString());
        if (s == 'pending_store' && pendingAt == null) pendingAt = t;
        if (s == 'preparing' && acceptedAt == null) acceptedAt = t;
      }
    }

    final addr = json['deliveryAddress'] as Map?;

    return StoreOrder(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      code: json['code'] as String? ?? '',
      customerId: json['customerId']?.toString(),
      mainStatus: json['mainStatus'] as String? ?? 'pending_store',
      paymentStatus: json['paymentStatus'] as String? ?? 'unpaid',
      paymentMethod: json['paymentMethod'] as String? ?? 'bank_transfer',
      refundStatus: json['refundStatus'] as String?,
      deliveryMethod: json['deliveryMethod'] as String? ?? 'store_delivery',
      items: (json['items'] as List? ?? [])
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal:
          ((json['itemsTotal'] ?? json['subtotal'] ?? 0) as num).toDouble(),
      shipFee: (json['shipFee'] as num? ?? 0).toDouble(),
      total:
          ((json['totalAmount'] ?? json['total'] ?? 0) as num).toDouble(),
      paidAmount: (json['paidAmount'] as num? ?? 0).toDouble(),
      deliveryAddressText: addr?['text'] as String? ??
          json['deliveryAddressText'] as String? ?? '',
      note: json['customerNote'] as String? ?? json['note'] as String?,
      recipientName: (json['receiver'] as Map?)?['name'] as String? ??
          json['recipientName'] as String?,
      recipientPhone: (json['receiver'] as Map?)?['phone'] as String? ??
          json['recipientPhone'] as String?,
      isPreOrder: json['isPreOrder'] as bool? ?? false,
      bankTransferReceiptUrl: json['bankTransferReceiptUrl'] as String?,
      foodPhotos: (json['foodPhotos'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      cancelInfo: json['cancelInfo'] != null
          ? CancelInfo.fromJson(json['cancelInfo'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      pendingAt: pendingAt,
      acceptedAt: acceptedAt,
    );
  }

  double get remainingAmount =>
      (total - paidAmount).clamp(0.0, double.infinity);

  bool get isPending =>
      ['pending_store', 'awaiting_payment', 'awaiting_store_open']
          .contains(mainStatus);

  bool get isActive =>
      ['preparing', 'delivering'].contains(mainStatus);
}

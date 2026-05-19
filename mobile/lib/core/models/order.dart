// lib/core/models/order.dart
// Tạo theo spec v3.1 — mục 7.1 (multi-field status), 16 (MongoDB schema orders)

// ---------------------------------------------------------------------------
// Enums — khớp với string literals trong spec
// ---------------------------------------------------------------------------

/// spec 7.1 — mainStatus
enum OrderMainStatus {
  cart,
  created,
  awaitingPayment,
  awaitingStoreOpen,
  pendingStore,
  preparing,
  delivering,
  delivered,
  completed,
  cancelled;

  static OrderMainStatus fromJson(String v) => switch (v) {
        'cart'                 => cart,
        'created'              => created,
        'awaiting_payment'     => awaitingPayment,
        'awaiting_store_open'  => awaitingStoreOpen,
        'pending_store'        => pendingStore,
        'preparing'            => preparing,
        'delivering'           => delivering,
        'delivered'            => delivered,
        'completed'            => completed,
        'cancelled'            => cancelled,
        _ => throw ArgumentError('Unknown mainStatus: $v'),
      };

  String toJson() => switch (this) {
        cart                => 'cart',
        created             => 'created',
        awaitingPayment     => 'awaiting_payment',
        awaitingStoreOpen   => 'awaiting_store_open',
        pendingStore        => 'pending_store',
        preparing           => 'preparing',
        delivering          => 'delivering',
        delivered           => 'delivered',
        completed           => 'completed',
        cancelled           => 'cancelled',
      };
}

/// spec 7.1 — paymentStatus
enum OrderPaymentStatus {
  unpaid,
  reportedPaid,
  partial,
  paidFull,
  codPending,
  codCollected;

  static OrderPaymentStatus fromJson(String v) => switch (v) {
        'unpaid'        => unpaid,
        'reported_paid' => reportedPaid,
        'partial'       => partial,
        'paid_full'     => paidFull,
        'cod_pending'   => codPending,
        'cod_collected' => codCollected,
        _ => throw ArgumentError('Unknown paymentStatus: $v'),
      };

  String toJson() => switch (this) {
        unpaid        => 'unpaid',
        reportedPaid  => 'reported_paid',
        partial       => 'partial',
        paidFull      => 'paid_full',
        codPending    => 'cod_pending',
        codCollected  => 'cod_collected',
      };
}

/// spec 7.1 — refundStatus (nullable)
enum OrderRefundStatus {
  required,
  submitted,
  refunded,
  disputed;

  static OrderRefundStatus fromJson(String v) => switch (v) {
        'required'  => required,
        'submitted' => submitted,
        'refunded'  => refunded,
        'disputed'  => disputed,
        _ => throw ArgumentError('Unknown refundStatus: $v'),
      };

  String toJson() => switch (this) {
        required  => 'required',
        submitted => 'submitted',
        refunded  => 'refunded',
        disputed  => 'disputed',
      };
}

/// spec 7.1 — cancelInfo.by
enum CancelBy {
  customer,
  store,
  system,
  admin;

  static CancelBy fromJson(String v) => switch (v) {
        'customer' => customer,
        'store'    => store,
        'system'   => system,
        'admin'    => admin,
        _ => throw ArgumentError('Unknown cancelBy: $v'),
      };

  String toJson() => name; // 'customer' | 'store' | 'system' | 'admin'
}

/// spec 5.1.6 + 6 — deliveryMethod
enum DeliveryMethod {
  storeDelivery,
  selfPickup,
  customerShipper;

  static DeliveryMethod fromJson(String v) => switch (v) {
        'store_delivery'    => storeDelivery,
        'self_pickup'       => selfPickup,
        'customer_shipper'  => customerShipper,
        _ => throw ArgumentError('Unknown deliveryMethod: $v'),
      };

  String toJson() => switch (this) {
        storeDelivery   => 'store_delivery',
        selfPickup      => 'self_pickup',
        customerShipper => 'customer_shipper',
      };
}

/// spec 5.3.1 — paymentMethod
enum PaymentMethod {
  bankTransfer,
  cod,
  fiftyFifty,
  momo,
  zaloPay;

  static PaymentMethod fromJson(String v) => switch (v) {
        'bank_transfer' => bankTransfer,
        'cod'           => cod,
        'fifty_fifty'   => fiftyFifty,
        'momo'          => momo,
        'zalo_pay'      => zaloPay,
        _ => throw ArgumentError('Unknown paymentMethod: $v'),
      };

  String toJson() => switch (this) {
        bankTransfer => 'bank_transfer',
        cod          => 'cod',
        fiftyFifty   => 'fifty_fifty',
        momo         => 'momo',
        zaloPay      => 'zalo_pay',
      };
}

// ---------------------------------------------------------------------------
// Sub-models
// ---------------------------------------------------------------------------

/// spec schema: orders.items[]
class OrderItem {
  final String itemId;
  final String nameSnapshot;
  final double priceSnapshot;
  final int qty;
  final String? note;

  const OrderItem({
    required this.itemId,
    required this.nameSnapshot,
    required this.priceSnapshot,
    required this.qty,
    this.note,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        itemId:        j['itemId']        as String,
        nameSnapshot:  j['nameSnapshot']  as String,
        priceSnapshot: (j['priceSnapshot'] as num).toDouble(),
        qty:           j['qty']           as int,
        note:          j['note']          as String?,
      );

  Map<String, dynamic> toJson() => {
        'itemId':        itemId,
        'nameSnapshot':  nameSnapshot,
        'priceSnapshot': priceSnapshot,
        'qty':           qty,
        'note':          note,
      };

  /// Tiện ích hiển thị: "Phở bò × 2"
  String get displayLine => '$nameSnapshot × $qty';
}

/// spec schema: orders.receiver
class OrderReceiver {
  final String name;
  final String phone;
  final bool isSelfReceiver;

  const OrderReceiver({
    required this.name,
    required this.phone,
    required this.isSelfReceiver,
  });

  factory OrderReceiver.fromJson(Map<String, dynamic> j) => OrderReceiver(
        name:            j['name']            as String,
        phone:           j['phone']           as String,
        isSelfReceiver:  (j['isSelfReceiver'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name':           name,
        'phone':          phone,
        'isSelfReceiver': isSelfReceiver,
      };
}

/// spec schema: orders.guestInfo
class GuestInfo {
  final String name;
  final String phone;
  final String? email;
  final BankAccount? bankAccountForRefund;

  const GuestInfo({
    required this.name,
    required this.phone,
    this.email,
    this.bankAccountForRefund,
  });

  factory GuestInfo.fromJson(Map<String, dynamic> j) => GuestInfo(
        name:                 j['name']  as String,
        phone:                j['phone'] as String,
        email:                j['email'] as String?,
        bankAccountForRefund: j['bankAccountForRefund'] != null
            ? BankAccount.fromJson(
                j['bankAccountForRefund'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name':  name,
        'phone': phone,
        if (email != null) 'email': email,
        if (bankAccountForRefund != null)
          'bankAccountForRefund': bankAccountForRefund!.toJson(),
      };
}

/// Dùng trong storeBankSnapshot + refundInfo.bankAccountReceiver
class BankAccount {
  final String number;
  final String bank;
  final String holder;

  const BankAccount({
    required this.number,
    required this.bank,
    required this.holder,
  });

  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
        number: j['number'] as String,
        bank:   j['bank']   as String,
        holder: j['holder'] as String,
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'bank':   bank,
        'holder': holder,
      };
}

/// spec schema: orders.shipFeeFormulaSnapshot
class ShipFeeFormulaSnapshot {
  final double a;
  final double b;
  final double c;
  final double distanceKm;

  const ShipFeeFormulaSnapshot({
    required this.a,
    required this.b,
    required this.c,
    required this.distanceKm,
  });

  factory ShipFeeFormulaSnapshot.fromJson(Map<String, dynamic> j) =>
      ShipFeeFormulaSnapshot(
        a:          (j['a']          as num).toDouble(),
        b:          (j['b']          as num).toDouble(),
        c:          (j['c']          as num).toDouble(),
        distanceKm: (j['distanceKm'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'a':          a,
        'b':          b,
        'c':          c,
        'distanceKm': distanceKm,
      };
}

/// spec schema: orders.deliveryAddress
class DeliveryAddress {
  final String text;
  final double? lat;
  final double? lng;

  const DeliveryAddress({
    required this.text,
    this.lat,
    this.lng,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> j) {
    final loc = j['location'] as Map<String, dynamic>?;
    final coords = loc?['coordinates'] as List<dynamic>?;
    return DeliveryAddress(
      text: j['text'] as String,
      lng:  coords != null ? (coords[0] as num).toDouble() : null,
      lat:  coords != null ? (coords[1] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        if (lat != null && lng != null)
          'location': {
            'type': 'Point',
            'coordinates': [lng, lat],
          },
      };
}

/// spec schema: orders.cancelInfo
class CancelInfo {
  final CancelBy by;
  final String reason;
  final DateTime at;

  const CancelInfo({
    required this.by,
    required this.reason,
    required this.at,
  });

  factory CancelInfo.fromJson(Map<String, dynamic> j) => CancelInfo(
        by:     CancelBy.fromJson(j['by'] as String),
        reason: j['reason'] as String,
        at:     DateTime.parse(j['at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'by':     by.toJson(),
        'reason': reason,
        'at':     at.toIso8601String(),
      };
}

/// spec schema: orders.refundInfo
class RefundInfo {
  final DateTime? submittedAt;
  final String? refundProofImage;  // Cloudinary URL ảnh UNC
  final DateTime? refundedAt;
  final BankAccount? bankAccountReceiver;

  const RefundInfo({
    this.submittedAt,
    this.refundProofImage,
    this.refundedAt,
    this.bankAccountReceiver,
  });

  factory RefundInfo.fromJson(Map<String, dynamic> j) => RefundInfo(
        submittedAt:          j['submittedAt'] != null
            ? DateTime.parse(j['submittedAt'] as String)
            : null,
        refundProofImage:     j['refundProofImage'] as String?,
        refundedAt:           j['refundedAt'] != null
            ? DateTime.parse(j['refundedAt'] as String)
            : null,
        bankAccountReceiver:  j['bankAccountReceiver'] != null
            ? BankAccount.fromJson(
                j['bankAccountReceiver'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        if (submittedAt != null)
          'submittedAt': submittedAt!.toIso8601String(),
        if (refundProofImage != null)
          'refundProofImage': refundProofImage,
        if (refundedAt != null)
          'refundedAt': refundedAt!.toIso8601String(),
        if (bankAccountReceiver != null)
          'bankAccountReceiver': bankAccountReceiver!.toJson(),
      };
}

/// spec schema: orders.statusHistory[]
class StatusHistoryEntry {
  final String status;
  final DateTime at;
  final String? by; // userId hoặc 'system'

  const StatusHistoryEntry({
    required this.status,
    required this.at,
    this.by,
  });

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> j) =>
      StatusHistoryEntry(
        status: j['status'] as String,
        at:     DateTime.parse(j['at'] as String),
        by:     j['by'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'at':     at.toIso8601String(),
        if (by != null) 'by': by,
      };
}

// ---------------------------------------------------------------------------
// Order — model chính
// ---------------------------------------------------------------------------

class Order {
  // Identity
  final String id;           // MongoDB _id
  final String code;         // "AB251107-456" (spec 8)
  final String? trackingToken; // 32 chars, chỉ có ở guest orders (spec OD-10)

  // Parties
  final String? customerId;
  final GuestInfo? guestInfo;
  final String storeId;
  final OrderReceiver receiver;

  // Items
  final List<OrderItem> items;
  final double itemsTotal;
  final double shipFee;
  final ShipFeeFormulaSnapshot? shipFeeFormulaSnapshot;
  final double totalAmount;

  // Payment
  final PaymentMethod paymentMethod;
  final BankAccount? storeBankSnapshot;
  final double paidAmount;
  final OrderPaymentStatus paymentStatus;

  // Delivery
  final DeliveryMethod deliveryMethod;
  final DeliveryAddress? deliveryAddress;
  final double? distanceKm;
  final String customerNote;

  // Status (spec 7.1)
  final OrderMainStatus mainStatus;
  final bool isPreOrder;
  final OrderRefundStatus? refundStatus;
  final RefundInfo? refundInfo;
  final CancelInfo? cancelInfo;
  final List<StatusHistoryEntry> statusHistory;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.code,
    this.trackingToken,
    this.customerId,
    this.guestInfo,
    required this.storeId,
    required this.receiver,
    required this.items,
    required this.itemsTotal,
    required this.shipFee,
    this.shipFeeFormulaSnapshot,
    required this.totalAmount,
    required this.paymentMethod,
    this.storeBankSnapshot,
    required this.paidAmount,
    required this.paymentStatus,
    required this.deliveryMethod,
    this.deliveryAddress,
    this.distanceKm,
    required this.customerNote,
    required this.mainStatus,
    required this.isPreOrder,
    this.refundStatus,
    this.refundInfo,
    this.cancelInfo,
    required this.statusHistory,
    required this.createdAt,
    required this.updatedAt,
  });

  // ---------------------------------------------------------------------------
  // fromJson
  // ---------------------------------------------------------------------------

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id:   (j['_id'] ?? j['id']) as String,
        code: j['code'] as String,
        trackingToken: j['trackingToken'] as String?,

        customerId: j['customerId'] as String?,
        guestInfo:  j['guestInfo'] != null
            ? GuestInfo.fromJson(j['guestInfo'] as Map<String, dynamic>)
            : null,
        storeId:    j['storeId'] as String,
        receiver:   OrderReceiver.fromJson(
            j['receiver'] as Map<String, dynamic>),

        items: (j['items'] as List<dynamic>)
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        itemsTotal: (j['itemsTotal'] as num).toDouble(),
        shipFee:    (j['shipFee']    as num).toDouble(),
        shipFeeFormulaSnapshot: j['shipFeeFormulaSnapshot'] != null
            ? ShipFeeFormulaSnapshot.fromJson(
                j['shipFeeFormulaSnapshot'] as Map<String, dynamic>)
            : null,
        totalAmount: (j['totalAmount'] as num).toDouble(),

        paymentMethod:     PaymentMethod.fromJson(
            j['paymentMethod'] as String),
        storeBankSnapshot: j['storeBankSnapshot'] != null
            ? BankAccount.fromJson(
                j['storeBankSnapshot'] as Map<String, dynamic>)
            : null,
        paidAmount:    (j['paidAmount']    as num).toDouble(),
        paymentStatus: OrderPaymentStatus.fromJson(
            j['paymentStatus'] as String),

        deliveryMethod:  DeliveryMethod.fromJson(
            j['deliveryMethod'] as String),
        deliveryAddress: j['deliveryAddress'] != null
            ? DeliveryAddress.fromJson(
                j['deliveryAddress'] as Map<String, dynamic>)
            : null,
        distanceKm:   j['distanceKm'] != null
            ? (j['distanceKm'] as num).toDouble()
            : null,
        customerNote: (j['customerNote'] as String?) ?? '',

        mainStatus:  OrderMainStatus.fromJson(j['mainStatus'] as String),
        isPreOrder:  (j['isPreOrder']  as bool?) ?? false,
        refundStatus: j['refundStatus'] != null
            ? OrderRefundStatus.fromJson(j['refundStatus'] as String)
            : null,
        refundInfo:  j['refundInfo'] != null
            ? RefundInfo.fromJson(j['refundInfo'] as Map<String, dynamic>)
            : null,
        cancelInfo:  j['cancelInfo'] != null
            ? CancelInfo.fromJson(j['cancelInfo'] as Map<String, dynamic>)
            : null,
        statusHistory: (j['statusHistory'] as List<dynamic>?)
                ?.map((e) => StatusHistoryEntry.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            [],

        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );

  // ---------------------------------------------------------------------------
  // toJson — dùng khi gửi lên backend (chỉ các field client tự sinh)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'code':          code,
        'storeId':       storeId,
        'receiver':      receiver.toJson(),
        'items':         items.map((e) => e.toJson()).toList(),
        'itemsTotal':    itemsTotal,
        'shipFee':       shipFee,
        'totalAmount':   totalAmount,
        'paymentMethod': paymentMethod.toJson(),
        'paidAmount':    paidAmount,
        'paymentStatus': paymentStatus.toJson(),
        'deliveryMethod': deliveryMethod.toJson(),
        if (deliveryAddress != null)
          'deliveryAddress': deliveryAddress!.toJson(),
        if (distanceKm != null) 'distanceKm': distanceKm,
        'customerNote':  customerNote,
        'mainStatus':    mainStatus.toJson(),
        'isPreOrder':    isPreOrder,
        if (guestInfo != null) 'guestInfo': guestInfo!.toJson(),
      };

  // ---------------------------------------------------------------------------
  // Computed properties — dùng trong UI
  // ---------------------------------------------------------------------------

  /// Tiền còn phải thu (spec 5.3.4)
  double get remainingAmount => (totalAmount - paidAmount).clamp(0, double.infinity);

  /// Tóm tắt items cho OrderCard: "Phở bò × 2, Cơm tấm × 1..."
  String get itemsSummary {
    final parts = items.map((e) => e.displayLine).toList();
    if (parts.length <= 3) return parts.join(', ');
    return '${parts.take(3).join(', ')} (+${parts.length - 3})';
  }

  /// Tên người nhận (receiver)
  String get receiverName => receiver.name;

  /// SĐT người nhận (receiver)
  String get receiverPhone => receiver.phone;

  /// Đơn có phải CK trước không (dùng để hiện nút "Tiền chưa vào TK")
  bool get isBankTransferBased =>
      paymentMethod == PaymentMethod.bankTransfer ||
      paymentMethod == PaymentMethod.fiftyFifty;

  /// Đơn đang cần hoàn tiền
  bool get needsRefund =>
      refundStatus == OrderRefundStatus.required ||
      refundStatus == OrderRefundStatus.submitted;

  /// Đơn đã bị huỷ
  bool get isCancelled => mainStatus == OrderMainStatus.cancelled;

  /// Đơn đã hoàn thành
  bool get isCompleted => mainStatus == OrderMainStatus.completed;

  // ---------------------------------------------------------------------------
  // copyWith — tiện khi update state cục bộ trước khi gọi API
  // ---------------------------------------------------------------------------

  Order copyWith({
    OrderMainStatus?    mainStatus,
    OrderPaymentStatus? paymentStatus,
    OrderRefundStatus?  refundStatus,
    double?             paidAmount,
    CancelInfo?         cancelInfo,
    RefundInfo?         refundInfo,
    List<StatusHistoryEntry>? statusHistory,
    DateTime?           updatedAt,
  }) =>
      Order(
        id:                    id,
        code:                  code,
        trackingToken:         trackingToken,
        customerId:            customerId,
        guestInfo:             guestInfo,
        storeId:               storeId,
        receiver:              receiver,
        items:                 items,
        itemsTotal:            itemsTotal,
        shipFee:               shipFee,
        shipFeeFormulaSnapshot: shipFeeFormulaSnapshot,
        totalAmount:           totalAmount,
        paymentMethod:         paymentMethod,
        storeBankSnapshot:     storeBankSnapshot,
        paidAmount:            paidAmount         ?? this.paidAmount,
        paymentStatus:         paymentStatus       ?? this.paymentStatus,
        deliveryMethod:        deliveryMethod,
        deliveryAddress:       deliveryAddress,
        distanceKm:            distanceKm,
        customerNote:          customerNote,
        mainStatus:            mainStatus          ?? this.mainStatus,
        isPreOrder:            isPreOrder,
        refundStatus:          refundStatus        ?? this.refundStatus,
        refundInfo:            refundInfo          ?? this.refundInfo,
        cancelInfo:            cancelInfo          ?? this.cancelInfo,
        statusHistory:         statusHistory       ?? this.statusHistory,
        createdAt:             createdAt,
        updatedAt:             updatedAt           ?? DateTime.now(),
      );

  @override
  String toString() => 'Order($code, $mainStatus, $paymentStatus)';

  @override
  bool operator ==(Object other) => other is Order && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// lib/core/models/order.dart
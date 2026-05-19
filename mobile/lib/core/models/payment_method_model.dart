// lib/core/models/payment_method_model.dart

/// Các phương thức thanh toán mà quán có thể bật/tắt,
/// map 1-1 với schema `stores.paymentMethods` trong MongoDB.
enum PaymentMethod {
  bankTransfer,
  cod,
  fiftyFifty,
  momo,
  zaloPay,
}

extension PaymentMethodX on PaymentMethod {
  /// Key tương ứng trong JSON/backend.
  String get key => switch (this) {
        PaymentMethod.bankTransfer => 'bankTransfer',
        PaymentMethod.cod => 'cod',
        PaymentMethod.fiftyFifty => 'fiftyFifty',
        PaymentMethod.momo => 'momo',
        PaymentMethod.zaloPay => 'zaloPay',
      };

  /// Nhãn hiển thị tiếng Việt.
  String get label => switch (this) {
        PaymentMethod.bankTransfer => 'Chuyển khoản',
        PaymentMethod.cod => 'Thanh toán khi nhận hàng (COD)',
        PaymentMethod.fiftyFifty => 'Đặt cọc 50 – trả 50 khi nhận',
        PaymentMethod.momo => 'Momo',
        PaymentMethod.zaloPay => 'ZaloPay',
      };

  /// Khi khách chọn "Tự đến lấy" hoặc "Shipper riêng", COD vẫn hợp lệ.
  /// Pre-order luôn bắt buộc CK trước — caller tự lọc.
  bool get requiresPrepayment => switch (this) {
        PaymentMethod.bankTransfer => true,
        PaymentMethod.fiftyFifty => true,
        PaymentMethod.momo => true,
        PaymentMethod.zaloPay => true,
        PaymentMethod.cod => false,
      };

  static PaymentMethod? fromKey(String key) {
    for (final m in PaymentMethod.values) {
      if (m.key == key) return m;
    }
    return null;
  }
}

/// Model ánh xạ object `paymentMethods` từ API quán.
class PaymentMethodsConfig {
  final bool bankTransfer;
  final bool cod;
  final bool fiftyFifty;
  final bool momo;
  final bool zaloPay;

  const PaymentMethodsConfig({
    required this.bankTransfer,
    required this.cod,
    required this.fiftyFifty,
    required this.momo,
    required this.zaloPay,
  });

  factory PaymentMethodsConfig.fromJson(Map<String, dynamic> json) =>
      PaymentMethodsConfig(
        bankTransfer: (json['bankTransfer'] as bool?) ?? false,
        cod: (json['cod'] as bool?) ?? false,
        fiftyFifty: (json['fiftyFifty'] as bool?) ?? false,
        momo: (json['momo'] as bool?) ?? false,
        zaloPay: (json['zaloPay'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'bankTransfer': bankTransfer,
        'cod': cod,
        'fiftyFifty': fiftyFifty,
        'momo': momo,
        'zaloPay': zaloPay,
      };

  /// Danh sách phương thức đang được bật.
  List<PaymentMethod> get enabled => [
        if (bankTransfer) PaymentMethod.bankTransfer,
        if (cod) PaymentMethod.cod,
        if (fiftyFifty) PaymentMethod.fiftyFifty,
        if (momo) PaymentMethod.momo,
        if (zaloPay) PaymentMethod.zaloPay,
      ];

  PaymentMethodsConfig copyWith({
    bool? bankTransfer,
    bool? cod,
    bool? fiftyFifty,
    bool? momo,
    bool? zaloPay,
  }) =>
      PaymentMethodsConfig(
        bankTransfer: bankTransfer ?? this.bankTransfer,
        cod: cod ?? this.cod,
        fiftyFifty: fiftyFifty ?? this.fiftyFifty,
        momo: momo ?? this.momo,
        zaloPay: zaloPay ?? this.zaloPay,
      );
}

// lib/core/models/payment_method_model.dart
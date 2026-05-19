// lib/features/store_dashboard/providers/payment_methods_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/payment_method_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';

// ── Fetch cấu hình hiện tại ────────────────────────────────────────────────

/// Lấy `paymentMethods` của quán [storeId] từ backend.
/// Cache riêng theo storeId.
final paymentMethodsConfigProvider =
    FutureProvider.family<PaymentMethodsConfig, String>((ref, storeId) async {
  final res = await DioClient().dio.get(
        ApiEndpoints.storeById(storeId),
        queryParameters: {'fields': 'paymentMethods'},
      );

  final data = res.data as Map<String, dynamic>;
  final raw = (data['paymentMethods'] ?? data) as Map<String, dynamic>;
  return PaymentMethodsConfig.fromJson(raw);
});

// ── Notifier cập nhật ──────────────────────────────────────────────────────

/// State + actions để chủ quán bật/tắt phương thức thanh toán.
/// Dùng trong store dashboard settings.
class PaymentMethodsNotifier
    extends AutoDisposeFamilyAsyncNotifier<PaymentMethodsConfig, String> {
  @override
  Future<PaymentMethodsConfig> build(String storeId) async {
    final res = await DioClient().dio.get(
          ApiEndpoints.storeById(storeId),
          queryParameters: {'fields': 'paymentMethods'},
        );
    final data = res.data as Map<String, dynamic>;
    final raw = (data['paymentMethods'] ?? data) as Map<String, dynamic>;
    return PaymentMethodsConfig.fromJson(raw);
  }

  /// Bật/tắt 1 phương thức và lưu lên server ngay.
  Future<void> toggle(PaymentMethod method, {required bool enabled}) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = switch (method) {
      PaymentMethod.bankTransfer => current.copyWith(bankTransfer: enabled),
      PaymentMethod.cod => current.copyWith(cod: enabled),
      PaymentMethod.fiftyFifty => current.copyWith(fiftyFifty: enabled),
      PaymentMethod.momo => current.copyWith(momo: enabled),
      PaymentMethod.zaloPay => current.copyWith(zaloPay: enabled),
    };

    // Optimistic update
    state = AsyncData(updated);

    try {
      await DioClient().dio.patch(
            ApiEndpoints.storeById(arg),
            data: {'paymentMethods': updated.toJson()},
          );
    } catch (e, st) {
      // Rollback nếu request thất bại
      state = AsyncData(current);
      state = AsyncError(e, st);
    }
  }

  /// Lưu toàn bộ config cùng 1 lúc (dùng khi có nút "Lưu" riêng).
  Future<void> saveAll(PaymentMethodsConfig config) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await DioClient().dio.patch(
            ApiEndpoints.storeById(arg),
            data: {'paymentMethods': config.toJson()},
          );
      return config;
    });
  }
}

final paymentMethodsNotifierProvider = AsyncNotifierProvider.autoDispose
    .family<PaymentMethodsNotifier, PaymentMethodsConfig, String>(
  PaymentMethodsNotifier.new,
);

// ── Helper provider cho màn đặt hàng ──────────────────────────────────────

/// Trả về danh sách [PaymentMethod] được bật của quán.
/// Dùng ở checkout để lọc các lựa chọn thanh toán khả dụng.
final enabledPaymentMethodsProvider =
    Provider.autoDispose.family<List<PaymentMethod>, String>((ref, storeId) {
  final config = ref.watch(paymentMethodsConfigProvider(storeId));
  return config.whenOrNull(data: (c) => c.enabled) ?? [];
});

// lib/features/store_dashboard/providers/payment_methods_provider.dart
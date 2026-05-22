// lib/features/profile/providers/payment_methods_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';

enum PaymentType { bankTransfer, cod, fiftyFifty, momo, zaloPay }

class BankAccount {
  final String bankCode;
  final String accountNumber;
  final String accountHolder;

  const BankAccount({
    required this.bankCode,
    required this.accountNumber,
    required this.accountHolder,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        bankCode: json['bank'] as String,
        accountNumber: json['number'] as String,
        accountHolder: json['holder'] as String,
      );

  Map<String, dynamic> toJson() => {
        'bank': bankCode,
        'number': accountNumber,
        'holder': accountHolder,
      };
}

enum PmStatus { initial, loading, loaded, error }

class PaymentMethodsState {
  final PmStatus status;
  final PaymentType? defaultMethod;
  final BankAccount? bankAccountForRefund;
  final bool isSavingDefault;
  final String? errorMessage;

  const PaymentMethodsState({
    this.status = PmStatus.initial,
    this.defaultMethod,
    this.bankAccountForRefund,
    this.isSavingDefault = false,
    this.errorMessage,
  });

  PaymentMethodsState copyWith({
    PmStatus? status,
    PaymentType? defaultMethod,
    BankAccount? bankAccountForRefund,
    bool? isSavingDefault,
    String? errorMessage,
    bool clearBankAccount = false,
  }) =>
      PaymentMethodsState(
        status: status ?? this.status,
        defaultMethod: defaultMethod ?? this.defaultMethod,
        bankAccountForRefund: clearBankAccount
            ? null
            : bankAccountForRefund ?? this.bankAccountForRefund,
        isSavingDefault: isSavingDefault ?? this.isSavingDefault,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class PaymentMethodsNotifier extends StateNotifier<PaymentMethodsState> {
  PaymentMethodsNotifier() : super(const PaymentMethodsState());

  Future<void> load() async {
    state = state.copyWith(status: PmStatus.loading);
    try {
      final res = await DioClient.instance.get(ApiEndpoints.me);
      final data = res.data is Map ? res.data : {};
      final user = (data['user'] ?? data) as Map<String, dynamic>;

      final rawMethod = user['defaultPaymentMethod'] as String?;
      final bankJson = user['bankAccountForRefund'] as Map<String, dynamic>?;

      PaymentType? method;
      if (rawMethod != null) {
        method = PaymentType.values.firstWhere(
          (e) => e.name == rawMethod,
          orElse: () => PaymentType.bankTransfer,
        );
      }

      state = state.copyWith(
        status: PmStatus.loaded,
        defaultMethod: method ?? PaymentType.bankTransfer,
        bankAccountForRefund:
            bankJson != null ? BankAccount.fromJson(bankJson) : null,
      );
    } catch (e) {
      state = state.copyWith(status: PmStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> setDefaultMethod(PaymentType type) async {
    final prev = state.defaultMethod;
    state = state.copyWith(isSavingDefault: true, defaultMethod: type);
    try {
      await DioClient.instance.patch(ApiEndpoints.me, data: {
        'defaultPaymentMethod': type.name,
      });
      state = state.copyWith(isSavingDefault: false);
    } catch (_) {
      state = state.copyWith(isSavingDefault: false, defaultMethod: prev);
    }
  }

  Future<void> saveBankAccount({
    required String bankCode,
    required String accountNumber,
    required String accountHolder,
  }) async {
    final account = BankAccount(
      bankCode: bankCode,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
    );
    await DioClient.instance.patch(ApiEndpoints.myBankAccount, data: account.toJson());
    state = state.copyWith(bankAccountForRefund: account);
  }
}

final paymentMethodsProvider =
    StateNotifierProvider<PaymentMethodsNotifier, PaymentMethodsState>((ref) {
  return PaymentMethodsNotifier();
});

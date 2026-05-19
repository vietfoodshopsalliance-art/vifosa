// 📁 mobile/lib/features/profile/screens/payment_methods_screen.dart
// Vifosa — Viet Food Shops Alliance
// Payment Methods Screen — Cài đặt phương thức thanh toán mặc định của khách
// Ref spec: §5.1.11, §BIZ-6, §0.4 OD-4, schema `users.bankAccountForRefund`

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/app_snackbar.dart';
import '../../../core/models/payment_method_model.dart';
import '../../store_dashboard/providers/payment_methods_provider.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Màn hình cài đặt thanh toán của người dùng (role: customer).
///
/// Gồm 2 phần:
///   1. Chọn phương thức thanh toán mặc định (bank_transfer / momo / zalo_pay / cod)
///      — chỉ hiển thị phương thức quán hỗ trợ khi vào màn hình đặt hàng;
///      ở đây user lưu preference cá nhân.
///   2. Tài khoản ngân hàng nhận hoàn tiền (`bankAccountForRefund`)
///      — spec §5.1.11, §7.4 refund flow step 2.
class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentMethodsProvider.notifier).load();
    });
  }

  // ---- Phương thức thanh toán mặc định ------------------------------------

  void _selectDefaultMethod(PaymentType type) {
    ref.read(paymentMethodsProvider.notifier).setDefaultMethod(type);
  }

  // ---- Tài khoản ngân hàng nhận hoàn tiền ---------------------------------

  void _openAddBankAccount() {
    final state = ref.read(paymentMethodsProvider);
    _showBankAccountSheet(existing: state.bankAccountForRefund);
  }

  void _openEditBankAccount() {
    final state = ref.read(paymentMethodsProvider);
    _showBankAccountSheet(existing: state.bankAccountForRefund);
  }

  void _showBankAccountSheet({BankAccount? existing}) {
    final numberCtrl =
        TextEditingController(text: existing?.accountNumber ?? '');
    final holderCtrl =
        TextEditingController(text: existing?.accountHolder ?? '');
    String selectedBank = existing?.bankCode ?? '';
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) => Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    existing == null
                        ? 'Thêm TK nhận hoàn tiền'
                        : 'Sửa TK nhận hoàn tiền',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dùng khi quán cần hoàn tiền cho bạn.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // Chọn ngân hàng
                  DropdownButtonFormField<String>(
                    initialValue: selectedBank.isEmpty ? null : selectedBank,
                    decoration: const InputDecoration(
                      labelText: 'Ngân hàng *',
                      border: OutlineInputBorder(),
                    ),
                    items: _supportedBanks
                        .map((b) => DropdownMenuItem(
                              value: b['code'],
                              child: Text('${b['code']} — ${b['name']}'),
                            ))
                        .toList(),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Vui lòng chọn ngân hàng' : null,
                    onChanged: (v) =>
                        setSheetState(() => selectedBank = v ?? ''),
                  ),
                  const SizedBox(height: 12),

                  // Số tài khoản
                  TextFormField(
                    controller: numberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Số tài khoản *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập số tài khoản';
                      }
                      if (v.trim().length < 6) {
                        return 'Số tài khoản không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Chủ tài khoản
                  TextFormField(
                    controller: holderCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên chủ tài khoản *',
                      hintText: 'Nhập đúng như trên thẻ/sổ',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Vui lòng nhập tên chủ tài khoản'
                            : null,
                  ),
                  const SizedBox(height: 24),

                  // Nút lưu
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        Navigator.pop(ctx);
                        await ref
                            .read(paymentMethodsProvider.notifier)
                            .saveBankAccount(
                              bankCode: selectedBank,
                              accountNumber: numberCtrl.text.trim(),
                              accountHolder: holderCtrl.text.trim().toUpperCase(),
                            );
                        if (mounted) {
                          AppSnackbar.success(context, 'Đã lưu tài khoản ngân hàng');
                        }
                      },
                      child: const Text('Lưu'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Phương thức thanh toán')),
      body: switch (state.status) {
        PmStatus.loading => const Center(child: CircularProgressIndicator()),
        PmStatus.error => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.errorMessage ?? 'Có lỗi xảy ra'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(paymentMethodsProvider.notifier).load(),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        _ => ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // ── Phương thức mặc định ──────────────────────────────────────
              const _SectionHeader(title: 'Phương thức mặc định'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Được chọn sẵn khi đặt hàng. Bạn vẫn có thể đổi trong từng đơn.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
              const SizedBox(height: 4),
              ..._paymentOptions.map(
                (opt) => _PaymentOptionTile(
                  icon: opt.icon,
                  label: opt.label,
                  subtitle: opt.subtitle,
                  value: opt.type,
                  groupValue: state.defaultMethod,
                  onChanged: _selectDefaultMethod,
                  isSaving: state.isSavingDefault,
                ),
              ),

              const Divider(height: 32),

              // ── TK ngân hàng nhận hoàn tiền ───────────────────────────────
              const _SectionHeader(title: 'TK ngân hàng nhận hoàn tiền'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Dùng khi quán hoàn tiền. Lưu trước để không phải nhập lại lúc cần.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),

              if (state.bankAccountForRefund != null)
                _BankAccountCard(
                  account: state.bankAccountForRefund!,
                  onEdit: _openEditBankAccount,
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm tài khoản ngân hàng'),
                    onPressed: _openAddBankAccount,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // ── Ghi chú BIZ-6 ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Vifosa không lưu giữ tiền. Tiền được chuyển trực tiếp '
                          'giữa bạn và quán. Ví điện tử (Momo, ZaloPay) cần quán '
                          'hỗ trợ mới dùng được.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets nội bộ
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );
}

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.isSaving,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final PaymentType value;
  final PaymentType? groupValue;
  final ValueChanged<PaymentType> onChanged;
  final bool isSaving;

  @override
  Widget build(BuildContext context) => RadioListTile<PaymentType>(
        value: value,
        groupValue: groupValue,
        title: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        onChanged: isSaving ? null : (v) => onChanged(v!),
        secondary: isSaving && groupValue == value
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      );
}

class _BankAccountCard extends StatelessWidget {
  const _BankAccountCard({required this.account, required this.onEdit});
  final BankAccount account;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: Text(
              account.bankCode,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.accountNumber),
                Text(
                  account.accountHolder,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            trailing: TextButton(
              onPressed: onEdit,
              child: const Text('Sửa'),
            ),
            isThreeLine: true,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// Các phương thức thanh toán hỗ trợ trong MVP
/// Spec §5.3.1: bankTransfer / cod / fiftyFifty / momo / zaloPay
enum PaymentType {
  bankTransfer,
  cod,
  fiftyFifty,
  momo,
  zaloPay,
}

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

// ---------------------------------------------------------------------------
// Static data
// ---------------------------------------------------------------------------

/// Danh sách option hiển thị — spec §5.3.1 paymentMethods
class _PaymentOption {
  final IconData icon;
  final String label;
  final String subtitle;
  final PaymentType type;
  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.type,
  });
}

const _paymentOptions = [
  _PaymentOption(
    icon: Icons.account_balance_outlined,
    label: 'Chuyển khoản ngân hàng',
    subtitle: 'Chuyển trực tiếp qua số TK hoặc VietQR',
    type: PaymentType.bankTransfer,
  ),
  _PaymentOption(
    icon: Icons.payments_outlined,
    label: 'Thanh toán khi nhận hàng (COD)',
    subtitle: 'Trả tiền mặt khi nhận hàng (nếu quán hỗ trợ)',
    type: PaymentType.cod,
  ),
  _PaymentOption(
    icon: Icons.splitscreen_outlined,
    label: '50% trước – 50% khi nhận',
    subtitle: 'Nếu quán hỗ trợ hình thức này',
    type: PaymentType.fiftyFifty,
  ),
  _PaymentOption(
    icon: Icons.account_balance_wallet_outlined,
    label: 'MoMo',
    subtitle: 'Nếu quán hỗ trợ MoMo',
    type: PaymentType.momo,
  ),
  _PaymentOption(
    icon: Icons.mobile_friendly_outlined,
    label: 'ZaloPay',
    subtitle: 'Nếu quán hỗ trợ ZaloPay',
    type: PaymentType.zaloPay,
  ),
];

/// Danh sách ngân hàng phổ biến tại VN (không đủ tất cả — chỉ MVP)
const _supportedBanks = [
  {'code': 'VCB', 'name': 'Vietcombank'},
  {'code': 'TCB', 'name': 'Techcombank'},
  {'code': 'MB', 'name': 'MB Bank'},
  {'code': 'VPB', 'name': 'VPBank'},
  {'code': 'ACB', 'name': 'ACB'},
  {'code': 'BIDV', 'name': 'BIDV'},
  {'code': 'VTB', 'name': 'Vietinbank'},
  {'code': 'STB', 'name': 'Sacombank'},
  {'code': 'TPB', 'name': 'TPBank'},
  {'code': 'OCB', 'name': 'OCB'},
  {'code': 'MSB', 'name': 'Maritime Bank'},
  {'code': 'SHB', 'name': 'SHB'},
  {'code': 'VIB', 'name': 'VIB'},
  {'code': 'HDBank', 'name': 'HDBank'},
  {'code': 'CAKE', 'name': 'CAKE (VPBank Digital)'},
  {'code': 'Timo', 'name': 'Timo (VPBank)'},
  {'code': 'KHAC', 'name': 'Ngân hàng khác'},
];

// ---------------------------------------------------------------------------
// Provider state & notifier
// Tách ra: mobile/lib/features/profile/providers/payment_methods_provider.dart
// ---------------------------------------------------------------------------

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

final paymentMethodsProvider =
    StateNotifierProvider<PaymentMethodsNotifier, PaymentMethodsState>((ref) {
  return PaymentMethodsNotifier();
});

class PaymentMethodsNotifier extends StateNotifier<PaymentMethodsState> {
  PaymentMethodsNotifier() : super(const PaymentMethodsState());

  /// Load setting từ server — spec: preference lưu phía user profile
  Future<void> load() async {
    state = state.copyWith(status: PmStatus.loading);
    try {
      // TODO: gọi API GET /me hoặc GET /me/payment-settings
      // final res = await dio.get('/me');
      // final data = res.data;
      // final rawMethod = data['defaultPaymentMethod'] as String?;
      // final bankJson = data['bankAccountForRefund'];
      await Future.delayed(const Duration(milliseconds: 400));

      state = state.copyWith(
        status: PmStatus.loaded,
        defaultMethod: PaymentType.bankTransfer, // fallback default
        bankAccountForRefund: null, // user chưa lưu
      );
    } catch (e) {
      state = state.copyWith(
        status: PmStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Đặt phương thức thanh toán mặc định — spec §5.1.11
  Future<void> setDefaultMethod(PaymentType type) async {
    state = state.copyWith(isSavingDefault: true, defaultMethod: type);
    try {
      // TODO: gọi API PATCH /me/payment-settings
      // await dio.patch('/me/payment-settings', data: {'defaultPaymentMethod': type.name});
      await Future.delayed(const Duration(milliseconds: 300));
      state = state.copyWith(isSavingDefault: false);
    } catch (_) {
      // Rollback không cần thiết vì chỉ là preference, giữ giá trị mới
      state = state.copyWith(isSavingDefault: false);
    }
  }

  /// Lưu tài khoản ngân hàng nhận hoàn — spec §5.1.11, §7.4 refund step 2
  /// Schema: `users.bankAccountForRefund: { number, bank, holder }`
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
    try {
      // TODO: gọi API PATCH /me/bank-account-refund
      // await dio.patch('/me/bank-account-refund', data: account.toJson());
      await Future.delayed(const Duration(milliseconds: 300));
      state = state.copyWith(bankAccountForRefund: account);
    } catch (e) {
      rethrow;
    }
  }
}

// 📁 mobile/lib/features/profile/screens/payment_methods_screen.dart (end of file)
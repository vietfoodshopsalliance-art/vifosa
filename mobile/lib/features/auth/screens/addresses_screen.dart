// lib/features/auth/screens/addresses_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/app_button.dart';

// Addresses lưu trong profile user — lấy từ GET /me
final addressesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await DioClient.instance.get(ApiEndpoints.me);
  final addresses = res.data['addresses'] ?? [];
  return List<Map<String, dynamic>>.from(addresses);
});

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addrAsync = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Địa chỉ đã lưu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddressSheet(context, ref, null),
          ),
        ],
      ),
      body: addrAsync.when(
        data: (addresses) => addresses.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_off_outlined, size: 56, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('Chưa có địa chỉ nào', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => _showAddressSheet(context, ref, null),
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm địa chỉ mới'),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: addresses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final addr = addresses[i];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        addr['label'] == 'home' ? Icons.home_outlined : Icons.work_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(addr['label'] ?? 'Địa chỉ ${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(addr['address'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (addr['isDefault'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Mặc định',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _showAddressSheet(context, ref, addr),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(addressesProvider),
            child: const Text('Thử lại'),
          ),
        ),
      ),
    );
  }

  void _showAddressSheet(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddressSheet(
        existing: existing,
        onSaved: () => ref.invalidate(addressesProvider),
      ),
    );
  }
}

class _AddressSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _AddressSheet({this.existing, required this.onSaved});

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  final _addressCtrl = TextEditingController();
  String _label = 'home';
  bool _isDefault = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _addressCtrl.text = widget.existing!['address'] ?? '';
      _label = widget.existing!['label'] ?? 'home';
      _isDefault = widget.existing!['isDefault'] ?? false;
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_addressCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      // PATCH /me với addresses mới (tuỳ API design)
      await DioClient.instance.patch(ApiEndpoints.me, data: {
        'address': {
          'label': _label,
          'address': _addressCtrl.text.trim(),
          'isDefault': _isDefault,
        },
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'Thêm địa chỉ' : 'Chỉnh sửa địa chỉ',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _label,
            decoration: const InputDecoration(labelText: 'Loại địa chỉ', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'home', child: Text('Nhà riêng')),
              DropdownMenuItem(value: 'work', child: Text('Nơi làm việc')),
              DropdownMenuItem(value: 'other', child: Text('Khác')),
            ],
            onChanged: (v) => setState(() => _label = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ chi tiết',
              hintText: 'Số nhà, đường, phường, quận...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Đặt làm địa chỉ mặc định'),
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Lưu địa chỉ',
            onPressed: _loading ? null : _save,
            isLoading: _loading,
            variant: ButtonVariant.primary,
          ),
        ],
      ),
    );
  }
}